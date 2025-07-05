#!/usr/bin/env python3

import os
import asyncio
import asyncpg
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Database connection parameters
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME")

async def migrate_enhanced_handoff_times():
    """Add location, from_parent_id, and to_parent_id columns to handoff_times table"""
    
    # Connect to the database
    conn = await asyncpg.connect(
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        host=DB_HOST,
        port=DB_PORT
    )
    
    try:
        print("🔄 Starting enhanced handoff_times table migration...")
        
        # Check if columns already exist
        location_exists = await conn.fetchval("""
            SELECT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'handoff_times' 
                AND column_name = 'location'
            )
        """)
        
        from_parent_exists = await conn.fetchval("""
            SELECT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'handoff_times' 
                AND column_name = 'from_parent_id'
            )
        """)
        
        to_parent_exists = await conn.fetchval("""
            SELECT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'handoff_times' 
                AND column_name = 'to_parent_id'
            )
        """)
        
        # Add location column if it doesn't exist
        if not location_exists:
            print("  📍 Adding location column...")
            await conn.execute("""
                ALTER TABLE handoff_times 
                ADD COLUMN location VARCHAR(100) DEFAULT 'daycare'
            """)
            print("  ✅ Location column added successfully")
        else:
            print("  ℹ️ Location column already exists")
        
        # Add from_parent_id column if it doesn't exist
        if not from_parent_exists:
            print("  👤 Adding from_parent_id column...")
            await conn.execute("""
                ALTER TABLE handoff_times 
                ADD COLUMN from_parent_id UUID REFERENCES users(id)
            """)
            print("  ✅ From_parent_id column added successfully")
        else:
            print("  ℹ️ From_parent_id column already exists")
        
        # Add to_parent_id column if it doesn't exist
        if not to_parent_exists:
            print("  👥 Adding to_parent_id column...")
            await conn.execute("""
                ALTER TABLE handoff_times 
                ADD COLUMN to_parent_id UUID REFERENCES users(id)
            """)
            print("  ✅ To_parent_id column added successfully")
        else:
            print("  ℹ️ To_parent_id column already exists")
        
        # Create index for better query performance
        print("  🔍 Creating indexes for new columns...")
        try:
            await conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_handoff_times_from_parent 
                ON handoff_times(from_parent_id)
            """)
            await conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_handoff_times_to_parent 
                ON handoff_times(to_parent_id)
            """)
            await conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_handoff_times_location 
                ON handoff_times(location)
            """)
            print("  ✅ Indexes created successfully")
        except Exception as e:
            print(f"  ⚠️ Index creation warning: {e}")
        
        # Show current table structure
        print("\n📋 Current handoff_times table structure:")
        columns = await conn.fetch("""
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns 
            WHERE table_name = 'handoff_times'
            ORDER BY ordinal_position
        """)
        
        for column in columns:
            nullable = "NULL" if column['is_nullable'] == 'YES' else "NOT NULL"
            default = f" DEFAULT {column['column_default']}" if column['column_default'] else ""
            print(f"  • {column['column_name']}: {column['data_type']} {nullable}{default}")
        
        print("\n✅ Enhanced handoff_times table migration completed successfully!")
        
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        raise
    
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(migrate_enhanced_handoff_times()) 