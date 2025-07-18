from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from datetime import datetime
import uuid
import httpx

from core.database import database
from core.security import get_current_user, uuid_to_string
from core.logging import logger
from core.config import settings
from db.models import daycare_providers
from schemas.daycare import DaycareProvider, DaycareProviderCreate, DaycareSearchRequest, DaycareSearchResult

router = APIRouter()

@router.get("/", response_model=List[DaycareProvider])
async def get_daycare_providers(current_user = Depends(get_current_user)):
    """
    Get all daycare providers for the current user's family.
    """
    query = daycare_providers.select().where(
        daycare_providers.c.family_id == current_user['family_id']
    ).order_by(daycare_providers.c.created_at.desc())
    
    provider_records = await database.fetch_all(query)
    
    return [
        DaycareProvider(
            id=record['id'],
            name=record['name'],
            address=record['address'],
            phoneNumber=record['phone_number'],
            email=record['email'],
            hours=record['hours'],
            notes=record['notes'],
            googlePlaceId=record['google_place_id'],
            rating=record['rating'],
            website=record['website'],
            createdByUserId=uuid_to_string(record['created_by_user_id']),
            createdAt=record['created_at'].isoformat(),
            updatedAt=record['updated_at'].isoformat()
        )
        for record in provider_records
    ]

@router.post("/", response_model=DaycareProvider, status_code=status.HTTP_201_CREATED)
async def create_daycare_provider(provider: DaycareProviderCreate, current_user = Depends(get_current_user)):
    """
    Create a new daycare provider for the current user's family.
    """
    now = datetime.utcnow()
    values = {
        "name": provider.name,
        "address": provider.address,
        "phone_number": provider.phone_number,
        "email": provider.email,
        "hours": provider.hours,
        "notes": provider.notes,
        "google_place_id": provider.google_place_id,
        "rating": provider.rating,
        "website": provider.website,
        "family_id": current_user['family_id'],
        "created_by_user_id": current_user['id'],
        "created_at": now,
        "updated_at": now
    }
    
    query = daycare_providers.insert().values(**values)
    provider_id = await database.execute(query)
    
    # Fetch the created provider
    created_provider = await database.fetch_one(
        daycare_providers.select().where(daycare_providers.c.id == provider_id)
    )
    
    return DaycareProvider(
        id=created_provider['id'],
        name=created_provider['name'],
        address=created_provider['address'],
        phoneNumber=created_provider['phone_number'],
        email=created_provider['email'],
        hours=created_provider['hours'],
        notes=created_provider['notes'],
        googlePlaceId=created_provider['google_place_id'],
        rating=created_provider['rating'],
        website=created_provider['website'],
        createdByUserId=uuid_to_string(created_provider['created_by_user_id']),
        createdAt=created_provider['created_at'].isoformat(),
        updatedAt=created_provider['updated_at'].isoformat()
    )

@router.put("/{provider_id}", response_model=DaycareProvider)
async def update_daycare_provider(
    provider_id: int, 
    provider: DaycareProviderCreate, 
    current_user = Depends(get_current_user)
):
    """
    Update an existing daycare provider.
    """
    # Check if provider exists and belongs to user's family
    existing_provider = await database.fetch_one(
        daycare_providers.select().where(
            (daycare_providers.c.id == provider_id) & 
            (daycare_providers.c.family_id == current_user['family_id'])
        )
    )
    
    if not existing_provider:
        raise HTTPException(status_code=404, detail="Daycare provider not found")
    
    values = {
        "name": provider.name,
        "address": provider.address,
        "phone_number": provider.phone_number,
        "email": provider.email,
        "hours": provider.hours,
        "notes": provider.notes,
        "google_place_id": provider.google_place_id,
        "rating": provider.rating,
        "website": provider.website,
        "updated_at": datetime.utcnow()
    }
    
    query = daycare_providers.update().where(
        daycare_providers.c.id == provider_id
    ).values(**values)
    
    await database.execute(query)
    
    # Fetch the updated provider
    updated_provider = await database.fetch_one(
        daycare_providers.select().where(daycare_providers.c.id == provider_id)
    )
    
    return DaycareProvider(
        id=updated_provider['id'],
        name=updated_provider['name'],
        address=updated_provider['address'],
        phoneNumber=updated_provider['phone_number'],
        email=updated_provider['email'],
        hours=updated_provider['hours'],
        notes=updated_provider['notes'],
        googlePlaceId=updated_provider['google_place_id'],
        rating=updated_provider['rating'],
        website=updated_provider['website'],
        createdByUserId=uuid_to_string(updated_provider['created_by_user_id']),
        createdAt=updated_provider['created_at'].isoformat(),
        updatedAt=updated_provider['updated_at'].isoformat()
    )

@router.delete("/{provider_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_daycare_provider(provider_id: int, current_user = Depends(get_current_user)):
    """
    Delete a daycare provider.
    """
    # Check if provider exists and belongs to user's family
    existing_provider = await database.fetch_one(
        daycare_providers.select().where(
            (daycare_providers.c.id == provider_id) & 
            (daycare_providers.c.family_id == current_user['family_id'])
        )
    )
    
    if not existing_provider:
        raise HTTPException(status_code=404, detail="Daycare provider not found")
    
    query = daycare_providers.delete().where(daycare_providers.c.id == provider_id)
    await database.execute(query)
    
    return None

@router.post("/search", response_model=List[DaycareSearchResult])
async def search_daycare_providers(
    search_request: DaycareSearchRequest,
    current_user = Depends(get_current_user)
):
    """
    Search for daycare providers using Google Places API.
    This returns an array of search results.
    """
    # Mock implementation - replace with actual Google Places API call
    # For now, return empty array to match expected structure
    return []
