#!/usr/bin/env python3
"""
Simple database migration script to create the enrollment_codes table.
Uses psycopg2 for direct PostgreSQL connection.
"""

import os
import psycopg2
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

def create_enrollment_codes_table():
    """Create enrollment_codes table for family linking"""
    
    try:
        # Connect to PostgreSQL
        connection = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        
        cursor = connection.cursor()
        print("🔗 Connected to database")
        
        # Create enrollment_codes table
        create_table_sql = """
        CREATE TABLE IF NOT EXISTS enrollment_codes (
            id SERIAL PRIMARY KEY,
            code VARCHAR(6) UNIQUE NOT NULL,
            family_id UUID REFERENCES families(id) ON DELETE CASCADE,
            created_by_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
            is_used BOOLEAN DEFAULT FALSE,
            used_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
            expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '7 days'),
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
        """
        
        cursor.execute(create_table_sql)
        print("✅ Created enrollment_codes table")
        
        # Create indexes for better performance
        indexes = [
            "CREATE INDEX IF NOT EXISTS idx_enrollment_codes_code ON enrollment_codes(code);",
            "CREATE INDEX IF NOT EXISTS idx_enrollment_codes_family_id ON enrollment_codes(family_id);",
            "CREATE INDEX IF NOT EXISTS idx_enrollment_codes_created_by ON enrollment_codes(created_by_user_id);",
            "CREATE INDEX IF NOT EXISTS idx_enrollment_codes_expires_at ON enrollment_codes(expires_at);",
            "CREATE INDEX IF NOT EXISTS idx_enrollment_codes_is_used ON enrollment_codes(is_used);"
        ]
        
        for index_sql in indexes:
            cursor.execute(index_sql)
        
        print("✅ Created indexes for enrollment_codes table")
        
        # Create trigger to update updated_at timestamp
        trigger_sql = """
        CREATE OR REPLACE FUNCTION update_enrollment_codes_updated_at()
        RETURNS TRIGGER AS $$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $$ language 'plpgsql';
        
        DROP TRIGGER IF EXISTS update_enrollment_codes_updated_at ON enrollment_codes;
        CREATE TRIGGER update_enrollment_codes_updated_at
            BEFORE UPDATE ON enrollment_codes
            FOR EACH ROW
            EXECUTE FUNCTION update_enrollment_codes_updated_at();
        """
        
        cursor.execute(trigger_sql)
        print("✅ Created trigger for enrollment_codes table")
        
        # Commit the changes
        connection.commit()
        print("✅ Successfully created enrollment_codes table with indexes and triggers")
        return True
        
    except Exception as e:
        print(f"❌ Error creating enrollment_codes table: {e}")
        if connection:
            connection.rollback()
        return False
    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()

def main():
    print("🚀 Starting enrollment codes table migration...")
    
    # Check if we have database credentials
    if not all([DB_HOST, DB_USER, DB_PASSWORD, DB_NAME]):
        print("❌ Missing database credentials in environment variables")
        print("Required: DB_HOST, DB_USER, DB_PASSWORD, DB_NAME")
        return 1
    
    success = create_enrollment_codes_table()
    
    if success:
        print("✅ Enrollment codes migration completed successfully!")
        return 0
    else:
        print("❌ Enrollment codes migration failed!")
        return 1

if __name__ == "__main__":
    exit_code = main()
    exit(exit_code)
