import uuid
from typing import Optional
from pydantic import BaseModel, EmailStr
from schemas.base import BaseSchema

class UserBase(BaseSchema):
    """Base user schema."""
    first_name: str
    last_name: str
    email: EmailStr
    phone_number: Optional[str] = None

class UserCreate(UserBase):
    """Schema for creating a new user."""
    password: str

class UserUpdate(BaseSchema):
    """Schema for updating user information."""
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    email: Optional[EmailStr] = None
    phone_number: Optional[str] = None

class UserResponse(UserBase):
    """Schema for user response data."""
    id: str
    family_id: str
    subscription_type: Optional[str] = "Free"
    subscription_status: Optional[str] = "Active"
    profile_photo_url: Optional[str] = None
    status: Optional[str] = "active"
    last_signed_in: Optional[str] = None
    created_at: Optional[str] = None
    selected_theme: Optional[str] = None

class UserProfile(UserResponse):
    """Extended user profile schema."""
    pass

class UserRegistration(BaseSchema):
    """Schema for user registration."""
    first_name: str
    last_name: str
    email: EmailStr
    password: str
    phone_number: Optional[str] = None
    family_name: Optional[str] = None

class UserRegistrationResponse(BaseSchema):
    """Schema for user registration response."""
    user_id: str
    family_id: str
    access_token: str
    token_type: str = "bearer"
    message: str

class PasswordUpdate(BaseSchema):
    """Schema for password update."""
    current_password: str
    new_password: str
    dob: str  # Date string in YYYY-MM-DD format
    family_id: str

class UserPreferenceUpdate(BaseSchema):
    """Schema for updating user preferences."""
    selected_theme: str

class LocationUpdateRequest(BaseSchema):
    """Schema for updating user location."""
    latitude: float
    longitude: float

class FamilyMember(BaseSchema):
    """Schema for family member information."""
    id: str
    first_name: str
    last_name: str
    email: str
    phone_number: Optional[str] = None
    status: Optional[str] = "active"
    last_signed_in: Optional[str] = None
    last_known_location: Optional[str] = None
    last_known_location_timestamp: Optional[str] = None

class FamilyMemberEmail(BaseSchema):
    """Schema for family member email information."""
    id: str
    first_name: str
    email: str
