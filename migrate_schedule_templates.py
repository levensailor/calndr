#!/usr/bin/env python3

"""
Migration script to create the schedule_templates table.
"""

import asyncio
import asyncpg
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "calndr")

DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

async def migrate_schedule_templates():
    """Create schedule_templates table."""
    
    print("🗄️ Connecting to database...")
    connection = await asyncpg.connect(DATABASE_URL)
    
    try:
        # Check if table already exists
        table_exists = await connection.fetchval("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name = 'schedule_templates'
            );
        """)
        
        if table_exists:
            print("✅ schedule_templates table already exists")
            return
        
        print("📋 Creating schedule_templates table...")
        
        # Create the schedule_templates table
        await connection.execute("""
            CREATE TABLE schedule_templates (
                id SERIAL PRIMARY KEY,
                family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
                name VARCHAR(255) NOT NULL,
                description TEXT,
                pattern_type VARCHAR(50) NOT NULL,
                weekly_pattern JSONB,
                alternating_weeks_pattern JSONB,
                is_active BOOLEAN NOT NULL DEFAULT true,
                created_by_user_id UUID NOT NULL REFERENCES users(id),
                created_at TIMESTAMP DEFAULT NOW(),
                updated_at TIMESTAMP DEFAULT NOW()
            );
        """)
        
        print("✅ schedule_templates table created successfully")
        
        # Create indexes for better performance
        await connection.execute("""
            CREATE INDEX idx_schedule_templates_family_id ON schedule_templates(family_id);
        """)
        
        await connection.execute("""
            CREATE INDEX idx_schedule_templates_created_by ON schedule_templates(created_by_user_id);
        """)
        
        await connection.execute("""
            CREATE INDEX idx_schedule_templates_pattern_type ON schedule_templates(pattern_type);
        """)
        
        print("✅ Created indexes for schedule_templates table")
        
    except Exception as e:
        print(f"❌ Error creating schedule_templates table: {e}")
        raise
    finally:
        await connection.close()
        print("🔐 Database connection closed")

if __name__ == "__main__":
    asyncio.run(migrate_schedule_templates()) 