from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from datetime import datetime

from core.database import database
from core.security import verify_password, create_access_token, get_password_hash, uuid_to_string
from core.logging import logger
from db.models import users, families
from schemas.auth import Token
from schemas.user import UserRegistration, UserRegistrationResponse
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
