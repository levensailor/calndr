#!/usr/bin/env python3
"""
Migration script to add status and last_signed_in columns to users table
"""

import os
import asyncio
import databases
import sqlalchemy
from dotenv import load_dotenv
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

async def migrate_users_table():
    """Add status and last_signed_in columns to users table if they don't exist"""
    
    print("Starting user status and signin migration...")
    
    try:
        await database.connect()
        
        # Check if columns already exist and add them if they don't
        columns_to_add = [
            ("status", "VARCHAR DEFAULT 'active'"),
            ("last_signed_in", "TIMESTAMP DEFAULT NOW()")
        ]
        
        for column_name, column_definition in columns_to_add:
            try:
                # Try to add the column
                query = f"ALTER TABLE users ADD COLUMN {column_name} {column_definition};"
                await database.execute(query)
                print(f"✅ Added column: {column_name}")
            except Exception as e:
                if "already exists" in str(e).lower():
                    print(f"⚠️  Column {column_name} already exists, skipping...")
                else:
                    print(f"❌ Error adding column {column_name}: {e}")
                    raise
        
        # Update any NULL values to have default values
        await database.execute("""
            UPDATE users 
            SET status = 'active' 
            WHERE status IS NULL
        """)
        
        await database.execute("""
            UPDATE users 
            SET last_signed_in = created_at 
            WHERE last_signed_in IS NULL AND created_at IS NOT NULL
        """)
        
        # For users without created_at, set last_signed_in to now
        await database.execute("""
            UPDATE users 
            SET last_signed_in = NOW() 
            WHERE last_signed_in IS NULL
        """)
        
        print("✅ Migration completed successfully!")
        print("📋 Status field added with possible values: 'active', 'inactive', 'pending'")
        print("📅 Last signed in field added, initialized to created_at or current time")
        
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        raise
    finally:
        await database.disconnect()

if __name__ == "__main__":
    asyncio.run(migrate_users_table()) 