from fastapi import APIRouter, Depends, HTTPException
from typing import List
from datetime import datetime
import os
import httpx

from core.database import database
from core.security import get_current_user
from core.logging import logger
from db.models import daycare_providers
from schemas.daycare import DaycareProviderCreate, DaycareProviderResponse, DaycareSearchRequest, DaycareSearchResult

router = APIRouter()

@router.get("", response_model=List[DaycareProviderResponse])
async def get_daycare_providers(current_user = Depends(get_current_user)):
    """
    Get all daycare providers for the current user's family.
    """
    try:
        query = daycare_providers.select().where(daycare_providers.c.family_id == current_user['family_id'])
        providers = await database.fetch_all(query)
        
        return [
            DaycareProviderResponse(
                id=provider['id'],
                name=provider['name'],
                address=provider['address'],
                phone_number=provider['phone_number'],
                email=provider['email'],
                hours=provider['hours'],
                notes=provider['notes'],
                google_place_id=provider['google_place_id'],
                rating=float(provider['rating']) if provider['rating'] else None,
                website=provider['website'],
                created_by_user_id=str(provider['created_by_user_id']),
                created_at=str(provider['created_at']),
                updated_at=str(provider['updated_at'])
            )
            for provider in providers
        ]
    except Exception as e:
        logger.error(f"Error fetching daycare providers: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch daycare providers")

@router.post("", response_model=DaycareProviderResponse)
async def create_daycare_provider(provider_data: DaycareProviderCreate, current_user = Depends(get_current_user)):
    """
    Create a new daycare provider for the current user's family.
    """
    try:
        insert_query = daycare_providers.insert().values(
            family_id=current_user['family_id'],
            name=provider_data.name,
            address=provider_data.address,
            phone_number=provider_data.phone_number,
            email=provider_data.email,
            hours=provider_data.hours,
            notes=provider_data.notes,
            google_place_id=provider_data.google_place_id,
            rating=provider_data.rating,
            website=provider_data.website,
            created_by_user_id=current_user['id'],
            created_at=datetime.now(),
            updated_at=datetime.now()
        )
        
        provider_id = await database.execute(insert_query)
        
        # Fetch the created provider
        provider_record = await database.fetch_one(daycare_providers.select().where(daycare_providers.c.id == provider_id))
        
        return DaycareProviderResponse(
            id=provider_record['id'],
            name=provider_record['name'],
            address=provider_record['address'],
            phone_number=provider_record['phone_number'],
            email=provider_record['email'],
            hours=provider_record['hours'],
            notes=provider_record['notes'],
            google_place_id=provider_record['google_place_id'],
            rating=float(provider_record['rating']) if provider_record['rating'] else None,
            website=provider_record['website'],
            created_by_user_id=str(provider_record['created_by_user_id']),
            created_at=str(provider_record['created_at']),
            updated_at=str(provider_record['updated_at'])
        )
    except Exception as e:
        logger.error(f"Error creating daycare provider: {e}")
        raise HTTPException(status_code=500, detail="Failed to create daycare provider")

@router.put("/{provider_id}", response_model=DaycareProviderResponse)
async def update_daycare_provider(provider_id: int, provider_data: DaycareProviderCreate, current_user = Depends(get_current_user)):
    """
    Update a daycare provider that belongs to the current user's family.
    """
    try:
        # Check if provider exists and belongs to user's family
        check_query = daycare_providers.select().where(
            (daycare_providers.c.id == provider_id) &
            (daycare_providers.c.family_id == current_user['family_id'])
        )
        existing = await database.fetch_one(check_query)
        
        if not existing:
            raise HTTPException(status_code=404, detail="Daycare provider not found")
        
        # Update the provider
        update_query = daycare_providers.update().where(daycare_providers.c.id == provider_id).values(
            name=provider_data.name,
            address=provider_data.address,
            phone_number=provider_data.phone_number,
            email=provider_data.email,
            hours=provider_data.hours,
            notes=provider_data.notes,
            google_place_id=provider_data.google_place_id,
            rating=provider_data.rating,
            website=provider_data.website,
            updated_at=datetime.now()
        )
        await database.execute(update_query)
        
        # Fetch the updated provider
        provider_record = await database.fetch_one(daycare_providers.select().where(daycare_providers.c.id == provider_id))
        
        return DaycareProviderResponse(
            id=provider_record['id'],
            name=provider_record['name'],
            address=provider_record['address'],
            phone_number=provider_record['phone_number'],
            email=provider_record['email'],
            hours=provider_record['hours'],
            notes=provider_record['notes'],
            google_place_id=provider_record['google_place_id'],
            rating=float(provider_record['rating']) if provider_record['rating'] else None,
            website=provider_record['website'],
            created_by_user_id=str(provider_record['created_by_user_id']),
            created_at=str(provider_record['created_at']),
            updated_at=str(provider_record['updated_at'])
        )
    except Exception as e:
        logger.error(f"Error updating daycare provider: {e}")
        raise HTTPException(status_code=500, detail="Failed to update daycare provider")

