# Backend Medical API Implementation Prompt

## Overview
We need to implement a comprehensive medical management system for the Calndr app with two main components:
1. **Medical Providers (Doctors)** - Location-based search and management
2. **Medications** - Tracking with reminders and scheduling

## Database Schema Requirements

### Medical Providers Table
```sql
CREATE TABLE medical_providers (
    id SERIAL PRIMARY KEY,
    family_id VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    specialty VARCHAR(255),
    address TEXT,
    phone VARCHAR(50),
    email VARCHAR(255),
    website VARCHAR(500),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    zip_code VARCHAR(20),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (family_id) REFERENCES families(id) ON DELETE CASCADE
);
```

### Medications Table
```sql
CREATE TABLE medications (
    id SERIAL PRIMARY KEY,
    family_id VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    dosage VARCHAR(100),
    frequency VARCHAR(100),
    instructions TEXT,
    start_date DATE,
    end_date DATE,
    is_active BOOLEAN DEFAULT true,
    reminder_enabled BOOLEAN DEFAULT false,
    reminder_time TIME,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (family_id) REFERENCES families(id) ON DELETE CASCADE
);
```

## API Endpoints Required

### Medical Providers Endpoints

#### 1. GET /api/v1/medical-providers
- **Purpose**: Fetch all medical providers for the authenticated family
- **Authentication**: Required (JWT token)
- **Response**: Array of MedicalProvider objects
- **Features**: 
  - Filter by specialty (optional query param)
  - Sort by name, distance, or recently added
  - Pagination support

#### 2. POST /api/v1/medical-providers
- **Purpose**: Create a new medical provider
- **Authentication**: Required (JWT token)
- **Request Body**: MedicalProviderCreate object
- **Response**: Created MedicalProvider object
- **Features**:
  - Validate required fields (name, family_id)
  - Auto-geocode address if coordinates not provided
  - Sanitize phone numbers and emails

#### 3. GET /api/v1/medical-providers/{id}
- **Purpose**: Fetch specific medical provider details
- **Authentication**: Required (JWT token)
- **Response**: MedicalProvider object
- **Features**: Verify family ownership

#### 4. PUT /api/v1/medical-providers/{id}
- **Purpose**: Update medical provider information
- **Authentication**: Required (JWT token)
- **Request Body**: MedicalProviderUpdate object
- **Response**: Updated MedicalProvider object
- **Features**: Partial updates, validate family ownership

#### 5. DELETE /api/v1/medical-providers/{id}
- **Purpose**: Delete medical provider
- **Authentication**: Required (JWT token)
- **Response**: Success message
- **Features**: Verify family ownership, soft delete option

#### 6. GET /api/v1/medical-providers/search
- **Purpose**: Search medical providers by location or name
- **Authentication**: Required (JWT token)
- **Query Parameters**:
  - `q`: Search query (name, specialty, address)
  - `lat`: Latitude for distance-based search
  - `lng`: Longitude for distance-based search
  - `radius`: Search radius in miles (default: 25)
  - `specialty`: Filter by medical specialty
- **Response**: Array of MedicalProvider objects with distance info
- **Features**:
  - Geocoding for address-based searches
  - Distance calculation using Haversine formula
  - Integration with external medical provider APIs (optional)

### Medications Endpoints

#### 1. GET /api/v1/medications
- **Purpose**: Fetch all medications for the authenticated family
- **Authentication**: Required (JWT token)
- **Response**: Array of Medication objects
- **Features**:
  - Filter by active status
  - Filter by reminder enabled
  - Sort by name, start date, or recently added
  - Pagination support

#### 2. POST /api/v1/medications
- **Purpose**: Create a new medication
- **Authentication**: Required (JWT token)
- **Request Body**: MedicationCreate object
- **Response**: Created Medication object
- **Features**:
  - Validate required fields (name, family_id)
  - Validate date ranges (start_date <= end_date)
  - Auto-schedule reminders if enabled
  - Integration with notification system

#### 3. GET /api/v1/medications/{id}
- **Purpose**: Fetch specific medication details
- **Authentication**: Required (JWT token)
- **Response**: Medication object
- **Features**: Verify family ownership

#### 4. PUT /api/v1/medications/{id}
- **Purpose**: Update medication information
- **Authentication**: Required (JWT token)
- **Request Body**: MedicationUpdate object
- **Response**: Updated Medication object
- **Features**:
  - Partial updates
  - Validate family ownership
  - Update reminder schedules if changed
  - Handle active/inactive status changes

#### 5. DELETE /api/v1/medications/{id}
- **Purpose**: Delete medication
- **Authentication**: Required (JWT token)
- **Response**: Success message
- **Features**: Verify family ownership, cancel associated reminders

#### 6. GET /api/v1/medications/active
- **Purpose**: Fetch only active medications
- **Authentication**: Required (JWT token)
- **Response**: Array of active Medication objects
- **Features**: Filter by current date within start/end date range

#### 7. GET /api/v1/medications/reminders
- **Purpose**: Fetch medications with active reminders
- **Authentication**: Required (JWT token)
- **Response**: Array of medications with reminder info
- **Features**: Include next reminder time, frequency info

## Additional Features Required

### 1. Location Services
- **Geocoding**: Convert addresses to coordinates using Google Maps API or similar
- **Reverse Geocoding**: Convert coordinates to addresses
- **Distance Calculation**: Calculate distances between locations
- **Location Validation**: Validate coordinates and addresses

### 2. Reminder System Integration
- **Scheduling**: Create/update/delete reminder schedules
- **Notification Integration**: Connect with existing notification system
- **Time Zone Handling**: Proper timezone support for reminders
- **Recurring Reminders**: Handle different medication frequencies

### 3. Data Validation
- **Phone Number Formatting**: Standardize phone number formats
- **Email Validation**: Proper email format validation
- **Date Range Validation**: Ensure start_date <= end_date
- **Required Field Validation**: Validate all required fields

### 4. Security & Privacy
- **Family Isolation**: Ensure data is only accessible to family members
- **Data Encryption**: Encrypt sensitive medical information
- **Audit Logging**: Log all CRUD operations for compliance
- **HIPAA Considerations**: Follow medical data privacy guidelines

### 5. Performance Optimizations
- **Database Indexing**: Index on family_id, name, specialty, coordinates
- **Caching**: Cache frequently accessed medical provider data
- **Pagination**: Implement efficient pagination for large datasets
- **Bulk Operations**: Support bulk create/update operations

## Error Handling
- **400 Bad Request**: Invalid input data
- **401 Unauthorized**: Missing or invalid authentication
- **403 Forbidden**: Family ownership verification failed
- **404 Not Found**: Medical provider or medication not found
- **422 Unprocessable Entity**: Validation errors
- **500 Internal Server Error**: Server-side errors

## Response Format
All responses should follow the existing API pattern:
```json
{
  "success": true,
  "data": {...},
  "message": "Operation completed successfully"
}
```

## Testing Requirements
- Unit tests for all CRUD operations
- Integration tests for API endpoints
- Location service tests
- Reminder system integration tests
- Security and authorization tests
- Performance tests for large datasets

## Implementation Priority
1. Database schema creation
2. Basic CRUD endpoints for medical providers
3. Basic CRUD endpoints for medications
4. Location search functionality
5. Reminder system integration
6. Advanced features (geocoding, distance search)
7. Performance optimizations
8. Security enhancements

Please implement this medical management system following the existing codebase patterns and ensure proper integration with the current authentication and family management systems. 