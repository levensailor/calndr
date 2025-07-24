import sqlalchemy
from sqlalchemy import create_engine
from datetime import datetime
import os
from dotenv import load_dotenv

load_dotenv()

# Build DATABASE_URL from individual components
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")
DB_NAME = os.getenv("DB_NAME")

DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
engine = create_engine(DATABASE_URL)

# Add daycare_sync_id to families table
add_daycare_sync_field_sql = """
-- Add daycare_sync_id field to families table
ALTER TABLE families 
ADD COLUMN IF NOT EXISTS daycare_sync_id INTEGER REFERENCES daycare_calendar_syncs(id) ON DELETE SET NULL;

-- Add school_sync_id field to families table for consistency
ALTER TABLE families 
ADD COLUMN IF NOT EXISTS school_sync_id INTEGER REFERENCES school_calendar_syncs(id) ON DELETE SET NULL;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_families_daycare_sync ON families(daycare_sync_id);
CREATE INDEX IF NOT EXISTS idx_families_school_sync ON families(school_sync_id);
"""

# Update families with their active daycare syncs
update_families_with_syncs_sql = """
-- Update families with their active daycare syncs
UPDATE families f
SET daycare_sync_id = (
    SELECT dcs.id
    FROM daycare_calendar_syncs dcs
    JOIN daycare_providers dp ON dcs.daycare_provider_id = dp.id
    WHERE dp.family_id = f.id
    AND dcs.sync_enabled = TRUE
    LIMIT 1  -- In case there are multiple, take the first active one
);

-- Update families with their active school syncs
UPDATE families f
SET school_sync_id = (
    SELECT scs.id
    FROM school_calendar_syncs scs
    JOIN school_providers sp ON scs.school_provider_id = sp.id
    WHERE sp.family_id = f.id
    AND scs.sync_enabled = TRUE
    LIMIT 1  -- In case there are multiple, take the first active one
);
"""

# Update the family_all_events view with the new logic
updated_family_all_events_view_sql = """
CREATE OR REPLACE VIEW family_all_events AS
-- Regular family events
SELECT 
    e.id,
    e.family_id,
    e.date as event_date,
    e.content as title,
    NULL as description,
    e.event_type,
    NULL as start_time,
    NULL as end_time,
    FALSE as all_day,
    'family' as source_type,
    NULL as provider_id,
    NULL as provider_name
FROM events e
WHERE e.event_type = 'regular'

UNION ALL

-- School events for families with active school sync
SELECT 
    se.id,
    f.id as family_id,
    se.event_date,
    se.title,
    se.description,
    se.event_type,
    se.start_time,
    se.end_time,
    se.all_day,
    'school' as source_type,
    sp.id as provider_id,
    sp.name as provider_name
FROM school_events se
JOIN school_calendar_syncs scs ON se.school_provider_id = scs.school_provider_id
JOIN families f ON f.school_sync_id = scs.id
JOIN school_providers sp ON se.school_provider_id = sp.id
WHERE scs.sync_enabled = TRUE

UNION ALL

-- Daycare events for families with active daycare sync
SELECT 
    de.id,
    f.id as family_id,
    de.event_date,
    de.title,
    de.description,
    de.event_type,
    de.start_time,
    de.end_time,
    de.all_day,
    'daycare' as source_type,
    dp.id as provider_id,
    dp.name as provider_name
FROM daycare_events de
JOIN daycare_calendar_syncs dcs ON de.daycare_provider_id = dcs.daycare_provider_id
JOIN families f ON f.daycare_sync_id = dcs.id
JOIN daycare_providers dp ON de.daycare_provider_id = dp.id
WHERE dcs.sync_enabled = TRUE;
"""

if __name__ == "__main__":
    with engine.connect() as conn:
        print("Adding daycare_sync_id and school_sync_id fields to families table...")
        conn.execute(sqlalchemy.text(add_daycare_sync_field_sql))
        conn.commit()
        
        print("Updating families with their active sync relationships...")
        result = conn.execute(sqlalchemy.text(update_families_with_syncs_sql))
        conn.commit()
        
        print("Updating family_all_events view with new logic...")
        conn.execute(sqlalchemy.text(updated_family_all_events_view_sql))
        conn.commit()
        
        # Check results
        print("Checking sync assignments...")
        families_with_daycare = conn.execute(sqlalchemy.text("""
            SELECT f.id, f.name, f.daycare_sync_id, dp.name as daycare_name
            FROM families f
            LEFT JOIN daycare_calendar_syncs dcs ON f.daycare_sync_id = dcs.id
            LEFT JOIN daycare_providers dp ON dcs.daycare_provider_id = dp.id
            WHERE f.daycare_sync_id IS NOT NULL
        """)).fetchall()
        
        print(f"Found {len(families_with_daycare)} families with daycare syncs:")
        for family in families_with_daycare:
            print(f"  - Family '{family[1]}' (ID: {family[0]}) -> Daycare: {family[3]} (Sync ID: {family[2]})")
        
        families_with_school = conn.execute(sqlalchemy.text("""
            SELECT f.id, f.name, f.school_sync_id, sp.name as school_name
            FROM families f
            LEFT JOIN school_calendar_syncs scs ON f.school_sync_id = scs.id
            LEFT JOIN school_providers sp ON scs.school_provider_id = sp.id
            WHERE f.school_sync_id IS NOT NULL
        """)).fetchall()
        
        print(f"Found {len(families_with_school)} families with school syncs:")
        for family in families_with_school:
            print(f"  - Family '{family[1]}' (ID: {family[0]}) -> School: {family[3]} (Sync ID: {family[2]})")
        
        print("Migration completed successfully!") 