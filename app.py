import os
import databases
import sqlalchemy
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy import create_engine, inspect
from dotenv import load_dotenv
from datetime import date, datetime, timedelta, timezone
from fastapi import FastAPI, Depends, HTTPException, status, Form, Query, Request
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from pydantic import BaseModel, EmailStr
from typing import Optional, List, Dict, Any
import logging
from logging.handlers import RotatingFileHandler
from passlib.context import CryptContext
import uuid
from apns2.client import APNsClient
from apns2.payload import Payload
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import httpx
import asyncio
import json
from sqlalchemy.dialects import postgresql

# --- Environment variables ---
load_dotenv()

# --- Logging ---
log_directory = "logs"
if not os.path.exists(log_directory):
    os.makedirs(log_directory)

log_file_path = os.path.join(log_directory, "backend.log")

# Configure logging to a rotating file and to the console
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s',
    handlers=[
        RotatingFileHandler(log_file_path, maxBytes=1*1024*1024, backupCount=3), # 1MB file, 3 backups
        logging.StreamHandler() # Keep logging to console for journalctl as a fallback
    ]
)
logger = logging.getLogger(__name__)

# --- Configuration ---
SECRET_KEY = os.getenv("SECRET_KEY", "a_random_secret_key_for_development")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 30 # 30 days
APNS_CERT_PATH = os.getenv("APNS_CERT_PATH")
APNS_KEY_ID = os.getenv("APNS_KEY_ID")
APNS_TEAM_ID = os.getenv("APNS_TEAM_ID")
APNS_TOPIC = os.getenv("APNS_TOPIC")

# --- APNs Client Setup ---
apns_client = None
if all([APNS_CERT_PATH, APNS_KEY_ID, APNS_TEAM_ID, APNS_TOPIC]):
    try:
        apns_client = APNsClient(
            team_id=APNS_TEAM_ID,
            auth_key_id=APNS_KEY_ID,
            auth_key_path=APNS_CERT_PATH,
            use_sandbox=True
        )
        logger.info("APNsClient initialized successfully.")
    except Exception as e:
        logger.error(f"Failed to initialize APNsClient: {e}")
else:
    logger.warning("APNs environment variables not fully set. Push notifications will be disabled.")


# --- Database ---
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME")

DATABASE_URL = f"postgresql+asyncpg://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
database = databases.Database(DATABASE_URL)
metadata = sqlalchemy.MetaData()
engine = create_engine(DATABASE_URL.replace("+asyncpg", ""))

# --- Table Definitions ---
users = sqlalchemy.Table(
    "users",
    metadata,
    sqlalchemy.Column("id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
    sqlalchemy.Column("family_id", UUID(as_uuid=True), sqlalchemy.ForeignKey("families.id")),
    sqlalchemy.Column("first_name", sqlalchemy.String, nullable=False),
    sqlalchemy.Column("last_name", sqlalchemy.String, nullable=False),
    sqlalchemy.Column("email", sqlalchemy.String, unique=True, nullable=False),
    sqlalchemy.Column("password_hash", sqlalchemy.String, nullable=False),
    sqlalchemy.Column("phone_number", sqlalchemy.String, nullable=True),
    sqlalchemy.Column("apns_token", sqlalchemy.String, nullable=True),
    sqlalchemy.Column("subscription_type", sqlalchemy.String, nullable=True, default="Free"),
    sqlalchemy.Column("subscription_status", sqlalchemy.String, nullable=True, default="Active"),
    sqlalchemy.Column("created_at", sqlalchemy.DateTime, nullable=True, default=datetime.now),
)

families = sqlalchemy.Table(
    "families",
    metadata,
    sqlalchemy.Column("id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
    sqlalchemy.Column("name", sqlalchemy.String, nullable=False)
)

events = sqlalchemy.Table(
    "events",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.Integer, primary_key=True, autoincrement=True),
    sqlalchemy.Column("family_id", UUID(as_uuid=True), sqlalchemy.ForeignKey("families.id"), nullable=False),
    sqlalchemy.Column("date", sqlalchemy.Date, nullable=False),
    sqlalchemy.Column("content", sqlalchemy.String(255), nullable=True),
    sqlalchemy.Column("position", sqlalchemy.Integer, nullable=True),
    sqlalchemy.Column("event_type", sqlalchemy.String, default='regular', nullable=False),
)

custody = sqlalchemy.Table(
    "custody",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.Integer, primary_key=True, autoincrement=True),
    sqlalchemy.Column("family_id", UUID(as_uuid=True), sqlalchemy.ForeignKey("families.id"), nullable=False),
    sqlalchemy.Column("date", sqlalchemy.Date, nullable=False),
    sqlalchemy.Column("actor_id", UUID(as_uuid=True), sqlalchemy.ForeignKey("users.id"), nullable=False),
    sqlalchemy.Column("custodian_id", UUID(as_uuid=True), sqlalchemy.ForeignKey("users.id"), nullable=False),
    sqlalchemy.Column("created_at", sqlalchemy.DateTime, nullable=True, default=datetime.now),
)

