#!/usr/bin/env python3
"""
Migration script to add reminders table to the database
"""

import os
import asyncio
import databases
import sqlalchemy
from dotenv import load_dotenv

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

async def migrate_reminders_table():
    """Add reminders table to the database if it doesn't exist"""
    
    print("Starting reminders table migration...")
    
    try:
        await database.connect()
        
        # Check if table already exists
        table_exists_query = """
        SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_name = 'reminders'
        );
        """
        
        table_exists = await database.fetch_val(table_exists_query)
        
        if not table_exists:
            print("📋 Creating reminders table...")
            create_table_query = """
            CREATE TABLE reminders (
                id SERIAL PRIMARY KEY,
                family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
                date DATE NOT NULL,
                text TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT NOW(),
                updated_at TIMESTAMP DEFAULT NOW(),
                UNIQUE(family_id, date)
            );
            """
            await database.execute(create_table_query)
            print("✅ Created reminders table")
            
            # Create indexes for better performance
            index_queries = [
                "CREATE INDEX IF NOT EXISTS idx_reminders_family_id ON reminders(family_id);",
                "CREATE INDEX IF NOT EXISTS idx_reminders_date ON reminders(date);",
                "CREATE INDEX IF NOT EXISTS idx_reminders_family_date ON reminders(family_id, date);"
            ]
            
            for index_query in index_queries:
                await database.execute(index_query)
                print("✅ Created index")
        else:
            print("📋 reminders table already exists, skipping creation")
        
        print("✅ Reminders table migration completed successfully")
        
    except Exception as e:
        print(f"❌ Error during reminders table migration: {e}")
        raise
    finally:
        await database.disconnect()

if __name__ == "__main__":
    asyncio.run(migrate_reminders_table()) 