from typing import Optional, List
from pydantic import BaseModel

class DaycareProviderCreate(BaseModel):
    name: str
    address: Optional[str] = None
    phone_number: Optional[str] = None
    email: Optional[str] = None
    hours: Optional[str] = None
    notes: Optional[str] = None
    google_place_id: Optional[str] = None
    rating: Optional[float] = None
    website: Optional[str] = None

class DaycareProviderResponse(BaseModel):
    id: int
    name: str
    address: Optional[str] = None
    phone_number: Optional[str] = None
    email: Optional[str] = None
    hours: Optional[str] = None
    notes: Optional[str] = None
    google_place_id: Optional[str] = None
    rating: Optional[float] = None
    website: Optional[str] = None
    created_by_user_id: str
    created_at: str
    updated_at: str

class DaycareSearchRequest(BaseModel):
    location_type: str  # "current" or "zipcode"
    zipcode: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    radius: Optional[int] = 5000  # meters, default 5km

class DaycareSearchResult(BaseModel):
    place_id: str
    name: str
    address: str
    phone_number: Optional[str] = None
    rating: Optional[float] = None
    website: Optional[str] = None
    hours: Optional[str] = None
    distance: Optional[float] = None  # distance in meters
