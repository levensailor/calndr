#!/usr/bin/env python3
"""
Migration script to add subscription and created_at columns to users table
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
    """Add subscription columns to users table if they don't exist"""
    
    print("Starting user profile migration...")
    
    try:
        await database.connect()
        
        # Check if columns already exist and add them if they don't
        columns_to_add = [
            ("subscription_type", "VARCHAR DEFAULT 'Free'"),
            ("subscription_status", "VARCHAR DEFAULT 'Active'"),
            ("created_at", "TIMESTAMP DEFAULT NOW()")
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
            SET subscription_type = 'Free' 
            WHERE subscription_type IS NULL
        """)
        
        await database.execute("""
            UPDATE users 
            SET subscription_status = 'Active' 
            WHERE subscription_status IS NULL
        """)
        
        await database.execute("""
            UPDATE users 
            SET created_at = NOW() 
            WHERE created_at IS NULL
        """)
        
        print("✅ Migration completed successfully!")
        
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        raise
    finally:
        await database.disconnect()

if __name__ == "__main__":
    asyncio.run(migrate_users_table()) 