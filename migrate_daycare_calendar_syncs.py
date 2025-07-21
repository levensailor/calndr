#!/usr/bin/env python3

"""
Migration script to create daycare_calendar_syncs table.

This table tracks successfully configured calendar URLs for automatic syncing.
"""

import os
import sys
import asyncio
import asyncpg
from datetime import datetime

# Add the project root to the Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from backend.core.config import settings

async def create_daycare_calendar_syncs_table():
    """Create the daycare_calendar_syncs table for tracking sync configurations."""
    
    print("🔄 Creating daycare_calendar_syncs table...")
    
    conn = await asyncpg.connect(
        user=settings.DB_USER,
        password=settings.DB_PASSWORD,
        database=settings.DB_NAME,
        host=settings.DB_HOST,
        port=settings.DB_PORT
    )
    
    try:
        # Create the table
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS daycare_calendar_syncs (
                id SERIAL PRIMARY KEY,
                daycare_provider_id INTEGER NOT NULL REFERENCES daycare_providers(id) ON DELETE CASCADE,
                calendar_url TEXT NOT NULL,
                last_sync_at TIMESTAMP WITH TIME ZONE,
                last_sync_success BOOLEAN DEFAULT NULL,
                last_sync_error TEXT,
                events_count INTEGER DEFAULT 0,
                sync_enabled BOOLEAN DEFAULT TRUE,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(daycare_provider_id, calendar_url)
            );
        """)
        
        # Create index for efficient queries
        await conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_daycare_calendar_syncs_provider_id 
            ON daycare_calendar_syncs(daycare_provider_id);
        """)
        
        await conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_daycare_calendar_syncs_sync_enabled 
            ON daycare_calendar_syncs(sync_enabled);
        """)
        
        await conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_daycare_calendar_syncs_last_sync 
            ON daycare_calendar_syncs(last_sync_at);
        """)
        
        # Create trigger to update updated_at timestamp
        await conn.execute("""
            CREATE OR REPLACE FUNCTION update_daycare_calendar_syncs_updated_at()
            RETURNS TRIGGER AS $$
            BEGIN
                NEW.updated_at = CURRENT_TIMESTAMP;
                RETURN NEW;
            END;
            $$ language 'plpgsql';
        """)
        
        await conn.execute("""
            DROP TRIGGER IF EXISTS update_daycare_calendar_syncs_updated_at 
            ON daycare_calendar_syncs;
        """)
        
        await conn.execute("""
            CREATE TRIGGER update_daycare_calendar_syncs_updated_at 
            BEFORE UPDATE ON daycare_calendar_syncs 
            FOR EACH ROW EXECUTE FUNCTION update_daycare_calendar_syncs_updated_at();
        """)
        
        print("✅ Successfully created daycare_calendar_syncs table with indexes and triggers")
        
    except Exception as e:
        print(f"❌ Error creating daycare_calendar_syncs table: {e}")
        raise
    finally:
        await conn.close()

async def main():
    """Run the migration."""
    print("🚀 Starting daycare calendar syncs table migration...")
    await create_daycare_calendar_syncs_table()
    print("✅ Migration completed successfully!")

if __name__ == "__main__":
    asyncio.run(main()) 