notification_emails = sqlalchemy.Table(
    "notification_emails",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.Integer, primary_key=True, autoincrement=True),
    sqlalchemy.Column("family_id", UUID(as_uuid=True), sqlalchemy.ForeignKey("families.id"), nullable=False),
    sqlalchemy.Column("email", sqlalchemy.String, nullable=False),
    sqlalchemy.Column("created_at", sqlalchemy.DateTime, nullable=True, default=datetime.now),
)


# --- Pydantic Models ---
class User(BaseModel):
    id: uuid.UUID
    family_id: uuid.UUID
    first_name: str
    email: EmailStr
    apns_token: Optional[str] = None

class Event(BaseModel):
    id: Optional[int] = None
    date: date
    custodian_id: Optional[uuid.UUID] = None

class CustodyRecord(BaseModel):
    id: Optional[int] = None
    date: date
    custodian_id: uuid.UUID

class CustodyResponse(BaseModel):
    id: int
    date: str
    custodian_id: str
    custodian_name: str

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    sub: Optional[str] = None

class UserProfile(BaseModel):
    id: str
    first_name: str
    last_name: str
    email: str
    phone_number: Optional[str] = None
    subscription_type: Optional[str] = "Free"
    subscription_status: Optional[str] = "Active"
    created_at: Optional[str] = None

class PasswordUpdate(BaseModel):
    current_password: str
    new_password: str

class NotificationEmail(BaseModel):
    id: int
    email: str

class AddNotificationEmail(BaseModel):
    email: str

class FamilyMemberEmail(BaseModel):
    id: str
    first_name: str
    email: str

# Add a new Pydantic model for the old format
class LegacyEvent(BaseModel):
    id: Optional[int] = None
    event_date: str
    content: str
    position: int

# Weather API models
class DailyWeather(BaseModel):
    time: List[str]
    temperature_2m_max: List[float]
    precipitation_probability_mean: List[float]
    cloudcover_mean: List[float]

class WeatherAPIResponse(BaseModel):
    daily: DailyWeather

# --- FastAPI Lifespan ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    await database.connect()
    yield
    await database.disconnect()

app = FastAPI(lifespan=lifespan)

@app.middleware("http")
async def add_no_cache_headers(request: Request, call_next):
    response = await call_next(request)
    if request.url.path.startswith("/api/"):
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
    return response

# --- CORS ---
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

# --- Security ---
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/token")

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

async def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    credentials_exception = HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Could not validate credentials")
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        if user_id is None: raise credentials_exception
    except JWTError:
        raise credentials_exception

    query = users.select().where(users.c.id == user_id)
    user_record = await database.fetch_one(query)
    if user_record is None: raise credentials_exception
    return User(**user_record)

# --- Endpoints ---