@router.delete("/{provider_id}")
async def delete_daycare_provider(provider_id: int, current_user = Depends(get_current_user)):
    """
    Delete a daycare provider that belongs to the current user's family.
    """
    try:
        # Check if provider exists and belongs to user's family
        check_query = daycare_providers.select().where(
            (daycare_providers.c.id == provider_id) &
            (daycare_providers.c.family_id == current_user['family_id'])
        )
        existing = await database.fetch_one(check_query)
        
        if not existing:
            raise HTTPException(status_code=404, detail="Daycare provider not found")
        
        # Delete the provider
        delete_query = daycare_providers.delete().where(daycare_providers.c.id == provider_id)
        await database.execute(delete_query)
        
        return {"status": "success", "message": "Daycare provider deleted successfully"}
    except Exception as e:
        logger.error(f"Error deleting daycare provider: {e}")
        raise HTTPException(status_code=500, detail="Failed to delete daycare provider")

@router.post("/search", response_model=List[DaycareSearchResult])
async def search_daycare_providers(search_data: DaycareSearchRequest, current_user = Depends(get_current_user)):
    """
    Search for daycare providers using Google Places API.
    """
    try:
        # Get Google Places API key from environment
        google_api_key = os.getenv("GOOGLE_PLACES_API_KEY")
        if not google_api_key:
            raise HTTPException(status_code=500, detail="Google Places API key not configured")
        
        # Search for daycare providers using Google Places API
        if search_data.location_type == "zipcode" and search_data.zipcode:
            # Use Text Search API for ZIP code searches
            places_url = "https://maps.googleapis.com/maps/api/place/textsearch/json"
            params = {
                "query": f"daycare centers near {search_data.zipcode}",
                "key": google_api_key
            }
            use_distance_calculation = False  # No reference point for distance
        elif search_data.location_type == "current" and search_data.latitude and search_data.longitude:
            # Use Nearby Search API for current location searches
            places_url = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
            params = {
                "location": f"{search_data.latitude},{search_data.longitude}",
                "radius": search_data.radius,
                "type": "school",
                "keyword": "daycare OR childcare OR preschool OR nursery",
                "key": google_api_key
            }
            use_distance_calculation = True
            latitude = search_data.latitude
            longitude = search_data.longitude
        else:
            raise HTTPException(status_code=400, detail="Invalid location data")
        
        async with httpx.AsyncClient() as client:
            places_response = await client.get(places_url, params=params)
            places_data = places_response.json()
            
            if places_data.get("status") != "OK":
                logger.error(f"Google Places API error: {places_data.get('status')}")
                return []
            
            results = []
            for place in places_data.get("results", []):
                # Get additional details for each place
                place_id = place.get("place_id")
                details_url = "https://maps.googleapis.com/maps/api/place/details/json"
                details_params = {
                    "place_id": place_id,
                    "fields": "name,formatted_address,formatted_phone_number,rating,website,opening_hours",
                    "key": google_api_key
                }
                
                details_response = await client.get(details_url, params=details_params)
                details_data = details_response.json()
                
                if details_data.get("status") == "OK":
                    result = details_data.get("result", {})
                    
                    # Calculate distance (approximate) only for current location searches
                    distance = None
                    if use_distance_calculation:
                        place_location = place.get("geometry", {}).get("location", {})
                        if place_location:
                            # Simple distance calculation (not precise, but good enough for sorting)
                            lat_diff = abs(latitude - place_location.get("lat", 0))
                            lng_diff = abs(longitude - place_location.get("lng", 0))
                            distance = (lat_diff + lng_diff) * 111000  # Rough conversion to meters
                    
                    # Format opening hours
                    hours = None
                    if result.get("opening_hours"):
                        hours = "; ".join(result["opening_hours"].get("weekday_text", []))
                    
                    results.append(DaycareSearchResult(
                        place_id=place_id,
                        name=result.get("name", ""),
                        address=result.get("formatted_address", ""),
                        phone_number=result.get("formatted_phone_number"),
                        rating=result.get("rating"),
                        website=result.get("website"),
                        hours=hours,
                        distance=distance
                    ))
            
            # Sort by distance if available (current location searches) or by name (ZIP code searches)
            if use_distance_calculation:
                results.sort(key=lambda x: x.distance if x.distance else float('inf'))
            else:
                results.sort(key=lambda x: x.name.lower())
            
            return results
            
    except Exception as e:
        logger.error(f"Error searching daycare providers: {e}")
        raise HTTPException(status_code=500, detail="Failed to search daycare providers")
