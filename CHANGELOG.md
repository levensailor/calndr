# CHANGELOG

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