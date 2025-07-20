from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from datetime import datetime
import uuid

from core.database import database
from core.security import verify_password, create_access_token, get_password_hash, uuid_to_string
from core.logging import logger
from db.models import users, families
from schemas.auth import Token
from schemas.user import UserRegistration, UserRegistrationResponse
from services.email_service import email_service
from services.sms_service import sms_service
import traceback

router = APIRouter()

@router.post("/token", response_model=Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends()):
    """Authenticate user and return access token."""
    query = users.select().where(users.c.email == form_data.username)
    user = await database.fetch_one(query)
    
    if not user or not verify_password(form_data.password, user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Update last_signed_in timestamp
    await database.execute(
        users.update().where(users.c.id == user['id']).values(last_signed_in=datetime.now())
    )
    
    access_token = create_access_token(
        data={"sub": uuid_to_string(user["id"]), "family_id": uuid_to_string(user["family_id"])}
    )
    return {"access_token": access_token, "token_type": "bearer"}

@router.post("/register", response_model=UserRegistrationResponse)
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
        password_hash = get_password_hash(registration_data.password)
        
        # Handle coparent linking or family creation
        family_id = None
        family_name = f"{registration_data.last_name} Family"  # Default family name
        
        if registration_data.coparent_email or registration_data.coparent_phone:
            # Check if coparent already exists
            coparent_query = None
            if registration_data.coparent_email:
                coparent_query = users.select().where(users.c.email == registration_data.coparent_email)
            elif registration_data.coparent_phone:
                coparent_query = users.select().where(users.c.phone_number == registration_data.coparent_phone)

            existing_coparent = await database.fetch_one(coparent_query) if coparent_query is not None else None
            
            if existing_coparent:
                # Use existing coparent's family
                family_id = existing_coparent['family_id']
                logger.info(f"Linking user to existing coparent's family: {family_id}")
            else:
                # Create new family and send invitation email
                family_id = uuid.uuid4()
                family_insert = families.insert().values(id=family_id, name=family_name)
                await database.execute(family_insert)
                logger.info(f"Created new family: {family_name} with ID: {family_id}")
                
                # Send invitation via email or SMS
                try:
                    if registration_data.coparent_email:
                        await email_service.send_coparent_invitation(
                            coparent_email=registration_data.coparent_email,
                            inviter_name=registration_data.first_name,
                            family_id=family_id
                        )
                    elif registration_data.coparent_phone:
                        await sms_service.send_coparent_invitation(
                            coparent_phone=registration_data.coparent_phone,
                            inviter_name=registration_data.first_name,
                            family_id=family_id
                        )
                except Exception as e:
                    logger.error(f"Error sending coparent invitation: {e}")
        else:
            # Create family without coparent
            family_id = uuid.uuid4()
            family_insert = families.insert().values(id=family_id, name=family_name)
            await database.execute(family_insert)
            logger.info(f"Created family without coparent: {family_name} with ID: {family_id}")
        
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
