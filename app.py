import os
import databases
import sqlalchemy
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy import create_engine, inspect
from dotenv import load_dotenv
from datetime import date, datetime, timedelta, timezone
from fastapi import FastAPI, Depends, HTTPException, status, Form, Query, Request, File, UploadFile
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List, Dict, Any
import logging
from logging.handlers import RotatingFileHandler
import traceback
from passlib.context import CryptContext
import uuid
from apns2.client import APNsClient
from apns2.credentials import TokenCredentials
from apns2.payload import Payload
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import httpx
import asyncio
import json
from sqlalchemy.dialects import postgresql
import pytz
import boto3
from botocore.exceptions import ClientError
import base64
import hashlib
from typing import Tuple
import time

# --- Environment variables ---
load_dotenv()

# --- Weather Cache ---
# Simple in-memory cache with TTL (time-to-live) expiration
weather_cache = {}

def get_cache_key(latitude: float, longitude: float, start_date: str, end_date: str, endpoint_type: str) -> str:
    """Generate a unique cache key for weather data."""
    key_string = f"{endpoint_type}:{latitude}:{longitude}:{start_date}:{end_date}"
    return hashlib.md5(key_string.encode()).hexdigest()

def get_cached_weather(cache_key: str) -> Optional[Dict]:
    """Get cached weather data if it exists and hasn't expired."""
    if cache_key in weather_cache:
        cached_data, timestamp = weather_cache[cache_key]
        # Cache expires after 1 hour for forecast, 24 hours for historic
        cache_ttl = 3600 if "forecast" in cache_key else 86400
        if time.time() - timestamp < cache_ttl:
            return cached_data
        else:
            # Remove expired cache entry
            del weather_cache[cache_key]
    return None

def cache_weather_data(cache_key: str, data: Dict):
    """Cache weather data with timestamp."""
    weather_cache[cache_key] = (data, time.time())

# --- Logging ---
log_directory = "logs"
if not os.path.exists(log_directory):
    os.makedirs(log_directory)

log_file_path = os.path.join(log_directory, "backend.log")

# Configure logging with EST timezone
import pytz

class ESTFormatter(logging.Formatter):
    def converter(self, timestamp):
        dt = datetime.fromtimestamp(timestamp, tz=pytz.timezone('US/Eastern'))
        return dt.timetuple()

est_formatter = ESTFormatter('%(asctime)s EST - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s')

# Configure logging to a rotating file and to the console
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# Remove default handlers
for handler in logger.handlers[:]:
    logger.removeHandler(handler)

# Create file handler
file_handler = RotatingFileHandler(log_file_path, maxBytes=1*1024*1024, backupCount=3)
file_handler.setFormatter(est_formatter)

# Create console handler  
console_handler = logging.StreamHandler()
console_handler.setFormatter(est_formatter)

# Add handlers to logger
logger.addHandler(file_handler)
logger.addHandler(console_handler)

# Prevent duplicate logs
logger.propagate = False

# --- Configuration ---
SECRET_KEY = os.getenv("SECRET_KEY", "a_random_secret_key_for_development")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 30 # 30 days
APNS_CERT_PATH = os.getenv("APNS_CERT_PATH")
APNS_KEY_ID = os.getenv("APNS_KEY_ID")
APNS_TEAM_ID = os.getenv("APNS_TEAM_ID")
APNS_TOPIC = os.getenv("APNS_TOPIC")

# --- APNs Client Setup ---
token_credentials = TokenCredentials(auth_key_path=APNS_CERT_PATH, auth_key_id=APNS_KEY_ID, team_id=APNS_TEAM_ID)
apns_client = None
if all([APNS_CERT_PATH, APNS_KEY_ID, APNS_TEAM_ID, APNS_TOPIC]):
    try:
        apns_client = APNsClient(credentials=token_credentials,use_sandbox=True)
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
    sqlalchemy.Column("profile_photo_url", sqlalchemy.String, nullable=True),
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
    sqlalchemy.Column("handoff_day", sqlalchemy.Boolean, default=False, nullable=True),
    sqlalchemy.Column("handoff_time", sqlalchemy.Time, nullable=True),
    sqlalchemy.Column("handoff_location", sqlalchemy.String(255), nullable=True),
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

babysitters = sqlalchemy.Table(
    "babysitters",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.Integer, primary_key=True, autoincrement=True),
    sqlalchemy.Column("first_name", sqlalchemy.String(100), nullable=False),
    sqlalchemy.Column("last_name", sqlalchemy.String(100), nullable=False),
    sqlalchemy.Column("phone_number", sqlalchemy.String(20), nullable=False),
    sqlalchemy.Column("rate", sqlalchemy.Numeric(6, 2), nullable=True),
    sqlalchemy.Column("notes", sqlalchemy.Text, nullable=True),
    sqlalchemy.Column("created_by_user_id", UUID(as_uuid=True), sqlalchemy.ForeignKey("users.id"), nullable=False),
    sqlalchemy.Column("created_at", sqlalchemy.DateTime, nullable=True, default=datetime.now),
)

babysitter_families = sqlalchemy.Table(
    "babysitter_families",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.Integer, primary_key=True, autoincrement=True),
    sqlalchemy.Column("babysitter_id", sqlalchemy.Integer, sqlalchemy.ForeignKey("babysitters.id", ondelete="CASCADE"), nullable=False),
    sqlalchemy.Column("family_id", UUID(as_uuid=True), sqlalchemy.ForeignKey("families.id", ondelete="CASCADE"), nullable=False),
    sqlalchemy.Column("added_by_user_id", UUID(as_uuid=True), sqlalchemy.ForeignKey("users.id"), nullable=False),
    sqlalchemy.Column("added_at", sqlalchemy.DateTime, nullable=True, default=datetime.now),
    sqlalchemy.UniqueConstraint("babysitter_id", "family_id", name="unique_babysitter_family"),
)

emergency_contacts = sqlalchemy.Table(
    "emergency_contacts",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.Integer, primary_key=True, autoincrement=True),
    sqlalchemy.Column("family_id", UUID(as_uuid=True), sqlalchemy.ForeignKey("families.id", ondelete="CASCADE"), nullable=False),
    sqlalchemy.Column("first_name", sqlalchemy.String(100), nullable=False),
    sqlalchemy.Column("last_name", sqlalchemy.String(100), nullable=False),
    sqlalchemy.Column("phone_number", sqlalchemy.String(20), nullable=False),
    sqlalchemy.Column("relationship", sqlalchemy.String(100), nullable=True),
    sqlalchemy.Column("notes", sqlalchemy.Text, nullable=True),
    sqlalchemy.Column("created_by_user_id", UUID(as_uuid=True), sqlalchemy.ForeignKey("users.id"), nullable=False),
    sqlalchemy.Column("created_at", sqlalchemy.DateTime, nullable=True, default=datetime.now),
)



