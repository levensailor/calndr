#!/usr/bin/env python3

import os
import sys
import psycopg2
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def migrate_profile_photo():
    """Add profile_photo_url column to users table"""
    
    # Database connection parameters
    DB_USER = os.getenv("DB_USER")
    DB_PASSWORD = os.getenv("DB_PASSWORD")
    DB_HOST = os.getenv("DB_HOST")
    DB_PORT = os.getenv("DB_PORT", "5432")
    DB_NAME = os.getenv("DB_NAME")
    
    if not all([DB_USER, DB_PASSWORD, DB_HOST, DB_NAME]):
        print("❌ Missing required database environment variables")
        return False
    
    try:
        # Connect to database
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            port=DB_PORT
        )
        
        cur = conn.cursor()
        
        # Check if column already exists
        cur.execute("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name='users' AND column_name='profile_photo_url';
        """)
        
        if cur.fetchone():
            print("✅ profile_photo_url column already exists in users table")
            cur.close()
            conn.close()
            return True
        
        # Add the column
        print("🔄 Adding profile_photo_url column to users table...")
        cur.execute("""
            ALTER TABLE users 
            ADD COLUMN profile_photo_url TEXT;
        """)
        
        conn.commit()
        print("✅ Successfully added profile_photo_url column to users table")
        
        cur.close()
        conn.close()
        return True
        
    except Exception as e:
        print(f"❌ Error during migration: {e}")
        return False

if __name__ == "__main__":
    print("🚀 Starting user profile photo migration...")
    success = migrate_profile_photo()
    
    if success:
        print("✅ Migration completed successfully!")
        sys.exit(0)
    else:
        print("❌ Migration failed!")
        sys.exit(1) 