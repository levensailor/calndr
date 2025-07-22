#!/usr/bin/env python3
"""
Database migration script to add school providers tables.
This adds the school_providers and school_calendar_syncs tables to the database.
"""

import asyncio
import asyncpg
import os
import uuid
from datetime import datetime

async def run_migration():
    """Run the migration to add school providers tables."""
    
    # Database connection parameters
    DATABASE_URL = os.getenv("DATABASE_URL")
    if not DATABASE_URL:
        print("❌ DATABASE_URL environment variable not set")
        return False
    
    try:
        # Connect to database
        print("🔗 Connecting to database...")
        conn = await asyncpg.connect(DATABASE_URL)
        
        print("📋 Creating school providers tables...")
        
        # Create school_providers table
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS school_providers (
                id SERIAL PRIMARY KEY,
                family_id UUID REFERENCES families(id) ON DELETE CASCADE NOT NULL,
                name VARCHAR(255) NOT NULL,
                address TEXT,
                phone_number VARCHAR(20),
                email VARCHAR(255),
                hours VARCHAR(255),
                notes TEXT,
                google_place_id VARCHAR(255),
                rating NUMERIC(3, 2),
                website VARCHAR(500),
                created_by_user_id UUID REFERENCES users(id) NOT NULL,
                created_at TIMESTAMP DEFAULT NOW(),
                updated_at TIMESTAMP DEFAULT NOW()
            );
        """)
        print("✅ Created school_providers table")
        
        # Create school_calendar_syncs table
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS school_calendar_syncs (
                id SERIAL PRIMARY KEY,
                school_provider_id INTEGER REFERENCES school_providers(id) ON DELETE CASCADE NOT NULL,
                calendar_url TEXT NOT NULL,
                last_sync_at TIMESTAMPTZ,
                last_sync_success BOOLEAN,
                last_sync_error TEXT,
                events_count INTEGER DEFAULT 0,
                sync_enabled BOOLEAN DEFAULT TRUE,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW()
            );
        """)
        print("✅ Created school_calendar_syncs table")
        
        # Create indexes for better performance
        await conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_school_providers_family_id 
            ON school_providers(family_id);
        """)
        
        await conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_school_calendar_syncs_provider_id 
            ON school_calendar_syncs(school_provider_id);
        """)
        print("✅ Created indexes")
        
        # Add update trigger for school_providers
        await conn.execute("""
            CREATE OR REPLACE FUNCTION update_school_providers_updated_at()
            RETURNS TRIGGER AS $$
            BEGIN
                NEW.updated_at = NOW();
                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql;
        """)
        
        await conn.execute("""
            DROP TRIGGER IF EXISTS trigger_update_school_providers_updated_at ON school_providers;
            CREATE TRIGGER trigger_update_school_providers_updated_at
                BEFORE UPDATE ON school_providers
                FOR EACH ROW
                EXECUTE FUNCTION update_school_providers_updated_at();
        """)
        
        # Add update trigger for school_calendar_syncs
        await conn.execute("""
            CREATE OR REPLACE FUNCTION update_school_calendar_syncs_updated_at()
            RETURNS TRIGGER AS $$
            BEGIN
                NEW.updated_at = NOW();
                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql;
        """)
        
        await conn.execute("""
            DROP TRIGGER IF EXISTS trigger_update_school_calendar_syncs_updated_at ON school_calendar_syncs;
            CREATE TRIGGER trigger_update_school_calendar_syncs_updated_at
                BEFORE UPDATE ON school_calendar_syncs
                FOR EACH ROW
                EXECUTE FUNCTION update_school_calendar_syncs_updated_at();
        """)
        print("✅ Created update triggers")
        
        print("🎉 School providers migration completed successfully!")
        
        # Close connection
        await conn.close()
        return True
        
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        return False

if __name__ == "__main__":
    print("🚀 Starting school providers migration...")
    success = asyncio.run(run_migration())
    if success:
        print("✅ Migration completed successfully!")
    else:
        print("❌ Migration failed!")
        exit(1) 