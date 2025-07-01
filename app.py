import os
import databases
import sqlalchemy
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy import create_engine, inspect
from dotenv import load_dotenv
from datetime import date, datetime, timedelta, timezone
from fastapi import FastAPI, Depends, HTTPException, status, Form
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from pydantic import BaseModel, EmailStr
from typing import Optional
import logging
from passlib.context import CryptContext
import uuid
from apns2.client import APNsClient
from apns2.payload import Payload
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

# --- Environment variables ---
load_dotenv()

# --- Logging ---
logging.basicConfig(level=logging.INFO)
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
    sqlalchemy.Column("custodian_id", UUID(as_uuid=True), sqlalchemy.ForeignKey("users.id"), nullable=True),
    sqlalchemy.Column("event_type", sqlalchemy.String, default='custody', nullable=False),
    # Add other event columns if needed
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

# --- FastAPI Lifespan ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    await database.connect()
    yield
    await database.disconnect()

app = FastAPI(lifespan=lifespan)

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
    return {
        "custodian_one": {"id": str(family_members[0]['id']), "first_name": family_members[0]['first_name']},
        "custodian_two": {"id": str(family_members[1]['id']), "first_name": family_members[1]['first_name']},
    }

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
async def get_events(year: int, month: int, current_user: User = Depends(get_current_user)):
    # Calculate start and end dates for the month
    start_date = date(year, month, 1)
    if month == 12:
        end_date = date(year + 1, 1, 1) - timedelta(days=1)
    else:
        end_date = date(year, month + 1, 1) - timedelta(days=1)
        
    query = events.select().where(
        (events.c.family_id == current_user.family_id) &
        (events.c.date.between(start_date, end_date))
    )
    db_events = await database.fetch_all(query)
    
    # Get family members to map custodian IDs to names
    family_query = users.select().where(users.c.family_id == current_user.family_id).order_by(users.c.first_name)
    family_members = await database.fetch_all(family_query)
    
    # Create a mapping from custodian ID to name (for backward compatibility)
    custodian_map = {}
    if len(family_members) >= 2:
        custodian_map[str(family_members[0]['id'])] = 'jeff'
        custodian_map[str(family_members[1]['id'])] = 'deanna'
    
    # Convert events to the format expected by frontend
    frontend_events = []
    for event in db_events:
        if event['custodian_id']:
            # This is a custody event - convert to old format
            custodian_name = custodian_map.get(str(event['custodian_id']), 'unknown')
            frontend_events.append({
                'id': event['id'],
                'event_date': str(event['date']),
                'content': custodian_name,
                'position': 4  # Custody events are always position 4
            })
        # Note: Non-custody events would be handled here if they existed
        
    return frontend_events

@app.post("/api/events")
async def save_event(request: dict, current_user: User = Depends(get_current_user)):
    try:
        logger.info(f"Received event request: {request}")
        
        # Handle both new format (Event) and old format (LegacyEvent)
        if 'custodian_id' in request and 'date' in request:
            # New format for custody events
            logger.info("Using new format (custody event)")
            event = Event(**request)
            event_date = event.date
            custodian_id = event.custodian_id
        elif 'event_date' in request and 'position' in request:
            # Old format - need to convert
            logger.info("Using legacy format - converting to new format")
            legacy_event = LegacyEvent(**request)
            event_date = datetime.strptime(legacy_event.event_date, '%Y-%m-%d').date()
            
            if legacy_event.position == 4:  # Custody event
                logger.info(f"Legacy custody event: {legacy_event.content}")
                # Map content to custodian_id
                family_query = users.select().where(users.c.family_id == current_user.family_id).order_by(users.c.first_name)
                family_members = await database.fetch_all(family_query)
                
                if len(family_members) >= 2:
                    if legacy_event.content == 'jeff':
                        custodian_id = family_members[0]['id']
                    elif legacy_event.content == 'deanna':
                        custodian_id = family_members[1]['id']
                    else:
                        raise HTTPException(status_code=400, detail="Invalid custodian name")
                else:
                    raise HTTPException(status_code=400, detail="Family not found")
            else:
                # Non-custody events not supported in new schema yet
                raise HTTPException(status_code=400, detail="Non-custody events not supported")
        else:
            raise HTTPException(status_code=400, detail="Invalid event format")

        # Check for an existing event for that date
        existing_event_query = events.select().where(
            (events.c.family_id == current_user.family_id) & (events.c.date == event_date)
        )
        existing_event = await database.fetch_one(existing_event_query)

        if existing_event:
            # Update existing event
            query = events.update().where(events.c.id == existing_event['id']).values(custodian_id=custodian_id)
            await database.execute(query)
        else:
            # Create new event
            query = events.insert().values(
                family_id=current_user.family_id,
                date=event_date,
                custodian_id=custodian_id,
            )
            await database.execute(query)
        
        await send_custody_change_notification(current_user.id, current_user.family_id, event_date)
        
        # Return the state of the event from the DB in frontend-compatible format
        final_event = await database.fetch_one(events.select().where(
            (events.c.family_id == current_user.family_id) & (events.c.date == event_date)
        ))
        
        # Get family members to map custodian ID to name
        family_query = users.select().where(users.c.family_id == current_user.family_id).order_by(users.c.first_name)
        family_members = await database.fetch_all(family_query)
        
        # Create a mapping from custodian ID to name
        custodian_map = {}
        if len(family_members) >= 2:
            custodian_map[str(family_members[0]['id'])] = 'jeff'
            custodian_map[str(family_members[1]['id'])] = 'deanna'
        
        # Convert to frontend format
        if final_event and final_event['custodian_id']:
            custodian_name = custodian_map.get(str(final_event['custodian_id']), 'unknown')
            return {
                'id': final_event['id'],
                'event_date': str(final_event['date']),
                'content': custodian_name,
                'position': 4
            }
        
        return final_event
    
    except Exception as e:
        logger.error(f"Error in save_event: {e}")
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