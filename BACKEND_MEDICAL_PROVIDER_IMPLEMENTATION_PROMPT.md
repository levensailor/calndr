# Backend Medical Provider Implementation Prompt

## Overview
I need you to implement the medical provider functionality for our calendar app backend. The iOS app is already built and working with the search functionality, but we need to create the backend API endpoints and database structure to support saving and managing medical providers.

## Current Status
✅ **Already Implemented:**
- Medical provider search using Google Places API (similar to daycare/school search)
- iOS app can search and display results 
- iOS app has UI for managing saved providers

❌ **Missing - Need Implementation:**
- Database table and model for medical_providers
- API endpoints for CRUD operations
- Pydantic schemas for request/response models

## Required Implementation

### 1. Database Table Creation
Create a `medical_providers` table with the following structure:

```sql
CREATE TABLE medical_providers (
    id SERIAL PRIMARY KEY,
    family_id INTEGER NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    specialty VARCHAR(255),
    address TEXT,
    phone VARCHAR(50),
    email VARCHAR(255),
    website VARCHAR(500),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    zip_code VARCHAR(10),
    notes TEXT,
    google_place_id VARCHAR(255),
    rating DECIMAL(2, 1),
    created_by_user_id INTEGER NOT NULL REFERENCES users(id),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    INDEX idx_medical_providers_family_id (family_id),
    INDEX idx_medical_providers_created_by (created_by_user_id)
);
```

### 2. Database Model (db/models.py)
Add medical_providers table definition following the existing pattern used for daycare_providers and school_providers.

### 3. Pydantic Schemas (schemas/medical.py)
Create the following schemas:

```python
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class MedicalProviderCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    specialty: Optional[str] = Field(None, max_length=255)
    address: Optional[str] = None
    phone: Optional[str] = Field(None, max_length=50)
    email: Optional[str] = Field(None, max_length=255)
    website: Optional[str] = Field(None, max_length=500)
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    zip_code: Optional[str] = Field(None, max_length=10)
    notes: Optional[str] = None
    google_place_id: Optional[str] = Field(None, max_length=255)
    rating: Optional[float] = Field(None, ge=0, le=5)

class MedicalProviderUpdate(MedicalProviderCreate):
    name: Optional[str] = Field(None, min_length=1, max_length=255)

class MedicalProviderResponse(BaseModel):
    id: int
    name: str
    specialty: Optional[str]
    address: Optional[str]
    phone: Optional[str]
    email: Optional[str]
    website: Optional[str]
    latitude: Optional[float]
    longitude: Optional[float]
    zip_code: Optional[str]
    notes: Optional[str]
    google_place_id: Optional[str]
    rating: Optional[float]
    created_by_user_id: str
    created_at: str
    updated_at: str

# Search models (already exist but including for completeness)
class MedicalSearchRequest(BaseModel):
    location_type: str  # "current" or "zipcode"
    zipcode: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    radius: int = 5000

class MedicalSearchResult(BaseModel):
    id: str
    name: str
    specialty: Optional[str]
    address: str
    phoneNumber: Optional[str]  # Note: camelCase to match Google Places API
    website: Optional[str]
    rating: Optional[float]
    placeId: Optional[str]  # Note: camelCase to match Google Places API
    distance: Optional[float]
```

### 4. API Endpoints (backend/api/v1/endpoints/medical_providers.py)
Create a new file with the following endpoints following the exact pattern used in daycare_providers.py and school_providers.py:

#### GET /medical-providers
- Get all medical providers for the current user's family
- Response: List[MedicalProviderResponse]

#### POST /medical-providers  
- Create a new medical provider for the current user's family
- Request: MedicalProviderCreate
- Response: MedicalProviderResponse

#### PUT /medical-providers/{provider_id}
- Update an existing medical provider (must belong to user's family)
- Request: MedicalProviderUpdate  
- Response: MedicalProviderResponse

#### DELETE /medical-providers/{provider_id}
- Delete a medical provider (must belong to user's family)
- Response: 204 No Content

#### POST /medical-providers/search
- Search for medical providers using Google Places API
- Request: MedicalSearchRequest
- Response: {"results": List[MedicalSearchResult], "total": int}
- **Note:** This endpoint may already exist - check and implement if missing

### 5. Router Registration (backend/api/v1/api.py)
Add the medical_providers router to the main API router:

```python
from .endpoints import medical_providers

api_router.include_router(
    medical_providers.router, 
    prefix="/medical-providers", 
    tags=["medical-providers"]
)
```

### 6. Search Implementation Details
The search endpoint should use Google Places API with the query "medical facilities" or "hospitals" or "doctors" near the specified location. Follow the exact same pattern as daycare_providers.py search endpoint.

For location-based searches:
- Use Google Places Nearby Search API for coordinate-based searches
- Use Google Places Text Search API for ZIP code searches  
- Include these place types: hospital, doctor, health, pharmacy, physiotherapist, dentist

Response should include:
- distance (for current location searches)
- All standard place details (name, address, phone, rating, website, etc.)

### 7. Security & Validation
- All endpoints require authentication via `get_current_user` dependency
- Validate that users can only access providers belonging to their family
- Include proper error handling and logging
- Use the same security patterns as other provider endpoints

### 8. Database Migration
Create a migration script to add the medical_providers table if it doesn't exist.

## Testing Requirements
After implementation, test these scenarios:
1. Create a medical provider via API
2. List medical providers for a family
3. Update a medical provider
4. Delete a medical provider  
5. Search for medical providers by location
6. Search for medical providers by ZIP code
7. Verify cross-family isolation (users can't see other families' providers)

## iOS Integration Points
The iOS app expects these specific field names in responses:
- `phone` (not `phone_number`) 
- `zip_code` (snake_case)
- All other fields match the schema above

The search response must be wrapped in an object:
```json
{
  "results": [...],
  "total": 5
}
```

Search results use camelCase for `phoneNumber` and `placeId` to match Google Places API format.

## Implementation Priority
1. Database table and model
2. Pydantic schemas  
3. Basic CRUD endpoints (GET, POST, PUT, DELETE)
4. Search endpoint (if not already implemented)
5. Router registration
6. Testing

Follow the exact same patterns, error handling, logging, and security as the existing daycare_providers.py and school_providers.py implementations.