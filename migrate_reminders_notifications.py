#!/usr/bin/env python3
"""
Migration script to add notification fields to reminders table
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

async def migrate_reminders_notifications():
    """Add notification fields to reminders table if they don't exist"""
    
    print("Starting reminders notifications migration...")
    
    try:
        await database.connect()
        
        # Check if notification columns exist
        columns_to_add = [
            ("notification_enabled", "BOOLEAN DEFAULT FALSE"),
            ("notification_time", "TIME DEFAULT NULL")
        ]
        
        for column_name, column_definition in columns_to_add:
            # Check if column exists
            column_exists_query = """
            SELECT EXISTS (
                SELECT 1 
                FROM information_schema.columns 
                WHERE table_name = 'reminders' 
                AND column_name = :column_name
            );
            """
            
            column_exists = await database.fetch_val(column_exists_query, {"column_name": column_name})
            
            if not column_exists:
                print(f"📋 Adding {column_name} column to reminders table...")
                add_column_query = f"""
                ALTER TABLE reminders 
                ADD COLUMN {column_name} {column_definition};
                """
                await database.execute(add_column_query)
                print(f"✅ Added {column_name} column")
            else:
                print(f"ℹ️ Column {column_name} already exists, skipping")
        
        print("✅ Reminders notifications migration completed successfully")
        
    except Exception as e:
        print(f"❌ Error during migration: {e}")
        raise
    finally:
        await database.disconnect()

if __name__ == "__main__":
    asyncio.run(migrate_reminders_notifications()) 