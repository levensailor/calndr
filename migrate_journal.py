#!/usr/bin/env python3

import asyncio
import asyncpg
import os
import sys
from datetime import datetime

# Add the backend directory to sys.path to import from core
sys.path.append('backend')

from core.config import Settings

async def migrate_journal():
    """Migrate database to add journal entries table"""
    
    # Use the same database configuration as the app
    settings = Settings()
    database_url = settings.DATABASE_URL.replace("+asyncpg", "")  # Remove the +asyncpg for asyncpg connection
    
    try:
        # Connect to database
        conn = await asyncpg.connect(database_url)
        print("Connected to database successfully")
        
        # Create journal_entries table
        create_journal_table = """
        CREATE TABLE IF NOT EXISTS journal_entries (
            id SERIAL PRIMARY KEY,
            family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            title VARCHAR(255),
            content TEXT NOT NULL,
            entry_date DATE NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        """
        
        await conn.execute(create_journal_table)
        print("✅ Created journal_entries table")
        
        # Add index for better performance
        create_index = """
        CREATE INDEX IF NOT EXISTS idx_journal_entries_family_date 
        ON journal_entries(family_id, entry_date DESC);
        """
        
        await conn.execute(create_index)
        print("✅ Created index on journal_entries")
        
        # Add trigger to update updated_at
        create_trigger = """
        CREATE OR REPLACE FUNCTION update_updated_at_column()
        RETURNS TRIGGER AS $$
        BEGIN
            NEW.updated_at = CURRENT_TIMESTAMP;
            RETURN NEW;
        END;
        $$ language 'plpgsql';
        
        DROP TRIGGER IF EXISTS update_journal_entries_updated_at ON journal_entries;
        CREATE TRIGGER update_journal_entries_updated_at
            BEFORE UPDATE ON journal_entries
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();
        """
        
        await conn.execute(create_trigger)
        print("✅ Created updated_at trigger")
        
        await conn.close()
        print("✅ Journal migration completed successfully!")
        
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        return False
    
    return True

if __name__ == "__main__":
    asyncio.run(migrate_journal()) 