group_chats = sqlalchemy.Table(
    "group_chats",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.Integer, primary_key=True, autoincrement=True),
    sqlalchemy.Column("family_id", UUID(as_uuid=True), sqlalchemy.ForeignKey("families.id", ondelete="CASCADE"), nullable=False),
    sqlalchemy.Column("contact_type", sqlalchemy.String(20), nullable=False),
    sqlalchemy.Column("contact_id", sqlalchemy.Integer, nullable=False),
    sqlalchemy.Column("group_identifier", sqlalchemy.String(255), unique=True, nullable=True),
    sqlalchemy.Column("created_by_user_id", UUID(as_uuid=True), sqlalchemy.ForeignKey("users.id"), nullable=False),
    sqlalchemy.Column("created_at", sqlalchemy.DateTime, nullable=True, default=datetime.now),
)

children = sqlalchemy.Table(
    "children",
    metadata,
    sqlalchemy.Column("id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
    sqlalchemy.Column("family_id", UUID(as_uuid=True), sqlalchemy.ForeignKey("families.id", ondelete="CASCADE"), nullable=False),
    sqlalchemy.Column("first_name", sqlalchemy.String(100), nullable=False),
    sqlalchemy.Column("last_name", sqlalchemy.String(100), nullable=False),
    sqlalchemy.Column("dob", sqlalchemy.Date, nullable=False),
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
    handoff_time: Optional[str] = None
    handoff_location: Optional[str] = None
    handoff_day: Optional[bool] = None

class CustodyResponse(BaseModel):
    id: int
    event_date: str
    content: str
    position: int = 4  # Always 4 for custody
    custodian_id: str
    handoff_day: Optional[bool] = None
    handoff_time: Optional[str] = None
    handoff_location: Optional[str] = None

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
    profile_photo_url: Optional[str] = None
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

class FamilyMember(BaseModel):
    id: str
    first_name: str
    last_name: str
    email: str
    phone_number: Optional[str] = None

class Babysitter(BaseModel):
    id: Optional[int] = None
    first_name: str
    last_name: str
    phone_number: str
    rate: Optional[float] = None
    notes: Optional[str] = None
    created_by_user_id: Optional[str] = None
    created_at: Optional[str] = None

class BabysitterCreate(BaseModel):
    first_name: str
    last_name: str
    phone_number: str
    rate: Optional[float] = None
    notes: Optional[str] = None

class BabysitterResponse(BaseModel):
    id: int
    first_name: str
    last_name: str
    phone_number: str
    rate: Optional[float] = None
    notes: Optional[str] = None
    created_by_user_id: str
    created_at: str

class EmergencyContact(BaseModel):
    id: Optional[int] = None
    first_name: str
    last_name: str
    phone_number: str
    relationship: Optional[str] = None
    notes: Optional[str] = None
    created_by_user_id: Optional[str] = None
    created_at: Optional[str] = None

class EmergencyContactCreate(BaseModel):
    first_name: str
    last_name: str
    phone_number: str
    relationship: Optional[str] = None
    notes: Optional[str] = None

class EmergencyContactResponse(BaseModel):
    id: int
    first_name: str
    last_name: str
    phone_number: str
    relationship: Optional[str] = None
    notes: Optional[str] = None
    created_by_user_id: str
    created_at: str

class UserRegistration(BaseModel):
    first_name: str
    last_name: str
    email: EmailStr
    password: str
    phone_number: Optional[str] = None
    family_name: Optional[str] = None

class UserRegistrationResponse(BaseModel):
    user_id: str
    family_id: str
    access_token: str
    token_type: str = "bearer"
    message: str

class GroupChatCreate(BaseModel):
    contact_type: str  # 'babysitter' or 'emergency'
    contact_id: int
    group_identifier: Optional[str] = None

class ChildCreate(BaseModel):
    first_name: str
    last_name: str
    dob: str  # Date string in YYYY-MM-DD format

class ChildResponse(BaseModel):
    id: str
    first_name: str
    last_name: str
    dob: str  # Date string in YYYY-MM-DD format
    family_id: str



# Add a new Pydantic model for the old format
class LegacyEvent(BaseModel):
    id: Optional[int] = None
    event_date: str
    content: str
    position: int


class DailyWeather(BaseModel):
    time: List[str]
    temperature_2m_max: List[Optional[float]]
    precipitation_probability_mean: List[Optional[float]]
    cloudcover_mean: List[Optional[float]]


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
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def uuid_to_string(uuid_obj) -> str:
    """Convert UUID to standardized lowercase string format for consistent comparisons"""
    return str(uuid_obj).lower()

async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    query = users.select().where(users.c.id == user_id)
    user = await database.fetch_one(query)
    
    if user is None:
        raise credentials_exception
    return user

@app.post("/api/auth/token", response_model=Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends()):
    query = users.select().where(users.c.email == form_data.username)
    user = await database.fetch_one(query)
    if not user or not verify_password(form_data.password, user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token = create_access_token(
        data={"sub": uuid_to_string(user["id"]), "family_id": uuid_to_string(user["family_id"])}
    )
    return {"access_token": access_token, "token_type": "bearer"}

@app.post("/api/auth/register", response_model=UserRegistrationResponse)
async def register_user(registration_data: UserRegistration):
    """
    Register a new user and create a family if family_name is provided.
    """
    logger.info(f"User registration attempt for email: {registration_data.email}")
    
    try:
        # Check if user already exists
        existing_user_query = users.select().where(users.c.email == registration_data.email)
        existing_user = await database.fetch_one(existing_user_query)
        
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="User with this email already exists"
            )
        
        # Hash the password
        password_hash = pwd_context.hash(registration_data.password)
        
        # Handle family creation/assignment
        family_id = None
        if registration_data.family_name:
            # Check if family already exists
            family_query = families.select().where(families.c.name == registration_data.family_name)
            existing_family = await database.fetch_one(family_query)
            
            if existing_family:
                family_id = existing_family['id']
                logger.info(f"Adding user to existing family: {registration_data.family_name}")
            else:
                # Create new family
                family_insert = families.insert().values(name=registration_data.family_name).returning(families.c.id)
                family_id = await database.execute(family_insert)
                logger.info(f"Created new family: {registration_data.family_name} with ID: {family_id}")
        else:
            # Create family with user's last name if no family name provided
            default_family_name = f"{registration_data.last_name} Family"
            family_insert = families.insert().values(name=default_family_name).returning(families.c.id)
            family_id = await database.execute(family_insert)
            logger.info(f"Created default family: {default_family_name} with ID: {family_id}")
        
        # Create the user
        user_insert = users.insert().values(
            family_id=family_id,
            first_name=registration_data.first_name,
            last_name=registration_data.last_name,
            email=registration_data.email,
            password_hash=password_hash,
            phone_number=registration_data.phone_number,
            subscription_type="Free",
            subscription_status="Active"
        ).returning(users.c.id)
        
        user_id = await database.execute(user_insert)
        logger.info(f"Created user with ID: {user_id}")
        
        # Create access token for the new user
        access_token = create_access_token(
            data={"sub": uuid_to_string(user_id), "family_id": uuid_to_string(family_id)}
        )
        
        return UserRegistrationResponse(
            user_id=uuid_to_string(user_id),
            family_id=uuid_to_string(family_id),
            access_token=access_token,
            message="User registered successfully"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error during user registration: {e}")
        logger.error(f"Full traceback: {traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Registration failed. Please try again."
        )

@app.get("/api/custody/{year}/{month}", response_model=List[CustodyResponse])
async def get_custody_records(year: int, month: int, current_user = Depends(get_current_user)):
    """
    Returns custody records for the specified month.
    """
    try:
        family_id = current_user['family_id']
        # Calculate start and end dates for the month
        start_date = date(year, month, 1)
        if month == 12:
            end_date = date(year, 1, 1) + timedelta(days=31)
            end_date = end_date.replace(day=1) - timedelta(days=1)
        else:
            end_date = date(year, month + 1, 1) - timedelta(days=1)
        
        # Query custody records for the given month and family
        query = custody.select().where(
            (custody.c.family_id == family_id) &
            (custody.c.date.between(start_date, end_date))
        )
        
        db_records = await database.fetch_all(query)
        
        # Get all user data for the family in a single query
        user_query = users.select().where(users.c.family_id == family_id)
        family_users = await database.fetch_all(user_query)
        user_map = {uuid_to_string(user['id']): user['first_name'] for user in family_users}
        
        # Convert records to CustodyResponse format
        custody_responses = [
            CustodyResponse(
                id=record['id'],
                event_date=str(record['date']),
                content=user_map.get(uuid_to_string(record['custodian_id']), "Unknown"),
                custodian_id=uuid_to_string(record['custodian_id']),
                handoff_day=record['handoff_day'],
                handoff_time=record['handoff_time'].strftime('%H:%M') if record['handoff_time'] else None,
                handoff_location=record['handoff_location']
            ) for record in db_records
        ]
        
        # logger.info(f"Returning {len(custody_responses)} custody records for {year}-{month}")
        return custody_responses
    except Exception as e:
        logger.error(f"Error fetching custody records: {e}")
        logger.error(f"Full traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/api/custody", response_model=CustodyResponse)
async def set_custody(custody_data: CustodyRecord, current_user = Depends(get_current_user)):
    """
    Creates or updates a custody record for a specific date.
    """
    logger.info(f"Received custody update request: {custody_data.model_dump_json(indent=2)}")
    
    family_id = current_user['family_id']
    actor_id = current_user['id']
    
    try:
        # Check if a record already exists for this date
        existing_record_query = custody.select().where(
            (custody.c.family_id == family_id) &
            (custody.c.date == custody_data.date)
        )
        existing_record = await database.fetch_one(existing_record_query)
        
        # If handoff_day is not provided, determine it based on default logic
        handoff_day_value = custody_data.handoff_day
        if handoff_day_value is None and custody_data.handoff_time is not None:
            # If handoff time is provided but handoff_day is not, assume it's a handoff day
            handoff_day_value = True
        elif handoff_day_value is None:
            # Default logic: check if previous day has different custodian
            previous_date = custody_data.date - timedelta(days=1)
            previous_record = await database.fetch_one(
                custody.select().where(
                    (custody.c.family_id == family_id) &
                    (custody.c.date == previous_date)
                )
            )
            if previous_record and previous_record['custodian_id'] != custody_data.custodian_id:
                handoff_day_value = True
                
                # Set default handoff time and location if not provided
                if not custody_data.handoff_time:
                    weekday = custody_data.date.weekday()  # Monday = 0, Sunday = 6
                    is_weekend = weekday >= 5  # Saturday = 5, Sunday = 6
                    if is_weekend:
                        custody_data.handoff_time = "12:00"  # Noon for weekends
                        if not custody_data.handoff_location:
                            # Get target custodian name for location
                            target_user = await database.fetch_one(users.select().where(users.c.id == custody_data.custodian_id))
                            target_name = target_user['first_name'].lower() if target_user else "unknown"
                            custody_data.handoff_location = f"{target_name}'s home"
                    else:
                        custody_data.handoff_time = "17:00"  # 5pm for weekdays
                        if not custody_data.handoff_location:
                            custody_data.handoff_location = "daycare"
            else:
                handoff_day_value = False

        if existing_record:
            # Update existing record
            update_query = custody.update().where(custody.c.id == existing_record['id']).values(
                custodian_id=custody_data.custodian_id,
                actor_id=actor_id,
                handoff_day=handoff_day_value,
                handoff_time=datetime.strptime(custody_data.handoff_time, '%H:%M').time() if custody_data.handoff_time else None,
                handoff_location=custody_data.handoff_location
            )
            await database.execute(update_query)
            record_id = existing_record['id']
        else:
            # Insert new record
            insert_query = custody.insert().values(
                family_id=family_id,
                date=custody_data.date,
                custodian_id=custody_data.custodian_id,
                actor_id=actor_id,
                handoff_day=handoff_day_value,
                handoff_time=datetime.strptime(custody_data.handoff_time, '%H:%M').time() if custody_data.handoff_time else None,
                handoff_location=custody_data.handoff_location,
                created_at=datetime.now()
            )
            record_id = await database.execute(insert_query)
            
        # Send push notification to the other parent
        await send_custody_change_notification(sender_id=actor_id, family_id=family_id, event_date=custody_data.date)
            
        # Get custodian name for response
        custodian_user = await database.fetch_one(users.select().where(users.c.id == custody_data.custodian_id))
        custodian_name = custodian_user['first_name'] if custodian_user else "Unknown"

        return CustodyResponse(
            id=record_id,
            event_date=str(custody_data.date),
            content=custodian_name,
            custodian_id=str(custody_data.custodian_id),
            handoff_day=handoff_day_value,
            handoff_time=custody_data.handoff_time,
            handoff_location=custody_data.handoff_location
        )
    except Exception as e:
        logger.error(f"Error setting custody: {e}")
        logger.error(f"Full traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Internal server error while setting custody: {e}")

@app.patch("/api/custody/handoff-day", response_model=CustodyResponse)
async def update_handoff_day_only(request: dict, current_user = Depends(get_current_user)):
    """
    Updates only the handoff_day field for an existing custody record.
    Does not modify custodian_id, handoff_time, or handoff_location.
    """
    date_str = request.get("date")
    handoff_day = request.get("handoff_day")
    
    if not date_str or handoff_day is None:
        raise HTTPException(status_code=400, detail="date and handoff_day are required")
    
    try:
        date_obj = datetime.strptime(date_str, '%Y-%m-%d').date()
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")
    
    family_id = current_user['family_id']
    
    try:
        # Find existing custody record for this date
        existing_record_query = custody.select().where(
            (custody.c.family_id == family_id) &
            (custody.c.date == date_obj)
        )
        existing_record = await database.fetch_one(existing_record_query)
        
        if not existing_record:
            raise HTTPException(status_code=404, detail="No custody record found for this date")
        
        # Update only the handoff_day field
        update_query = custody.update().where(custody.c.id == existing_record['id']).values(
            handoff_day=handoff_day
        )
        await database.execute(update_query)
        
        # Get custodian name for response
        custodian_user = await database.fetch_one(users.select().where(users.c.id == existing_record['custodian_id']))
        custodian_name = custodian_user['first_name'] if custodian_user else "Unknown"
        
        # Return the updated record
        return CustodyResponse(
            id=existing_record['id'],
            event_date=str(date_obj),
            content=custodian_name,
            custodian_id=uuid_to_string(existing_record['custodian_id']),
            handoff_day=handoff_day,
            handoff_time=existing_record['handoff_time'].strftime('%H:%M') if existing_record['handoff_time'] else None,
            handoff_location=existing_record['handoff_location']
        )
        
    except Exception as e:
        logger.error(f"Error updating handoff_day: {e}")
        logger.error(f"Full traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Internal server error while updating handoff_day: {e}")

@app.get("/api/family/custodians")
async def get_family_custodians(current_user = Depends(get_current_user)):
    """
    Returns the two primary custodians (parents) for the current user's family.
    """
    family_id = current_user['family_id']
    family_members = await database.fetch_all(users.select().where(users.c.family_id == family_id).order_by(users.c.created_at))
    
    if len(family_members) < 2:
        raise HTTPException(status_code=404, detail="Family must have at least two members to determine custodians")
        
    custodian_one = family_members[0]
    custodian_two = family_members[1]
    
    return {
        "custodian_one": {
            "id": uuid_to_string(custodian_one['id']),
            "first_name": custodian_one['first_name']
        },
        "custodian_two": {
            "id": uuid_to_string(custodian_two['id']),
            "first_name": custodian_two['first_name']
        }
    }

@app.get("/api/weather/{latitude}/{longitude}", response_model=WeatherAPIResponse)
async def get_weather(
    latitude: float, 
    longitude: float, 
    start_date: str = Query(..., description="Start date in YYYY-MM-DD format"),
    end_date: str = Query(..., description="End date in YYYY-MM-DD format"),
    current_user = Depends(get_current_user)
):
    """
    Fetches weather data from Open-Meteo API.
    """
    # logger.info(f"Fetching weather data for {start_date} to {end_date}")
    cache_key = get_cache_key(latitude, longitude, start_date, end_date, "forecast")
    
    cached_data = get_cached_weather(cache_key)
    if cached_data:
        logger.info(f"Returning cached weather data for forecast: {start_date} to {end_date}")
        return cached_data
    
    api_url = f"https://api.open-meteo.com/v1/forecast?latitude={latitude}&longitude={longitude}&daily=temperature_2m_max,precipitation_probability_mean,cloudcover_mean&timezone=auto&start_date={start_date}&end_date={end_date}"
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(api_url)
            response.raise_for_status()
            data = response.json()
            
            # Replace None with 0.0 for robust handling
            daily_data = data.get("daily", {})
            for key in ['temperature_2m_max', 'precipitation_probability_mean', 'cloudcover_mean']:
                if key in daily_data:
                    daily_data[key] = [v if v is not None else 0.0 for v in daily_data[key]]
            
            # Cache the response
            cache_weather_data(cache_key, data)
            
            return data
    except httpx.HTTPStatusError as e:
        logger.error(f"HTTP error fetching weather data: {e.response.status_code} - {e.response.text}")
        raise HTTPException(status_code=e.response.status_code, detail=f"Error from weather API: {e.response.text}")
    except Exception as e:
        logger.error(f"Error fetching weather data: {e}")
        raise HTTPException(status_code=500, detail="Internal server error while fetching weather data")

@app.get("/api/weather/historic/{latitude}/{longitude}", response_model=WeatherAPIResponse)
async def get_historic_weather(
    latitude: float, 
    longitude: float, 
    start_date: str = Query(..., description="Start date in YYYY-MM-DD format"),
    end_date: str = Query(..., description="End date in YYYY-MM-DD format"),
    current_user = Depends(get_current_user)
):
    """
    Fetches historic weather data from Open-Meteo API.
    """
    # logger.info(f"Fetching historic weather data for {start_date} to {end_date}")
    cache_key = get_cache_key(latitude, longitude, start_date, end_date, "historic")
    
    cached_data = get_cached_weather(cache_key)
    if cached_data:
        # logger.info(f"Returning cached weather data for historic: {start_date} to {end_date}")
        return cached_data
        
    api_url = f"https://archive-api.open-meteo.com/v1/archive?latitude={latitude}&longitude={longitude}&start_date={start_date}&end_date={end_date}&daily=temperature_2m_max,precipitation_probability_mean,cloudcover_mean&timezone=auto"

    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(api_url)
            response.raise_for_status()
            data = response.json()
            
            # Replace None with 0.0 for robust handling
            daily_data = data.get("daily", {})
            for key in ['temperature_2m_max', 'precipitation_probability_mean', 'cloudcover_mean']:
                if key in daily_data:
                    daily_data[key] = [v if v is not None else 0.0 for v in daily_data[key]]
            
            # Cache the response
            cache_weather_data(cache_key, data)
            
            return data
    except httpx.HTTPStatusError as e:
        logger.error(f"HTTP error fetching historic weather: {e.response.status_code} - {e.response.text}")
        raise HTTPException(status_code=e.response.status_code, detail=f"Error from historic weather API: {e.response.text}")
    except Exception as e:
        logger.error(f"Error fetching historic weather: {e}")
        raise HTTPException(status_code=500, detail="Internal server error while fetching historic weather")

@app.get("/api/user/profile", response_model=UserProfile)
async def get_user_profile(current_user = Depends(get_current_user)):
    """
    Fetch the current user's profile information.
    """
    try:
        # Get user data from database
        user_record = await database.fetch_one(users.select().where(users.c.id == current_user['id']))
        if not user_record:
            raise HTTPException(status_code=404, detail="User not found")
            
        return UserProfile(
            id=uuid_to_string(user_record['id']),
            first_name=user_record['first_name'],
            last_name=user_record['last_name'],
            email=user_record['email'],
            phone_number=user_record['phone_number'],
            subscription_type=user_record['subscription_type'] or "Free",
            subscription_status=user_record['subscription_status'] or "Active",
            profile_photo_url=user_record['profile_photo_url'],
            created_at=str(user_record['created_at']) if user_record['created_at'] else None
        )
    except Exception as e:
        logger.error(f"Error fetching user profile: {e}")
        logger.error(f"Full traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/api/users/me", response_model=UserProfile)
async def get_user_profile_legacy(current_user = Depends(get_current_user)):
    """
    Legacy endpoint for backward compatibility.
    """
    try:
        # Get user data from database
        user_record = await database.fetch_one(users.select().where(users.c.id == current_user['id']))
        if not user_record:
            raise HTTPException(status_code=404, detail="User not found")
            
        return UserProfile(
            id=uuid_to_string(user_record['id']),
            first_name=user_record['first_name'],
            last_name=user_record['last_name'],
            email=user_record['email'],
            phone_number=user_record['phone_number'],
            subscription_type=user_record['subscription_type'] or "Free",
            subscription_status=user_record['subscription_status'] or "Active",
            profile_photo_url=user_record['profile_photo_url'],
            created_at=str(user_record['created_at']) if user_record['created_at'] else None
        )
    except Exception as e:
        logger.error(f"Error fetching user profile (legacy): {e}")
        logger.error(f"Full traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.put("/api/users/me/password")
async def update_user_password(password_update: PasswordUpdate, current_user = Depends(get_current_user)):
    """
    Updates the password for the current authenticated user.
    """
    # Verify current password
    user_record = await database.fetch_one(users.select().where(users.c.id == current_user['id']))
    if not user_record or not verify_password(password_update.current_password, user_record['password_hash']):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid current password")
    
    # Hash new password and update
    new_password_hash = pwd_context.hash(password_update.new_password)
    await database.execute(
        users.update().where(users.c.id == current_user['id']).values(password_hash=new_password_hash)
    )
    
    return {"status": "success", "message": "Password updated successfully"}

@app.post("/api/users/me/device-token")
async def update_device_token(token: str = Form(...), current_user = Depends(get_current_user)):
    await database.execute(users.update().where(users.c.id == current_user['id']).values(apns_token=token))
    return {"status": "success"}

@app.post("/api/user/profile/photo", response_model=UserProfile)
async def upload_profile_photo(
    photo: UploadFile = File(...),
    current_user = Depends(get_current_user)
):
    """
    Uploads a profile photo for the current user.
    """
    try:
        # Validate file type
        if not photo.content_type.startswith('image/'):
            raise HTTPException(status_code=400, detail="File must be an image")
        
        # Generate a unique filename
        file_extension = os.path.splitext(photo.filename)[1]
        unique_filename = f"{uuid.uuid4()}{file_extension}"
        object_name = f"profile_photos/{unique_filename}"

        # Upload to S3
        s3_client = boto3.client(
            's3',
            aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
            aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
            region_name=os.getenv("AWS_REGION")
        )

        # Read file content
        file_content = await photo.read()

        # Upload to S3
        s3_client.put_object(
            Bucket=os.getenv("AWS_S3_BUCKET_NAME"),
            Key=object_name,
            Body=file_content,
            ContentType=photo.content_type,
            ACL='public-read'  # Make the file publicly accessible
        )

        # Construct the S3 URL
        s3_url = f"https://{os.getenv('AWS_S3_BUCKET_NAME')}.s3.{os.getenv('AWS_REGION')}.amazonaws.com/{object_name}"

        # Update user's profile_photo_url in the database
        await database.execute(
            users.update().where(users.c.id == current_user['id']).values(profile_photo_url=s3_url)
        )

        # Re-fetch user to get updated profile_photo_url
        user_record = await database.fetch_one(users.select().where(users.c.id == current_user['id']))
        return UserProfile(
            id=str(user_record['id']),
            first_name=user_record['first_name'],
            last_name=user_record['last_name'],
            email=user_record['email'],
            phone_number=user_record['phone_number'],
            subscription_type=user_record['subscription_type'] or "Free",
            subscription_status=user_record['subscription_status'] or "Active",
            profile_photo_url=user_record['profile_photo_url'],
            created_at=str(user_record['created_at']) if user_record['created_at'] else None
        )
    except ClientError as e:
        logger.error(f"S3 upload error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to upload profile photo: {e.response['Error']['Message']}")
    except Exception as e:
        logger.error(f"Error uploading profile photo: {e}")
        logger.error(f"Full traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.get("/api/events/{year}/{month}")
async def get_events_by_month(year: int, month: int, current_user = Depends(get_current_user)):
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
        (events.c.family_id == current_user['family_id']) &
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
async def get_events_by_date_range(start_date: str = None, end_date: str = None, current_user = Depends(get_current_user)):
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
        (events.c.family_id == current_user['family_id']) &
        (events.c.date.between(start_date_obj, end_date_obj)) &
        (events.c.event_type != 'custody')  # Exclude custody events
    )
    
    # Log the raw SQL query for debugging
    compiled_query = query.compile(dialect=postgresql.dialect(), compile_kwargs={"literal_binds": True})
    # logger.info(f"Executing event query: {compiled_query}")

    db_events = await database.fetch_all(query)
    
    # logger.info(f"Returning {len(db_events)} non-custody events to iOS app")
    
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
        
    # logger.info(f"Payload for /api/events: {json.dumps(frontend_events, indent=2)}")
    return frontend_events

@app.post("/api/events")
async def save_event(request: dict, current_user = Depends(get_current_user)):
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
            logger.info(f"[Line 604]   - family_id: {current_user['family_id']}")
            logger.info(f"[Line 605]   - date: {event_date}")
            logger.info(f"[Line 606]   - content: {legacy_event.content}")
            logger.info(f"[Line 607]   - position: {legacy_event.position}")
            logger.info(f"[Line 608]   - event_type: 'regular'")
            
            insert_query = events.insert().values(
                family_id=current_user['family_id'],
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
        logger.error(f"[Line 642] Full traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.put("/api/events/{event_id}")
async def update_event(event_id: int, request: dict, current_user = Depends(get_current_user)):
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
            (events.c.family_id == current_user['family_id']) &
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
        logger.error(f"Full traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.delete("/api/events/{event_id}")
async def delete_event(event_id: int, current_user = Depends(get_current_user)):
    """
    Deletes an existing non-custody event.
    """
    logger.info(f"Deleting event {event_id}")
    try:
        # Verify the event exists and belongs to the user's family
        verify_query = events.select().where(
            (events.c.id == event_id) & 
            (events.c.family_id == current_user['family_id']) &
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
        logger.error(f"Full traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

# MARK: - Notification Email Endpoints

@app.get("/api/notifications/emails", response_model=list[NotificationEmail])
async def get_notification_emails(current_user = Depends(get_current_user)):
    """
    Returns all notification emails for the current user's family.
    """
    query = notification_emails.select().where(notification_emails.c.family_id == current_user['family_id'])
    emails = await database.fetch_all(query)
    return [NotificationEmail(id=email['id'], email=email['email']) for email in emails]

@app.post("/api/notifications/emails", response_model=NotificationEmail)
async def add_notification_email(email_data: AddNotificationEmail, current_user = Depends(get_current_user)):
    """
    Adds a new notification email for the current user's family.
    """
    query = notification_emails.insert().values(
        family_id=current_user['family_id'],
        email=email_data.email
    )
    email_id = await database.execute(query)
    return NotificationEmail(id=email_id, email=email_data.email)

@app.put("/api/notifications/emails/{email_id}")
async def update_notification_email(email_id: int, email_data: AddNotificationEmail, current_user = Depends(get_current_user)):
    """
    Updates an existing notification email for the current user's family.
    """
    query = notification_emails.update().where(
        (notification_emails.c.id == email_id) & 
        (notification_emails.c.family_id == current_user['family_id'])
    ).values(email=email_data.email)
    await database.execute(query)
    return {"status": "success"}

@app.delete("/api/notifications/emails/{email_id}")
async def delete_notification_email(email_id: int, current_user = Depends(get_current_user)):
    """
    Deletes a notification email for the current user's family.
    """
    query = notification_emails.delete().where(
        (notification_emails.c.id == email_id) & 
        (notification_emails.c.family_id == current_user['family_id'])
    )
    await database.execute(query)
    return {"status": "success"}

@app.get("/api/family/emails", response_model=list[FamilyMemberEmail])
async def get_family_member_emails(current_user = Depends(get_current_user)):
    """
    Returns the email addresses of all family members (parents) for automatic population in alerts.
    """
    query = users.select().where(users.c.family_id == current_user['family_id']).order_by(users.c.first_name)
    family_members = await database.fetch_all(query)
    
    return [
        FamilyMemberEmail(
            id=str(member['id']),
            first_name=member['first_name'],
            email=member['email']
        )
        for member in family_members
    ]

@app.get("/api/family/members", response_model=list[FamilyMember])
async def get_family_members(current_user = Depends(get_current_user)):
    """
    Returns all family members with their contact information including phone numbers.
    """
    query = users.select().where(users.c.family_id == current_user['family_id']).order_by(users.c.first_name)
    family_members = await database.fetch_all(query)
    
    # Convert to FamilyMember models for logging and response
    family_member_models = [
        FamilyMember(
            id=str(member['id']),
            first_name=member['first_name'],
            last_name=member['last_name'],
            email=member['email'],
            phone_number=member['phone_number']
        )
        for member in family_members
    ]
    
    logger.info(f"Fetched {len(family_member_models)} family members: {[f'{m.first_name} {m.last_name} ({m.phone_number})' for m in family_member_models]}")
    
    return family_member_models

# ---------------------- Babysitters API ----------------------

@app.get("/api/babysitters", response_model=list[BabysitterResponse])
async def get_babysitters(current_user = Depends(get_current_user)):
    """
    Get all babysitters associated with the current user's family.
    """
    # Use SQLAlchemy query syntax instead of raw SQL
    query = babysitters.select().select_from(
        babysitters.join(babysitter_families, babysitters.c.id == babysitter_families.c.babysitter_id)
    ).where(
        babysitter_families.c.family_id == current_user['family_id']
    ).order_by(babysitters.c.first_name, babysitters.c.last_name)
    
    babysitter_records = await database.fetch_all(query)
    
    return [
        BabysitterResponse(
            id=record['id'],
            first_name=record['first_name'],
            last_name=record['last_name'],
            phone_number=record['phone_number'],
            rate=float(record['rate']) if record['rate'] else None,
            notes=record['notes'],
            created_by_user_id=str(record['created_by_user_id']),
            created_at=str(record['created_at'])
        )
        for record in babysitter_records
    ]

@app.post("/api/babysitters", response_model=BabysitterResponse)
async def create_babysitter(babysitter_data: BabysitterCreate, current_user = Depends(get_current_user)):
    """
    Create a new babysitter and associate with the current user's family.
    """
    try:
        # Insert babysitter
        babysitter_insert = babysitters.insert().values(
            first_name=babysitter_data.first_name,
            last_name=babysitter_data.last_name,
            phone_number=babysitter_data.phone_number,
            rate=babysitter_data.rate,
            notes=babysitter_data.notes,
            created_by_user_id=current_user['id']
        )
        babysitter_id = await database.execute(babysitter_insert)
        
        # Associate with family
        family_insert = babysitter_families.insert().values(
            babysitter_id=babysitter_id,
            family_id=current_user['family_id'],
            added_by_user_id=current_user['id']
        )
        await database.execute(family_insert)
        
        # Fetch the created babysitter
        babysitter_record = await database.fetch_one(babysitters.select().where(babysitters.c.id == babysitter_id))
        
        return BabysitterResponse(
            id=babysitter_record['id'],
            first_name=babysitter_record['first_name'],
            last_name=babysitter_record['last_name'],
            phone_number=babysitter_record['phone_number'],
            rate=float(babysitter_record['rate']) if babysitter_record['rate'] else None,
            notes=babysitter_record['notes'],
            created_by_user_id=str(babysitter_record['created_by_user_id']),
            created_at=str(babysitter_record['created_at'])
        )
    except Exception as e:
        logger.error(f"Error creating babysitter: {e}")
        raise HTTPException(status_code=500, detail="Failed to create babysitter")

@app.put("/api/babysitters/{babysitter_id}", response_model=BabysitterResponse)
async def update_babysitter(babysitter_id: int, babysitter_data: BabysitterCreate, current_user = Depends(get_current_user)):
    """
    Update a babysitter that belongs to the current user's family.
    """
    # Check if babysitter belongs to user's family using SQLAlchemy syntax
    check_query = babysitters.select().select_from(
        babysitters.join(babysitter_families, babysitters.c.id == babysitter_families.c.babysitter_id)
    ).where(
        (babysitters.c.id == babysitter_id) & 
        (babysitter_families.c.family_id == current_user['family_id'])
    )
    existing = await database.fetch_one(check_query)
    if not existing:
        raise HTTPException(status_code=404, detail="Babysitter not found")
    
    # Update babysitter
    update_query = babysitters.update().where(babysitters.c.id == babysitter_id).values(
        first_name=babysitter_data.first_name,
        last_name=babysitter_data.last_name,
        phone_number=babysitter_data.phone_number,
        rate=babysitter_data.rate,
        notes=babysitter_data.notes
    )
    await database.execute(update_query)
    
    # Fetch updated record
    babysitter_record = await database.fetch_one(babysitters.select().where(babysitters.c.id == babysitter_id))
    
    return BabysitterResponse(
        id=babysitter_record['id'],
        first_name=babysitter_record['first_name'],
        last_name=babysitter_record['last_name'],
        phone_number=babysitter_record['phone_number'],
        rate=float(babysitter_record['rate']) if babysitter_record['rate'] else None,
        notes=babysitter_record['notes'],
        created_by_user_id=str(babysitter_record['created_by_user_id']),
        created_at=str(babysitter_record['created_at'])
    )

@app.delete("/api/babysitters/{babysitter_id}")
async def delete_babysitter(babysitter_id: int, current_user = Depends(get_current_user)):
    """
    Remove a babysitter from the current user's family (deletes the association, not the babysitter).
    """
    # Delete the family association
    delete_query = babysitter_families.delete().where(
        (babysitter_families.c.babysitter_id == babysitter_id) &
        (babysitter_families.c.family_id == current_user['family_id'])
    )
    result = await database.execute(delete_query)
    
    if result == 0:
        raise HTTPException(status_code=404, detail="Babysitter not found in your family")
    
    return {"status": "success", "message": "Babysitter removed from family"}

# ---------------------- Emergency Contacts API ----------------------

@app.get("/api/emergency-contacts", response_model=list[EmergencyContactResponse])
async def get_emergency_contacts(current_user = Depends(get_current_user)):
    """
    Get all emergency contacts for the current user's family.
    """
    query = emergency_contacts.select().where(
        emergency_contacts.c.family_id == current_user['family_id']
    ).order_by(emergency_contacts.c.first_name, emergency_contacts.c.last_name)
    
    contact_records = await database.fetch_all(query)
    
    return [
        EmergencyContactResponse(
            id=record['id'],
            first_name=record['first_name'],
            last_name=record['last_name'],
            phone_number=record['phone_number'],
            relationship=record['relationship'],
            notes=record['notes'],
            created_by_user_id=str(record['created_by_user_id']),
            created_at=str(record['created_at'])
        )
        for record in contact_records
    ]

@app.post("/api/emergency-contacts", response_model=EmergencyContactResponse)
async def create_emergency_contact(contact_data: EmergencyContactCreate, current_user = Depends(get_current_user)):
    """
    Create a new emergency contact for the current user's family.
    """
    try:
        insert_query = emergency_contacts.insert().values(
            family_id=current_user['family_id'],
            first_name=contact_data.first_name,
            last_name=contact_data.last_name,
            phone_number=contact_data.phone_number,
            relationship=contact_data.relationship,
            notes=contact_data.notes,
            created_by_user_id=current_user['id']
        )
        contact_id = await database.execute(insert_query)
        
        # Fetch the created contact
        contact_record = await database.fetch_one(emergency_contacts.select().where(emergency_contacts.c.id == contact_id))
        
        return EmergencyContactResponse(
            id=contact_record['id'],
            first_name=contact_record['first_name'],
            last_name=contact_record['last_name'],
            phone_number=contact_record['phone_number'],
            relationship=contact_record['relationship'],
            notes=contact_record['notes'],
            created_by_user_id=str(contact_record['created_by_user_id']),
            created_at=str(contact_record['created_at'])
        )
    except Exception as e:
        logger.error(f"Error creating emergency contact: {e}")
        raise HTTPException(status_code=500, detail="Failed to create emergency contact")

@app.put("/api/emergency-contacts/{contact_id}", response_model=EmergencyContactResponse)
async def update_emergency_contact(contact_id: int, contact_data: EmergencyContactCreate, current_user = Depends(get_current_user)):
    """
    Update an emergency contact that belongs to the current user's family.
    """
    # Check if contact belongs to user's family
    existing = await database.fetch_one(
        emergency_contacts.select().where(
            (emergency_contacts.c.id == contact_id) &
            (emergency_contacts.c.family_id == current_user['family_id'])
        )
    )
    if not existing:
        raise HTTPException(status_code=404, detail="Emergency contact not found")
    
    # Update contact
    update_query = emergency_contacts.update().where(emergency_contacts.c.id == contact_id).values(
        first_name=contact_data.first_name,
        last_name=contact_data.last_name,
        phone_number=contact_data.phone_number,
        relationship=contact_data.relationship,
        notes=contact_data.notes
    )
    await database.execute(update_query)
    
    # Fetch updated record
    contact_record = await database.fetch_one(emergency_contacts.select().where(emergency_contacts.c.id == contact_id))
    
    return EmergencyContactResponse(
        id=contact_record['id'],
        first_name=contact_record['first_name'],
        last_name=contact_record['last_name'],
        phone_number=contact_record['phone_number'],
        relationship=contact_record['relationship'],
        notes=contact_record['notes'],
        created_by_user_id=str(contact_record['created_by_user_id']),
        created_at=str(contact_record['created_at'])
    )

@app.delete("/api/emergency-contacts/{contact_id}")
async def delete_emergency_contact(contact_id: int, current_user = Depends(get_current_user)):
    """
    Delete an emergency contact that belongs to the current user's family.
    """
    delete_query = emergency_contacts.delete().where(
        (emergency_contacts.c.id == contact_id) &
        (emergency_contacts.c.family_id == current_user['family_id'])
    )
    result = await database.execute(delete_query)
    
    if result == 0:
        raise HTTPException(status_code=404, detail="Emergency contact not found")
    
    return {"status": "success", "message": "Emergency contact deleted"}



# ---------------------- Group Chat API ----------------------

@app.post("/api/group-chat")
async def create_or_get_group_chat(chat_data: GroupChatCreate, current_user = Depends(get_current_user)):
    """
    Create a group chat identifier or return existing one for the given contact.
    This prevents duplicate group chats for the same contact.
    """
    # Check if group chat already exists
    existing_query = group_chats.select().where(
        (group_chats.c.family_id == current_user['family_id']) &
        (group_chats.c.contact_type == chat_data.contact_type) &
        (group_chats.c.contact_id == chat_data.contact_id)
    )
    existing_chat = await database.fetch_one(existing_query)
    
    if existing_chat:
        return {
            "group_identifier": existing_chat['group_identifier'],
            "exists": True,
            "created_at": str(existing_chat['created_at'])
        }
    
    # Create new group chat identifier
    import hashlib
    import time
    
    # Generate unique group identifier
    unique_string = f"{current_user['family_id']}-{chat_data.contact_type}-{chat_data.contact_id}-{time.time()}"
    group_identifier = hashlib.md5(unique_string.encode()).hexdigest()[:16]
    
    try:
        insert_query = group_chats.insert().values(
            family_id=current_user['family_id'],
            contact_type=chat_data.contact_type,
            contact_id=chat_data.contact_id,
            group_identifier=group_identifier,
            created_by_user_id=current_user['id']
        )
        await database.execute(insert_query)
        
        return {
            "group_identifier": group_identifier,
            "exists": False,
            "created_at": str(datetime.now())
        }
    except Exception as e:
        logger.error(f"Error creating group chat: {e}")
        raise HTTPException(status_code=500, detail="Failed to create group chat")

async def send_custody_change_notification(sender_id: uuid.UUID, family_id: uuid.UUID, event_date: date):
    # logger.info("Attempting to send custody change notification...")
    
    if not apns_client:
        logger.warning("APNs client not configured or initialized. Skipping push notification. Check APNS env vars.")
        return

    # logger.info(f"Searching for other user in family '{family_id}' who is not sender '{sender_id}'.")
    other_user_query = users.select().where((users.c.family_id == family_id) & (users.c.id != sender_id))
    other_user = await database.fetch_one(other_user_query)

    if not other_user:
        logger.warning(f"Could not find another user in family '{family_id}' to notify.")
        return
        
    # logger.info(f"Found other user: {other_user['first_name']} (ID: {other_user['id']}). Checking for APNs token.")

    if not other_user['apns_token']:
        logger.warning(f"User {other_user['first_name']} does not have an APNs token. Cannot send notification.")
        return

    # logger.info(f"User {other_user['first_name']} has an APNs token. Proceeding with notification creation.")
        
    sender = await database.fetch_one(users.select().where(users.c.id == sender_id))
    sender_name = sender['first_name'] if sender else "Someone"
    
    # Get the new custodian info for the changed date
    custodian_query = custody.select().where(
        (custody.c.family_id == family_id) & 
        (custody.c.date == event_date)
    )
    custody_record = await database.fetch_one(custodian_query)
    
    # Get custodian name
    custodian_name = "Unknown"
    if custody_record:
        custodian = await database.fetch_one(users.select().where(users.c.id == custody_record['custodian_id']))
        custodian_name = custodian['first_name'] if custodian else "Unknown"
    
    # Format the date nicely
    formatted_date = event_date.strftime('%A, %B %-d')
    
    # Create enhanced notification payload
    payload = Payload(
        alert={
            "title": "📅 Schedule Updated",
            "subtitle": f"{custodian_name} now has custody",
            "body": f"{sender_name} changed the schedule for {formatted_date}. Tap to manage your schedule."
        },
        sound="default",
        badge=1,
        category="CUSTODY_CHANGE",  # For custom actions
        custom={
            "type": "custody_change",
            "date": event_date.isoformat(),
            "custodian": custodian_name,
            "sender": sender_name,
            "deep_link": "calndr://schedule"  # Deep link to schedule view
        }
    )
    
    try:
        # logger.info(f"Sending enhanced APNs notification to {other_user['first_name']} about {custodian_name} having custody on {formatted_date}")
        # Run the synchronous APNs call in a separate thread
        await asyncio.to_thread(apns_client.send_notification, other_user['apns_token'], payload, topic=APNS_TOPIC)
        # logger.info("Enhanced push notification sent successfully.")
    except Exception as e:
        logger.error(f"Failed to send push notification: {e}")
        logger.error(f"Full APNs error traceback: {traceback.format_exc()}")

# ---------------------- School Events Caching ----------------------
SCHOOL_EVENTS_CACHE: Optional[List[Dict[str, Any]]] = None
SCHOOL_EVENTS_CACHE_TIME: Optional[datetime] = None
SCHOOL_EVENTS_CACHE_TTL_HOURS = 24

async def fetch_school_events() -> List[Dict[str, str]]:
    """Scrape school closing events and return list of {date, title}. Uses 24-hour in-memory cache."""
    global SCHOOL_EVENTS_CACHE, SCHOOL_EVENTS_CACHE_TIME
    # Return cached copy if fresh
    if SCHOOL_EVENTS_CACHE and SCHOOL_EVENTS_CACHE_TIME:
        if datetime.now(timezone.utc) - SCHOOL_EVENTS_CACHE_TIME < timedelta(hours=SCHOOL_EVENTS_CACHE_TTL_HOURS):
            return SCHOOL_EVENTS_CACHE

    import re
    from bs4 import BeautifulSoup

    logger.info("Fetching school events from The Learning Tree website …")
    events: Dict[str, str] = {}
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
        soup = BeautifulSoup(html, "html.parser")
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
    return SCHOOL_EVENTS_CACHE

# -------------------------------------------------------------------

# ---------------------- Children API ----------------------

@app.get("/api/children", response_model=list[ChildResponse])
async def get_children(current_user = Depends(get_current_user)):
    """
    Get all children for the current user's family.
    """
    query = children.select().where(
        children.c.family_id == current_user['family_id']
    ).order_by(children.c.dob.desc())  # Newest first
    
    child_records = await database.fetch_all(query)
    
    return [
        ChildResponse(
            id=uuid_to_string(record['id']),
            first_name=record['first_name'],
            last_name=record['last_name'],
            dob=str(record['dob']),
            family_id=uuid_to_string(record['family_id'])
        )
        for record in child_records
    ]

@app.post("/api/children", response_model=ChildResponse)
async def create_child(child_data: ChildCreate, current_user = Depends(get_current_user)):
    """
    Create a new child for the current user's family.
    """
    try:
        # Parse the date string
        dob_date = datetime.strptime(child_data.dob, '%Y-%m-%d').date()
        
        # Generate UUID for new child
        child_id = uuid.uuid4()
        
        # Insert child
        child_insert = children.insert().values(
            id=child_id,
            family_id=current_user['family_id'],
            first_name=child_data.first_name,
            last_name=child_data.last_name,
            dob=dob_date
        )
        await database.execute(child_insert)
        
        # Fetch the created child
        child_record = await database.fetch_one(children.select().where(children.c.id == child_id))
        
        return ChildResponse(
            id=uuid_to_string(child_record['id']),
            first_name=child_record['first_name'],
            last_name=child_record['last_name'],
            dob=str(child_record['dob']),
            family_id=uuid_to_string(child_record['family_id'])
        )
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")
    except Exception as e:
        logger.error(f"Error creating child: {e}")
        raise HTTPException(status_code=500, detail="Failed to create child")

@app.put("/api/children/{child_id}", response_model=ChildResponse)
async def update_child(child_id: str, child_data: ChildCreate, current_user = Depends(get_current_user)):
    """
    Update a child that belongs to the current user's family.
    """
    try:
        # Parse child_id as UUID
        child_uuid = uuid.UUID(child_id)
        
        # Check if child belongs to user's family
        check_query = children.select().where(
            (children.c.id == child_uuid) & 
            (children.c.family_id == current_user['family_id'])
        )
        existing = await database.fetch_one(check_query)
        if not existing:
            raise HTTPException(status_code=404, detail="Child not found")
        
        # Parse the date string
        dob_date = datetime.strptime(child_data.dob, '%Y-%m-%d').date()
        
        # Update child
        update_query = children.update().where(children.c.id == child_uuid).values(
            first_name=child_data.first_name,
            last_name=child_data.last_name,
            dob=dob_date
        )
        await database.execute(update_query)
        
        # Fetch updated record
        child_record = await database.fetch_one(children.select().where(children.c.id == child_uuid))
        
        return ChildResponse(
            id=uuid_to_string(child_record['id']),
            first_name=child_record['first_name'],
            last_name=child_record['last_name'],
            dob=str(child_record['dob']),
            family_id=uuid_to_string(child_record['family_id'])
        )
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid child ID or date format")
    except Exception as e:
        logger.error(f"Error updating child: {e}")
        raise HTTPException(status_code=500, detail="Failed to update child")

@app.delete("/api/children/{child_id}")
async def delete_child(child_id: str, current_user = Depends(get_current_user)):
    """
    Delete a child from the current user's family.
    """
    try:
        # Parse child_id as UUID
        child_uuid = uuid.UUID(child_id)
        
        # Check if child belongs to user's family
        check_query = children.select().where(
            (children.c.id == child_uuid) & 
            (children.c.family_id == current_user['family_id'])
        )
        existing = await database.fetch_one(check_query)
        if not existing:
            raise HTTPException(status_code=404, detail="Child not found")
        
        # Delete the child
        delete_query = children.delete().where(children.c.id == child_uuid)
        await database.execute(delete_query)
        
        return {"status": "success", "message": "Child deleted successfully"}
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid child ID format")
    except Exception as e:
        logger.error(f"Error deleting child: {e}")
        raise HTTPException(status_code=500, detail="Failed to delete child")

@app.get("/api/school-events")
async def get_school_events(current_user = Depends(get_current_user)):
    """Returns a JSON array of school events scraped from the Learning Tree website."""
    try:
        events = await fetch_school_events()
        return events
    except Exception as e:
        logger.error(f"Error retrieving school events: {e}")
        raise HTTPException(status_code=500, detail="Unable to retrieve school events")