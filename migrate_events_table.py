#!/usr/bin/env python3
"""
Migration script to add missing content and position fields to events table
This fixes the mismatch between API expectations and database schema
"""

import os
import asyncio
import sqlalchemy
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Database connection
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME")

DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

async def migrate_events_table():
    """
    Add missing content and position fields to events table
    """
    engine = create_engine(DATABASE_URL)
    
    try:
        print("🔧 Starting events table migration...")
        
        with engine.connect() as connection:
            # Check if columns already exist
            result = connection.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'events' 
                AND column_name IN ('content', 'position', 'event_type')
            """))
            existing_columns = [row[0] for row in result.fetchall()]
            
            # Add event_type column if it doesn't exist
            if 'event_type' not in existing_columns:
                print("➕ Adding 'event_type' column to events table...")
                connection.execute(text("""
                    ALTER TABLE events 
                    ADD COLUMN event_type VARCHAR(255) NOT NULL DEFAULT 'regular'
                """))
                connection.commit()
                print("✅ Added 'event_type' column")
            else:
                print("ℹ️  'event_type' column already exists")
            
            # Add content column if it doesn't exist
            if 'content' not in existing_columns:
                print("➕ Adding 'content' column to events table...")
                connection.execute(text("""
                    ALTER TABLE events 
                    ADD COLUMN content VARCHAR(255) NULL
                """))
                connection.commit()
                print("✅ Added 'content' column")
            else:
                print("ℹ️  'content' column already exists")
            
            # Add position column if it doesn't exist  
            if 'position' not in existing_columns:
                print("➕ Adding 'position' column to events table...")
                connection.execute(text("""
                    ALTER TABLE events 
                    ADD COLUMN position INTEGER NULL
                """))
                connection.commit()
                print("✅ Added 'position' column")
            else:
                print("ℹ️  'position' column already exists")
            
            # Update default event_type to 'regular' instead of 'custody'
            print("🔄 Updating default event_type...")
            connection.execute(text("""
                ALTER TABLE events 
                ALTER COLUMN event_type SET DEFAULT 'regular'
            """))
            connection.commit()
            print("✅ Updated event_type default value")
            
        print("🎉 Events table migration completed successfully!")
        
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        raise
    
    finally:
        engine.dispose()

if __name__ == "__main__":
    asyncio.run(migrate_events_table())