@app.get("/api/custody/{year}/{month}")
async def get_custody_records(year: int, month: int, current_user: User = Depends(get_current_user)):
    """
    Returns custody records for the specified month in a format compatible with the frontend.
    """
    # Calculate start and end dates for the month
    start_date = date(year, month, 1)
    if month == 12:
        end_date = date(year + 1, 1, 1) - timedelta(days=1)
    else:
        end_date = date(year, month + 1, 1) - timedelta(days=1)
        
    query = custody.select().where(
        (custody.c.family_id == current_user.family_id) &
        (custody.c.date.between(start_date, end_date))
    )
    custody_records = await database.fetch_all(query)
    
    # Get family members to map custodian IDs to names
    family_query = users.select().where(users.c.family_id == current_user.family_id).order_by(users.c.first_name)
    family_members = await database.fetch_all(family_query)
    
    # Create a mapping from custodian ID to name
    custodian_map = {}
    if len(family_members) >= 2:
        custodian_map[str(family_members[0]['id'])] = family_members[0]['first_name'].lower()
        custodian_map[str(family_members[1]['id'])] = family_members[1]['first_name'].lower()
    
    # Convert custody records to frontend format (compatible with events position 4)
    frontend_custody = []
    for record in custody_records:
        custodian_name = custodian_map.get(str(record['custodian_id']), 'unknown')
        frontend_custody.append({
            'id': record['id'],
            'event_date': str(record['date']),
            'content': custodian_name,
            'position': 4  # For frontend compatibility
        })
        
    return frontend_custody

