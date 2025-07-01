#!/usr/bin/env python3
"""
Migration script to create notification_emails table and populate with parent emails
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

async def migrate_notification_emails():
    """Create notification_emails table and populate with parent emails"""
    
    print("Starting notification emails migration...")
    
    try:
        await database.connect()
        
        # Create notification_emails table if it doesn't exist
        create_table_query = """
        CREATE TABLE IF NOT EXISTS notification_emails (
            id SERIAL PRIMARY KEY,
            family_id UUID NOT NULL REFERENCES families(id),
            email VARCHAR NOT NULL,
            created_at TIMESTAMP DEFAULT NOW()
        );
        """
        
        await database.execute(create_table_query)
        print("✅ Created notification_emails table")
        
        # Check if table structure is correct by trying to query it
        try:
            count_query = "SELECT COUNT(*) FROM notification_emails"
            email_count = await database.fetch_val(count_query)
            print(f"📊 Found {email_count} existing notification emails")
            
            if email_count == 0:
                # Get all families and their parent emails
                families_query = """
                SELECT DISTINCT f.id as family_id, u.email
                FROM families f
                JOIN users u ON u.family_id = f.id
                WHERE u.email IS NOT NULL
                ORDER BY f.id, u.email
                """
                
                family_emails = await database.fetch_all(families_query)
                print(f"📧 Found {len(family_emails)} parent emails to add")
                
                # Insert parent emails as notification emails
                for row in family_emails:
                    insert_query = """
                    INSERT INTO notification_emails (family_id, email, created_at)
                    VALUES (:family_id, :email, NOW())
                    """
                    await database.execute(insert_query, {
                        'family_id': row['family_id'],
                        'email': row['email']
                    })
                    print(f"✅ Added notification email: {row['email']} for family {row['family_id']}")
            else:
                print("⚠️  Notification emails already exist, skipping auto-population")
                
        except Exception as e:
            print(f"⚠️  Error querying notification_emails table: {e}")
            # If there's an issue with the table structure, drop and recreate it
            print("🔧 Recreating notification_emails table...")
            
            drop_query = "DROP TABLE IF EXISTS notification_emails"
            await database.execute(drop_query)
            
            # Recreate with correct structure
            await database.execute(create_table_query)
            print("✅ Recreated notification_emails table")
            
            # Now populate it
            families_query = """
            SELECT DISTINCT f.id as family_id, u.email
            FROM families f
            JOIN users u ON u.family_id = f.id
            WHERE u.email IS NOT NULL
            ORDER BY f.id, u.email
            """
            
            family_emails = await database.fetch_all(families_query)
            print(f"📧 Found {len(family_emails)} parent emails to add")
            
            # Insert parent emails as notification emails
            for row in family_emails:
                insert_query = """
                INSERT INTO notification_emails (family_id, email, created_at)
                VALUES (:family_id, :email, NOW())
                """
                await database.execute(insert_query, {
                    'family_id': row['family_id'],
                    'email': row['email']
                })
                print(f"✅ Added notification email: {row['email']} for family {row['family_id']}")
        
        print("✅ Notification emails migration completed successfully!")
        
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        raise
    finally:
        await database.disconnect()

if __name__ == "__main__":
    asyncio.run(migrate_notification_emails()) 