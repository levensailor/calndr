# CHANGELOG

## [2024-01-24] - Dedicated School and Daycare Events API Endpoints

### Added
- **School events API**: New `/api/v1/events/school/{year}/{month}` endpoint for school-specific events
- **Daycare events API**: New `/api/v1/events/daycare/{year}/{month}` endpoint for daycare-specific events
- **Date range support**: Added `/api/v1/events/school/?start_date=X&end_date=Y` and `/api/v1/events/daycare/?start_date=X&end_date=Y` for flexible date queries
- **Family sync integration**: Endpoints automatically resolve events based on family's active sync relationships

### Technical Implementation
- **Sync relationship chain**: User → Family → Sync ID → Provider ID → Events table
- **Query optimization**: Direct joins through family sync IDs for efficient event retrieval
- **Event formatting**: Provider name prefixed to event titles for clear identification
- **Complete metadata**: Includes description, start/end times, all_day flags, and event types
- **Authentication**: Secured endpoints requiring valid user authentication
- **Error handling**: Comprehensive error responses for invalid dates and missing syncs

### API Endpoints
```
GET /api/v1/events/school/2025/7          # School events for July 2025
GET /api/v1/events/daycare/2025/7         # Daycare events for July 2025
GET /api/v1/events/school/?start_date=2025-07-01&end_date=2025-07-31
GET /api/v1/events/daycare/?start_date=2025-07-01&end_date=2025-07-31
```

## [2024-01-24] - Single Text Field Event Modal

### Changed
- **Event modal redesign**: Replaced 4 position-based text fields with a single large TextEditor that spans the modal height
- **Simplified event model**: Made position field optional in Event model and backend schemas
- **Streamlined API**: Removed position requirements from events endpoints - only event_date and content are required
- **Enhanced user experience**: Events now display as a single cohesive text area for easier multi-line note taking

### Removed
- **Position-based layout**: Eliminated the rigid 4-position system for event display
- **Position validation**: Removed position field from API responses and validation logic
- **Position sorting**: Removed position-based sorting in calendar views

### Technical Details
- Updated `FocusedDayView.swift` to use `TextEditor` instead of multiple `TextField` components
- Modified `CalendarViewModel.swift` methods to work without position dependency
- Updated event filtering across `DayView`, `ThreeDayView`, and `DayContentView` to exclude only custody events
- Made `position` field optional in `Event` model and `LegacyEvent` schema
- Simplified save/update event logic to handle single text content

## [2024-01-24] - Family Sync Management System

### Added
- **Direct family sync relationships**: Added `daycare_sync_id` and `school_sync_id` fields to families table
- **Automatic sync assignment**: When calendar syncs are created, they're automatically assigned to the owning family
- **Sync management service**: Created comprehensive service for managing sync relationships between families and providers
- **Enhanced database view**: Updated `family_all_events` view to use direct family sync relationships for better performance

### Changed  
- **Improved sync logic**: Events now display based on direct family sync assignments rather than complex joins
- **Provider endpoints**: Updated school and daycare provider endpoints to automatically manage family sync assignments
- **Database efficiency**: Simplified the relationship between families and their calendar syncs

### Technical Details
- Added foreign key relationships: `families.daycare_sync_id` → `daycare_calendar_syncs.id`
- Added foreign key relationships: `families.school_sync_id` → `school_calendar_syncs.id`
- Created indexes for optimal query performance
- Migrated existing data: Levensailor family now has both daycare and school syncs

### Verification
✅ Family calendar displays daycare events from "The Learning Tree" when daycare sync is active  
✅ Family calendar displays school events from "Gregory Elementary" when school sync is active  
✅ Events properly filtered based on family sync agreements  
✅ Production deployment successful with HTTP 200 health check

## [2024-01-21] - Major Refactoring: School and Daycare Events Architecture

### Changed
- **Separated school and daycare events into dedicated tables**: Events are now stored in `school_events` and `daycare_events` tables indexed by provider ID instead of family ID
- **Improved efficiency**: Events are stored once per provider, eliminating duplicate storage across families
- **Added database view**: Created `family_all_events` view that combines family, school, and daycare events based on sync agreements
- **Updated API endpoints**: Modified events endpoints to use the new view for seamless event retrieval
- **Enhanced sync service**: Created unified `event_sync_service.py` to manage all calendar syncing operations

### Added
- New database tables: `school_events` and `daycare_events` with proper indexes
- New schemas: `SchoolEvent` and `DaycareEvent` with bulk operations support
- New sync script: `sync_all_calendars.py` for periodic updates
- New cron setup: `setup_calendar_sync_cron.sh` for automated daily syncing

### Migration
- Created `migrate_school_daycare_events_tables.py` to:
  - Create new tables with proper structure
  - Migrate existing events from the old format
  - Create the unified events view
  - Clean up old event data

### Benefits
- **Performance**: Significantly reduced database storage and query time
- **Scalability**: Events are stored once per provider, not duplicated per family
- **Maintainability**: Clear separation of concerns between different event types
- **Flexibility**: Easy to add new event sources in the future