@app.post("/api/custody")
async def set_custody(custody_data: CustodyRecord, current_user: User = Depends(get_current_user)):
    """
    Sets or updates custody for a specific date.
    """
    try:
        logger.info(f"Setting custody: date={custody_data.date}, custodian_id={custody_data.custodian_id}")
        
        # Check for existing custody record for this date
        existing_query = custody.select().where(
            (custody.c.family_id == current_user.family_id) & 
            (custody.c.date == custody_data.date)
        )
        existing_record = await database.fetch_one(existing_query)

        if existing_record:
            # Update existing record
            logger.info(f"Updating existing custody record with ID: {existing_record['id']}")
            update_query = custody.update().where(
                custody.c.id == existing_record['id']
            ).values(
                custodian_id=custody_data.custodian_id,
                actor_id=current_user.id
            )
            await database.execute(update_query)
            record_id = existing_record['id']
        else:
            # Create new record
            logger.info("Creating new custody record")
            insert_query = custody.insert().values(
                family_id=current_user.family_id,
                date=custody_data.date,
                actor_id=current_user.id,
                custodian_id=custody_data.custodian_id
            )
            record_id = await database.execute(insert_query)
        
        # Send notification
        await send_custody_change_notification(current_user.id, current_user.family_id, custody_data.date)
        
        # Return the updated record in frontend format
        final_query = custody.select().where(custody.c.id == record_id)
        final_record = await database.fetch_one(final_query)
        
        # Get custodian name for response
        family_query = users.select().where(users.c.family_id == current_user.family_id).order_by(users.c.first_name)
        family_members = await database.fetch_all(family_query)
        
        custodian_map = {}
        if len(family_members) >= 2:
            custodian_map[str(family_members[0]['id'])] = family_members[0]['first_name'].lower()
            custodian_map[str(family_members[1]['id'])] = family_members[1]['first_name'].lower()
        
        custodian_name = custodian_map.get(str(final_record['custodian_id']), 'unknown')
        
        logger.info(f"Custody set successfully: {custodian_name} for {custody_data.date}")
        
        return {
            'id': final_record['id'],
            'event_date': str(final_record['date']),
            'content': custodian_name,
            'position': 4  # For frontend compatibility
        }
        
    except Exception as e:
        logger.error(f"Error setting custody: {e}")
        import traceback
        logger.error(f"Full traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.get("/api/family/custodians")
async def get_family_custodians(current_user: User = Depends(get_current_user)):
    """
    Returns the first names and IDs of the two custodians in the current user's family.
    """
    query = users.select().where(users.c.family_id == current_user.family_id).order_by(users.c.first_name)
    family_members = await database.fetch_all(query)
    
    if not family_members or len(family_members) < 2:
        # Fallback or error for incomplete families
        return {
            "custodian_one": {"id": "placeholder1", "first_name": "Parent 1"},
            "custodian_two": {"id": "placeholder2", "first_name": "Parent 2"}
        }
        
    # Assuming the first two members found are the two primary custodians
    # FIX: Ensure consistent UUID string formatting for iOS compatibility
    return {
        "custodian_one": {"id": str(family_members[0]['id']).lower(), "first_name": family_members[0]['first_name']},
        "custodian_two": {"id": str(family_members[1]['id']).lower(), "first_name": family_members[1]['first_name']},
    }

@app.get("/api/weather/{latitude}/{longitude}", response_model=WeatherAPIResponse)
async def get_weather(
    latitude: float, 
    longitude: float, 
    start_date: str = Query(..., description="Start date in YYYY-MM-DD format"),
    end_date: str = Query(..., description="End date in YYYY-MM-DD format"),
    current_user: User = Depends(get_current_user)
):
    """
    Fetches weather data from Open-Meteo API for the specified coordinates and date range.
    Returns temperature, precipitation probability, and cloud cover data.
    """
    try:
        logger.info(f"Fetching weather for coordinates {latitude}, {longitude} from {start_date} to {end_date}")
        
        # Validate date format
        try:
            datetime.strptime(start_date, '%Y-%m-%d')
            datetime.strptime(end_date, '%Y-%m-%d')
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")
        
        # Build Open-Meteo API URL
        weather_url = (
            f"https://api.open-meteo.com/v1/forecast?"
            f"latitude={latitude}&longitude={longitude}"
            f"&start_date={start_date}&end_date={end_date}"
            f"&daily=temperature_2m_max,precipitation_probability_mean,cloudcover_mean"
            f"&temperature_unit=fahrenheit"
            f"&timezone=auto"
        )
        
        # Make request to Open-Meteo API
        async with httpx.AsyncClient() as client:
            response = await client.get(weather_url, timeout=10.0)
            
        if response.status_code != 200:
            logger.error(f"Open-Meteo API error: {response.status_code} - {response.text}")
            raise HTTPException(status_code=500, detail="Failed to fetch weather data from external API")
        
        weather_data = response.json()
        
        # Validate and transform the response
        if 'daily' not in weather_data:
            logger.error(f"Unexpected weather API response format: {weather_data}")
            raise HTTPException(status_code=500, detail="Invalid weather data format")
        
        daily_data = weather_data['daily']
        
        # Ensure we have all required fields
        required_fields = ['time', 'temperature_2m_max', 'precipitation_probability_mean', 'cloudcover_mean']
        for field in required_fields:
            if field not in daily_data:
                logger.error(f"Missing field '{field}' in weather response")
                raise HTTPException(status_code=500, detail=f"Missing weather data field: {field}")
        
        # Convert temperature from Celsius to Fahrenheit if needed (Open-Meteo should return Fahrenheit based on our request)
        temperatures = daily_data['temperature_2m_max']
        precipitation = daily_data['precipitation_probability_mean']
        cloudcover = daily_data['cloudcover_mean']
        
        # Handle None values by replacing with reasonable defaults
        temperatures = [temp if temp is not None else 70.0 for temp in temperatures]
        precipitation = [precip if precip is not None else 0.0 for precip in precipitation]
        cloudcover = [cloud if cloud is not None else 0.0 for cloud in cloudcover]
        
        logger.info(f"Successfully fetched weather data for {len(daily_data['time'])} days")
        
        return WeatherAPIResponse(
            daily=DailyWeather(
                time=daily_data['time'],
                temperature_2m_max=temperatures,
                precipitation_probability_mean=precipitation,
                cloudcover_mean=cloudcover
            )
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching weather data: {e}")
        import traceback
        logger.error(f"Full traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.post("/api/auth/token", response_model=Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends()):
    user = await database.fetch_one(users.select().where(users.c.email == form_data.username))
    if not user or not verify_password(form_data.password, user['password_hash']):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect username or password")
    return {"access_token": create_access_token(data={"sub": str(user['id'])}), "token_type": "bearer"}

@app.get("/api/users/me", response_model=UserProfile)
async def get_user_profile(current_user: User = Depends(get_current_user)):
    """
    Returns the full profile information for the current authenticated user.
    """
    query = users.select().where(users.c.id == current_user.id)
    user_record = await database.fetch_one(query)
    
    if not user_record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    
    return UserProfile(
        id=str(user_record['id']),
        first_name=user_record['first_name'],
        last_name=user_record['last_name'],
        email=user_record['email'],
        phone_number=user_record['phone_number'],
        subscription_type=user_record['subscription_type'] or "Free",
        subscription_status=user_record['subscription_status'] or "Active",
        created_at=str(user_record['created_at']) if user_record['created_at'] else None
    )

@app.put("/api/users/me/password")
async def update_user_password(password_update: PasswordUpdate, current_user: User = Depends(get_current_user)):
    """
    Updates the password for the current authenticated user.
    """
    # Verify current password
    user_record = await database.fetch_one(users.select().where(users.c.id == current_user.id))
    if not user_record or not verify_password(password_update.current_password, user_record['password_hash']):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid current password")
    
    # Hash new password and update
    new_password_hash = pwd_context.hash(password_update.new_password)
    await database.execute(
        users.update().where(users.c.id == current_user.id).values(password_hash=new_password_hash)
    )
    
    return {"status": "success", "message": "Password updated successfully"}

@app.post("/api/users/me/device-token")
async def update_device_token(token: str = Form(...), current_user: User = Depends(get_current_user)):
    await database.execute(users.update().where(users.c.id == current_user.id).values(apns_token=token))
    return {"status": "success"}

@app.get("/api/events/{year}/{month}")
async def get_events_by_month(year: int, month: int, current_user: User = Depends(get_current_user)):
    """
    Returns non-custody events for the specified month.
    Custody events are now handled by the separate custody API.
    """
    logger.info(f"Getting events for {year}/{month}")
    # Calculate start and end dates for the month
    start_date = date(year, month, 1)
    if month == 12:
        end_date = date(year + 1, 1, 1) - timedelta(days=1)
    else:
        end_date = date(year, month + 1, 1) - timedelta(days=1)
        
    query = events.select().where(
        (events.c.family_id == current_user.family_id) &
        (events.c.date.between(start_date, end_date)) &
        (events.c.event_type != 'custody')  # Exclude custody events
    )
    db_events = await database.fetch_all(query)
    
    # Convert events to the format expected by frontend
    frontend_events = []
    try:
        for event in db_events:
            event_data = {
                'id': event['id'],
                'family_id': str(event['family_id']),
                'event_date': str(event['date']),
                'content': event['content'],
                'position': event['position']
            }
            frontend_events.append(event_data)
    except Exception as e:
        logger.error(f"Error processing event records for /api/events/{{year}}/{{month}}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Error processing event data")
        
    logger.info(f"Payload for /api/events/{{year}}/{{month}}: {json.dumps(frontend_events, indent=2)}")
    return frontend_events

@app.get("/api/events")
async def get_events_by_date_range(start_date: str = None, end_date: str = None, current_user: User = Depends(get_current_user)):
    """
    Returns non-custody events for the specified date range (iOS app compatibility).
    Custody events are now handled by the separate custody API.
    """
    logger.info(f"iOS app requesting events from {start_date} to {end_date}")
    
    if not start_date or not end_date:
        raise HTTPException(status_code=400, detail="start_date and end_date query parameters are required")
    
    try:
        start_date_obj = datetime.strptime(start_date, '%Y-%m-%d').date()
        end_date_obj = datetime.strptime(end_date, '%Y-%m-%d').date()
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")
        
    query = events.select().where(
        (events.c.family_id == current_user.family_id) &
        (events.c.date.between(start_date_obj, end_date_obj)) &
        (events.c.event_type != 'custody')  # Exclude custody events
    )
    
    # Log the raw SQL query for debugging
    compiled_query = query.compile(dialect=postgresql.dialect(), compile_kwargs={"literal_binds": True})
    logger.info(f"Executing event query: {compiled_query}")

    db_events = await database.fetch_all(query)
    
    logger.info(f"Returning {len(db_events)} non-custody events to iOS app")
    
    # Convert events to the format expected by iOS app
    frontend_events = []
    try:
        for event in db_events:
            event_data = {
                'id': event['id'],
                'family_id': str(event['family_id']),
                'event_date': str(event['date']),
                'content': event['content'],
                'position': event['position']
            }
            frontend_events.append(event_data)
    except Exception as e:
        logger.error(f"Error processing event records for /api/events: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Error processing event data")
        
    logger.info(f"Payload for /api/events: {json.dumps(frontend_events, indent=2)}")
    return frontend_events

@app.post("/api/events")
async def save_event(request: dict, current_user: User = Depends(get_current_user)):
    """
    Handles non-custody events only. Custody events should use the /api/custody endpoint.
    """
    logger.info(f"Saving event: {request}")
    try:
        logger.info(f"[Line 587] Received non-custody event request: {request}")
        
        # Check if this is a custody event (position 4) and reject it
        if 'position' in request and request['position'] == 4:
            logger.error(f"[Line 591] Rejecting custody event - position 4 should use /api/custody endpoint")
            raise HTTPException(status_code=400, detail="Custody events should use /api/custody endpoint")
        
        # Handle legacy event format for non-custody events
        if 'event_date' in request and 'position' in request and 'content' in request:
            logger.info(f"[Line 596] Processing legacy event format")
            legacy_event = LegacyEvent(**request)
            logger.info(f"[Line 598] Created LegacyEvent object: {legacy_event}")
            
            event_date = datetime.strptime(legacy_event.event_date, '%Y-%m-%d').date()
            logger.info(f"[Line 601] Parsed event_date: {event_date}")
            
            logger.info(f"[Line 603] Creating insert query with values:")
            logger.info(f"[Line 604]   - family_id: {current_user.family_id}")
            logger.info(f"[Line 605]   - date: {event_date}")
            logger.info(f"[Line 606]   - content: {legacy_event.content}")
            logger.info(f"[Line 607]   - position: {legacy_event.position}")
            logger.info(f"[Line 608]   - event_type: 'regular'")
            
            insert_query = events.insert().values(
                family_id=current_user.family_id,
                date=event_date,
                content=legacy_event.content,
                position=legacy_event.position,
                event_type='regular'
            )
            logger.info(f"[Line 617] Insert query created successfully")
            logger.info(f"[Line 618] About to execute database insert...")
            
            event_id = await database.execute(insert_query)
            logger.info(f"[Line 621] Successfully executed insert, got event_id: {event_id}")
            
            logger.info(f"[Line 623] Successfully created event with ID {event_id}: position={legacy_event.position}, content={legacy_event.content}")
            
            return {
                'id': event_id,  # Return the actual database-generated ID
                'event_date': legacy_event.event_date,
                'content': legacy_event.content,
                'position': legacy_event.position
            }
        else:
            logger.error(f"[Line 632] Invalid event format - missing required fields")
            logger.error(f"[Line 633] Request keys: {list(request.keys())}")
            raise HTTPException(status_code=400, detail="Invalid event format - use legacy format with event_date, content, and position")
    
    except HTTPException:
        logger.error(f"[Line 637] HTTPException occurred")
        raise
    except Exception as e:
        logger.error(f"[Line 640] Exception in save_event: {e}")
        import traceback
        logger.error(f"[Line 642] Full traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.put("/api/events/{event_id}")
async def update_event(event_id: int, request: dict, current_user: User = Depends(get_current_user)):
    """
    Updates an existing non-custody event.
    """
    logger.info(f"Updating event {event_id}: {request}")
    try:
        # Check if this is a custody event (position 4) and reject it
        if 'position' in request and request['position'] == 4:
            logger.error(f"Rejecting custody event - position 4 should use /api/custody endpoint")
            raise HTTPException(status_code=400, detail="Custody events should use /api/custody endpoint")
        
        # Verify the event exists and belongs to the user's family
        verify_query = events.select().where(
            (events.c.id == event_id) & 
            (events.c.family_id == current_user.family_id) &
            (events.c.event_type != 'custody')
        )
        existing_event = await database.fetch_one(verify_query)
        
        if not existing_event:
            raise HTTPException(status_code=404, detail="Event not found or access denied")
        
        # Handle legacy event format
        if 'event_date' in request and 'position' in request and 'content' in request:
            legacy_event = LegacyEvent(**request)
            event_date = datetime.strptime(legacy_event.event_date, '%Y-%m-%d').date()
            
            # Update the event
            update_query = events.update().where(events.c.id == event_id).values(
                date=event_date,
                content=legacy_event.content,
                position=legacy_event.position
            )
            await database.execute(update_query)
            
            logger.info(f"Successfully updated event {event_id}: position={legacy_event.position}, content={legacy_event.content}")
            
            return {
                'id': event_id,
                'event_date': legacy_event.event_date,
                'content': legacy_event.content,
                'position': legacy_event.position
            }
        else:
            raise HTTPException(status_code=400, detail="Invalid event format - use legacy format with event_date, content, and position")
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Exception in update_event: {e}")
        import traceback
        logger.error(f"Full traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.delete("/api/events/{event_id}")
async def delete_event(event_id: int, current_user: User = Depends(get_current_user)):
    """
    Deletes an existing non-custody event.
    """
    logger.info(f"Deleting event {event_id}")
    try:
        # Verify the event exists and belongs to the user's family
        verify_query = events.select().where(
            (events.c.id == event_id) & 
            (events.c.family_id == current_user.family_id) &
            (events.c.event_type != 'custody')
        )
        existing_event = await database.fetch_one(verify_query)
        
        if not existing_event:
            raise HTTPException(status_code=404, detail="Event not found or access denied")
        
        # Delete the event
        delete_query = events.delete().where(events.c.id == event_id)
        await database.execute(delete_query)
        
        logger.info(f"Successfully deleted event {event_id}")
        return {"status": "success", "message": "Event deleted successfully"}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Exception in delete_event: {e}")
        import traceback
        logger.error(f"Full traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

# MARK: - Notification Email Endpoints

@app.get("/api/notifications/emails", response_model=list[NotificationEmail])
async def get_notification_emails(current_user: User = Depends(get_current_user)):
    """
    Returns all notification emails for the current user's family.
    """
    query = notification_emails.select().where(notification_emails.c.family_id == current_user.family_id)
    emails = await database.fetch_all(query)
    return [NotificationEmail(id=email['id'], email=email['email']) for email in emails]

@app.post("/api/notifications/emails", response_model=NotificationEmail)
async def add_notification_email(email_data: AddNotificationEmail, current_user: User = Depends(get_current_user)):
    """
    Adds a new notification email for the current user's family.
    """
    query = notification_emails.insert().values(
        family_id=current_user.family_id,
        email=email_data.email
    )
    email_id = await database.execute(query)
    return NotificationEmail(id=email_id, email=email_data.email)

@app.put("/api/notifications/emails/{email_id}")
async def update_notification_email(email_id: int, email_data: AddNotificationEmail, current_user: User = Depends(get_current_user)):
    """
    Updates an existing notification email for the current user's family.
    """
    query = notification_emails.update().where(
        (notification_emails.c.id == email_id) & 
        (notification_emails.c.family_id == current_user.family_id)
    ).values(email=email_data.email)
    await database.execute(query)
    return {"status": "success"}

@app.delete("/api/notifications/emails/{email_id}")
async def delete_notification_email(email_id: int, current_user: User = Depends(get_current_user)):
    """
    Deletes a notification email for the current user's family.
    """
    query = notification_emails.delete().where(
        (notification_emails.c.id == email_id) & 
        (notification_emails.c.family_id == current_user.family_id)
    )
    await database.execute(query)
    return {"status": "success"}

@app.get("/api/family/emails", response_model=list[FamilyMemberEmail])
async def get_family_member_emails(current_user: User = Depends(get_current_user)):
    """
    Returns the email addresses of all family members (parents) for automatic population in alerts.
    """
    query = users.select().where(users.c.family_id == current_user.family_id).order_by(users.c.first_name)
    family_members = await database.fetch_all(query)
    
    return [
        FamilyMemberEmail(
            id=str(member['id']),
            first_name=member['first_name'],
            email=member['email']
        )
        for member in family_members
    ]

async def send_custody_change_notification(sender_id: uuid.UUID, family_id: uuid.UUID, event_date: date):
    if not apns_client:
        logger.warning("APNs client not configured. Skipping push notification.")
        return

    other_user = await database.fetch_one(
        users.select().where((users.c.family_id == family_id) & (users.c.id != sender_id))
    )

    if other_user and other_user['apns_token']:
        sender = await database.fetch_one(users.select().where(users.c.id == sender_id))
        sender_name = sender['first_name'] if sender else "Someone"
        
        payload = Payload(
            alert=f"{sender_name} updated the schedule for {event_date.strftime('%B %-d')}.",
            sound="default",
            badge=1
        )
        try:
            logger.info(f"Sending APNs notification to {other_user['first_name']}")
            await apns_client.send_notification(other_user['apns_token'], payload, topic=APNS_TOPIC)
            logger.info("Push notification sent successfully.")
        except Exception as e:
            logger.error(f"Failed to send push notification: {e}")

# ---------------------- School Events Caching ----------------------
SCHOOL_EVENTS_CACHE: Optional[List[Dict[str, Any]]] = None  # type: ignore
SCHOOL_EVENTS_CACHE_TIME: Optional[datetime] = None
SCHOOL_EVENTS_CACHE_TTL_HOURS = 24

async def fetch_school_events() -> list[dict[str, str]]:
    """Scrape school closing events and return list of {date, title}. Uses 24-hour in-memory cache."""
    global SCHOOL_EVENTS_CACHE, SCHOOL_EVENTS_CACHE_TIME
    # Return cached copy if fresh
    if SCHOOL_EVENTS_CACHE and SCHOOL_EVENTS_CACHE_TIME:
        if datetime.now(timezone.utc) - SCHOOL_EVENTS_CACHE_TIME < timedelta(hours=SCHOOL_EVENTS_CACHE_TTL_HOURS):
            return SCHOOL_EVENTS_CACHE  # type: ignore

    import re
    from bs4 import BeautifulSoup  # type: ignore

    logger.info("Fetching school events from The Learning Tree website …")
    events: dict[str, str] = {}
    url = "https://www.thelearningtreewilmington.com/calendar-of-events/"
    try:
        async with httpx.AsyncClient(follow_redirects=True, timeout=10.0) as client:
            response = await client.get(url)
            response.raise_for_status()
            html = response.text
    except Exception as e:
        logger.error(f"Failed to download school events page: {e}")
        return []

    try:
        soup = BeautifulSoup(html, "lxml")
        header = soup.find('p', string=re.compile(r'THE LEARNING TREE CLOSINGS IN 202[0-9]'))
        if not header:
            logger.warning("School events header not found on page.")
            return []
        for sibling in header.find_next_siblings():
            if sibling.name != 'p':
                break
            text = sibling.get_text(separator=' ', strip=True)
            if not text:
                continue
            # Split by hyphen
            parts = text.split('-')
            if len(parts) > 1:
                event_name = parts[0].strip()
                date_str = '-'.join(parts[1:]).strip()
            else:
                event_name = text
                date_str = ''
            # Extract first occurrence of month day pattern
            date_match = re.search(r'(\w+\s+\d+)', text)
            if date_match:
                date_str = date_match.group(1)
            # Determine year from header
            year_match = re.search(r'(\d{4})', header.text)
            year = year_match.group(1) if year_match else str(datetime.now(timezone.utc).year)
            # Special New Year edge case for next year
            if "new year" in event_name.lower() and str(int(year)+1) in text:
                year = str(int(year)+1)
            # Clean event name
            event_name = event_name.replace(date_str, '').strip().rstrip('-').strip()
            # Parse date
            try:
                date_str_no_weekday = re.sub(r'^\w+,\s*', '', date_str)
                full_date_str = f"{date_str_no_weekday}, {year}"
                full_date_str = full_date_str.replace("Jan ", "January ")
                event_date = datetime.strptime(full_date_str, '%B %d, %Y')
                iso_date = event_date.strftime('%Y-%m-%d')
                if event_name:
                    events[iso_date] = event_name
            except ValueError:
                logger.warning(f"Could not parse date from: {date_str} ({text})")
    except Exception as e:
        logger.error(f"Failed to parse school events: {e}")
        return []

    logger.info(f"Successfully scraped {len(events)} school events.")
    SCHOOL_EVENTS_CACHE = [{"date": d, "title": name} for d, name in events.items()]
    SCHOOL_EVENTS_CACHE_TIME = datetime.now(timezone.utc)
    return SCHOOL_EVENTS_CACHE  # type: ignore

# -------------------------------------------------------------------

@app.get("/api/school-events")
async def get_school_events(current_user: User = Depends(get_current_user)):
    """Returns a JSON array of school events scraped from the Learning Tree website."""
    try:
        events = await fetch_school_events()
        return events
    except Exception as e:
        logger.error(f"Error retrieving school events: {e}")
        raise HTTPException(status_code=500, detail="Unable to retrieve school events")