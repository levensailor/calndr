import sqlalchemy
from sqlalchemy import create_engine, Column, Integer, String, Date, DateTime, ForeignKey, Boolean, Text, Time
from sqlalchemy.dialects.postgresql import UUID
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

# Create school_events table
school_events_sql = """
CREATE TABLE IF NOT EXISTS school_events (
    id SERIAL PRIMARY KEY,
    school_provider_id INTEGER NOT NULL REFERENCES school_providers(id) ON DELETE CASCADE,
    event_date DATE NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    event_type VARCHAR(50), -- holiday, closure, early_dismissal, event, etc.
    start_time TIME,
    end_time TIME,
    all_day BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Create index for efficient lookups
    CONSTRAINT unique_school_event UNIQUE (school_provider_id, event_date, title)
);

CREATE INDEX idx_school_events_provider_date ON school_events(school_provider_id, event_date);
CREATE INDEX idx_school_events_date ON school_events(event_date);
"""

# Create daycare_events table
daycare_events_sql = """
CREATE TABLE IF NOT EXISTS daycare_events (
    id SERIAL PRIMARY KEY,
    daycare_provider_id INTEGER NOT NULL REFERENCES daycare_providers(id) ON DELETE CASCADE,
    event_date DATE NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    event_type VARCHAR(50), -- holiday, closure, early_dismissal, event, etc.
    start_time TIME,
    end_time TIME,
    all_day BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Create index for efficient lookups
    CONSTRAINT unique_daycare_event UNIQUE (daycare_provider_id, event_date, title)
);

CREATE INDEX idx_daycare_events_provider_date ON daycare_events(daycare_provider_id, event_date);
CREATE INDEX idx_daycare_events_date ON daycare_events(event_date);
"""

# Create a view to get all events for a family (including school and daycare events)
family_all_events_view_sql = """
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

-- School events for families with school sync
SELECT 
    se.id,
    sp.family_id,
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
JOIN school_providers sp ON se.school_provider_id = sp.id
JOIN school_calendar_syncs scs ON sp.id = scs.school_provider_id
WHERE scs.sync_enabled = TRUE

UNION ALL

-- Daycare events for families with daycare sync
SELECT 
    de.id,
    dp.family_id,
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
JOIN daycare_providers dp ON de.daycare_provider_id = dp.id
JOIN daycare_calendar_syncs dcs ON dp.id = dcs.daycare_provider_id
WHERE dcs.sync_enabled = TRUE;
"""

# Migrate existing school and daycare events from the events table
migrate_school_events_sql = """
-- Migrate existing school events to the new table
INSERT INTO school_events (school_provider_id, event_date, title, description, event_type, all_day, created_at)
SELECT DISTINCT
    sp.id as school_provider_id,
    e.date as event_date,
    e.content as title,
    NULL as description,
    'imported' as event_type,
    TRUE as all_day,
    NOW() as created_at
FROM events e
JOIN school_providers sp ON e.family_id = sp.family_id
WHERE e.event_type = 'school'
ON CONFLICT (school_provider_id, event_date, title) DO NOTHING;
"""

migrate_daycare_events_sql = """
-- Migrate existing daycare events to the new table
INSERT INTO daycare_events (daycare_provider_id, event_date, title, description, event_type, all_day, created_at)
SELECT DISTINCT
    dp.id as daycare_provider_id,
    e.date as event_date,
    e.content as title,
    NULL as description,
    'imported' as event_type,
    TRUE as all_day,
    NOW() as created_at
FROM events e
JOIN daycare_providers dp ON e.family_id = dp.family_id
WHERE e.event_type = 'daycare'
ON CONFLICT (daycare_provider_id, event_date, title) DO NOTHING;
"""

# Remove old school and daycare events from events table
cleanup_old_events_sql = """
-- Remove school and daycare events from the main events table
DELETE FROM events WHERE event_type IN ('school', 'daycare');
"""

if __name__ == "__main__":
    with engine.connect() as conn:
        print("Creating school_events table...")
        conn.execute(sqlalchemy.text(school_events_sql))
        conn.commit()
        
        print("Creating daycare_events table...")
        conn.execute(sqlalchemy.text(daycare_events_sql))
        conn.commit()
        
        print("Creating family_all_events view...")
        conn.execute(sqlalchemy.text(family_all_events_view_sql))
        conn.commit()
        
        print("Migrating existing school events...")
        result = conn.execute(sqlalchemy.text(migrate_school_events_sql))
        print(f"Migrated {result.rowcount} school events")
        conn.commit()
        
        print("Migrating existing daycare events...")
        result = conn.execute(sqlalchemy.text(migrate_daycare_events_sql))
        print(f"Migrated {result.rowcount} daycare events")
        conn.commit()
        
        print("Cleaning up old events...")
        result = conn.execute(sqlalchemy.text(cleanup_old_events_sql))
        print(f"Removed {result.rowcount} old school/daycare events from events table")
        conn.commit()
        
        print("Migration completed successfully!")