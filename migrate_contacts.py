#!/usr/bin/env python3

import asyncio
import asyncpg
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

async def migrate_contacts():
    """Add babysitters and emergency_contacts tables to the database."""
    
    # Database connection settings
    DB_USER = os.getenv("DB_USER")
    DB_PASSWORD = os.getenv("DB_PASSWORD")
    DB_HOST = os.getenv("DB_HOST")
    DB_PORT = os.getenv("DB_PORT", "5432")
    DB_NAME = os.getenv("DB_NAME")
    
    if not all([DB_USER, DB_PASSWORD, DB_HOST, DB_NAME]):
        print("❌ Missing required database environment variables")
        return False

    print("🔌 Starting contacts migration...")
    
    try:
        # Connect to database
        conn = await asyncpg.connect(
            user=DB_USER,
            password=DB_PASSWORD,
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME
        )
        print("✅ Connected to database")
        
        # Create babysitters table
        await conn.execute('''
            CREATE TABLE IF NOT EXISTS babysitters (
                id SERIAL PRIMARY KEY,
                first_name VARCHAR(100) NOT NULL,
                last_name VARCHAR(100) NOT NULL,
                phone_number VARCHAR(20) NOT NULL,
                rate DECIMAL(6,2),
                notes TEXT,
                created_by_user_id UUID NOT NULL REFERENCES users(id),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        print("✅ Created babysitters table")
        
        # Create babysitter_families junction table (many-to-many relationship)
        await conn.execute('''
            CREATE TABLE IF NOT EXISTS babysitter_families (
                id SERIAL PRIMARY KEY,
                babysitter_id INTEGER NOT NULL REFERENCES babysitters(id) ON DELETE CASCADE,
                family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
                added_by_user_id UUID NOT NULL REFERENCES users(id),
                added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(babysitter_id, family_id)
            )
        ''')
        print("✅ Created babysitter_families junction table")
        
        # Create emergency_contacts table
        await conn.execute('''
            CREATE TABLE IF NOT EXISTS emergency_contacts (
                id SERIAL PRIMARY KEY,
                family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
                first_name VARCHAR(100) NOT NULL,
                last_name VARCHAR(100) NOT NULL,
                phone_number VARCHAR(20) NOT NULL,
                relationship VARCHAR(100),
                notes TEXT,
                created_by_user_id UUID NOT NULL REFERENCES users(id),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        print("✅ Created emergency_contacts table")
        
        # Create group_chats table to track group messaging
        await conn.execute('''
            CREATE TABLE IF NOT EXISTS group_chats (
                id SERIAL PRIMARY KEY,
                family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
                contact_type VARCHAR(20) NOT NULL CHECK (contact_type IN ('babysitter', 'emergency')),
                contact_id INTEGER NOT NULL,
                group_identifier VARCHAR(255) UNIQUE,
                created_by_user_id UUID NOT NULL REFERENCES users(id),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        print("✅ Created group_chats table")
        
        await conn.close()
        print("🔌 Database connection closed")
        print("✅ Contacts migration completed successfully!")
        return True
        
    except Exception as e:
        print(f"❌ Error during migration: {e}")
        return False

if __name__ == "__main__":
    success = asyncio.run(migrate_contacts())
    if not success:
        exit(1) 