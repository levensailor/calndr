#!/usr/bin/env python3
"""
Migration script to add selected_theme column to user_preferences table
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

async def migrate_user_preferences():
    """Add selected_theme column to user_preferences table if it doesn't exist"""
    
    print("Starting user preferences selected_theme migration...")
    
    try:
        await database.connect()
        
        # Check if the user_preferences table exists
        table_exists_query = """
        SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'user_preferences'
        );
        """
        table_exists = await database.fetch_val(table_exists_query)
        
        if not table_exists:
            print("📋 Creating user_preferences table...")
            create_table_query = """
            CREATE TABLE user_preferences (
                id SERIAL PRIMARY KEY,
                user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                selected_theme VARCHAR(100) DEFAULT 'Default',
                created_at TIMESTAMP DEFAULT NOW(),
                updated_at TIMESTAMP DEFAULT NOW(),
                UNIQUE(user_id)
            );
            """
            await database.execute(create_table_query)
            print("✅ Created user_preferences table with selected_theme column")
        else:
            print("📋 user_preferences table exists, checking for selected_theme column...")
            
            # Check if selected_theme column exists
            column_exists_query = """
            SELECT EXISTS (
                SELECT FROM information_schema.columns 
                WHERE table_name = 'user_preferences' 
                AND column_name = 'selected_theme'
            );
            """
            column_exists = await database.fetch_val(column_exists_query)
            
            if not column_exists:
                print("➕ Adding selected_theme column to user_preferences table...")
                alter_query = """
                ALTER TABLE user_preferences 
                ADD COLUMN selected_theme VARCHAR(100) DEFAULT 'Default'
                """
                await database.execute(alter_query)
                print("✅ Added selected_theme column to user_preferences table")
            else:
                print("ℹ️  selected_theme column already exists in user_preferences table")
        
        # Create index for better performance
        print("🔍 Creating index for user_id...")
        try:
            await database.execute("""
                CREATE INDEX IF NOT EXISTS idx_user_preferences_user_id 
                ON user_preferences(user_id)
            """)
            print("✅ Index created successfully")
        except Exception as e:
            print(f"⚠️ Index creation warning: {e}")
        
        # Show current table structure
        print("\n📋 Current user_preferences table structure:")
        columns = await database.fetch_all("""
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns 
            WHERE table_name = 'user_preferences'
            ORDER BY ordinal_position
        """)
        
        for column in columns:
            nullable = "NULL" if column['is_nullable'] == 'YES' else "NOT NULL"
            default = f" DEFAULT {column['column_default']}" if column['column_default'] else ""
            print(f"  • {column['column_name']}: {column['data_type']} {nullable}{default}")
        
        print("\n✅ User preferences selected_theme migration completed successfully!")
        
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        raise
    finally:
        await database.disconnect()

if __name__ == "__main__":
    asyncio.run(migrate_user_preferences()) 