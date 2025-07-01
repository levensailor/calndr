#!/usr/bin/env python3
"""
Database migration script to create the new custody table and migrate existing custody data.
This script should be run on the server after deploying the updated backend code.
"""

import os
import databases
import sqlalchemy
from dotenv import load_dotenv
import asyncio
from datetime import datetime

# Load environment variables
load_dotenv()

# Database configuration
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME")

DATABASE_URL = f"postgresql+asyncpg://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
database = databases.Database(DATABASE_URL)

# For creating tables
sync_engine = sqlalchemy.create_engine(DATABASE_URL.replace("+asyncpg", ""))
metadata = sqlalchemy.MetaData()

# SQL to create the custody table
CREATE_CUSTODY_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS custody (
    id SERIAL PRIMARY KEY,
    family_id UUID NOT NULL REFERENCES families(id),
    date DATE NOT NULL,
    actor_id UUID NOT NULL REFERENCES users(id),
    custodian_id UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_family_date_custody UNIQUE (family_id, date)
);
"""

async def main():
    """Main migration function"""
    print("Starting custody table migration...")
    
    try:
        await database.connect()
        
        # Check if custody table already exists
        table_exists_query = """
        SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'custody'
        );
        """
        table_exists = await database.fetch_val(table_exists_query)
        
        if table_exists:
            print("✅ Custody table already exists, skipping creation")
        else:
            # Create the custody table using raw SQL
            print("📊 Creating custody table...")
            await database.execute(CREATE_CUSTODY_TABLE_SQL)
            print("✅ Created custody table")
        
        # Check if there are any existing custody events in the events table to migrate
        existing_custody_query = """
        SELECT COUNT(*) FROM events WHERE event_type = 'custody' OR custodian_id IS NOT NULL;
        """
        
        try:
            existing_custody_count = await database.fetch_val(existing_custody_query)
            print(f"📊 Found {existing_custody_count} existing custody events in events table")
            
            if existing_custody_count > 0:
                # Migrate existing custody data
                print("🔄 Migrating existing custody data from events table...")
                
                # Get all custody events from events table
                migration_query = """
                SELECT 
                    family_id, 
                    date, 
                    custodian_id,
                    family_id as actor_id  -- Use family_id as actor_id since we don't have this info
                FROM events 
                WHERE custodian_id IS NOT NULL
                ORDER BY date;
                """
                
                custody_events = await database.fetch_all(migration_query)
                
                migrated_count = 0
                for event in custody_events:
                    # Check if this custody record already exists
                    existing_check = await database.fetch_val(
                        "SELECT COUNT(*) FROM custody WHERE family_id = :family_id AND date = :date",
                        {"family_id": event["family_id"], "date": event["date"]}
                    )
                    
                    if existing_check == 0:
                        # Insert into custody table
                        await database.execute(
                            """
                            INSERT INTO custody (family_id, date, actor_id, custodian_id, created_at)
                            VALUES (:family_id, :date, :actor_id, :custodian_id, :created_at)
                            """,
                            {
                                "family_id": event["family_id"],
                                "date": event["date"],
                                "actor_id": event["actor_id"],
                                "custodian_id": event["custodian_id"],
                                "created_at": datetime.now()
                            }
                        )
                        migrated_count += 1
                
                print(f"✅ Migrated {migrated_count} custody records to new custody table")
            
        except Exception as e:
            print(f"ℹ️  No existing events table or custody data to migrate: {e}")
        
        # Verify the migration
        custody_count = await database.fetch_val("SELECT COUNT(*) FROM custody")
        print(f"📊 Total custody records in new table: {custody_count}")
        
        print("✅ Custody table migration completed successfully!")
        
    except Exception as e:
        print(f"❌ Error during custody table migration: {e}")
        raise
    finally:
        if database.is_connected:
            await database.disconnect()
            print("🔌 Database connection closed.")

if __name__ == "__main__":
    if not all([DB_USER, DB_PASSWORD, DB_HOST, DB_NAME]):
        print("❌ ERROR: Missing required environment variables.")
        exit(1)
    else:
        asyncio.run(main()) 