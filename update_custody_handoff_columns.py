#!/usr/bin/env python3
"""
Database script to update the custody table with handoff information.

This script:
1. Adds handoff_day, handoff_time, and handoff_location columns to the custody table
2. Sets handoff_day to true when the custodian_id is different from the previous day
3. Sets handoff_time to 5pm (17:00) on handoff days that fall on weekends
4. Sets handoff_location to the custodian's house on handoff days that fall on weekends
5. Sets all other handoff_day records to false

Usage:
    python update_custody_handoff_columns.py [--dry-run]
"""

import os
import sys
import argparse
import psycopg2
from datetime import datetime, time
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Database connection details
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")

def get_connection():
    """Establish and return a database connection."""
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
    )

def add_handoff_columns(conn):
    """Add handoff columns to the custody table if they don't exist."""
    print("🔧 Checking and adding handoff columns to custody table...")
    
    with conn.cursor() as cur:
        try:
            # Check if columns already exist
            cur.execute("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'custody' 
                AND column_name IN ('handoff_day', 'handoff_time', 'handoff_location')
            """)
            existing_columns = {row[0] for row in cur.fetchall()}
            
            # Add missing columns
            columns_to_add = []
            
            if 'handoff_day' not in existing_columns:
                columns_to_add.append("ADD COLUMN handoff_day BOOLEAN DEFAULT FALSE")
                
            if 'handoff_time' not in existing_columns:
                columns_to_add.append("ADD COLUMN handoff_time TIME")
                
            if 'handoff_location' not in existing_columns:
                columns_to_add.append("ADD COLUMN handoff_location VARCHAR(255)")
            
            if columns_to_add:
                alter_statement = f"ALTER TABLE custody {', '.join(columns_to_add)}"
                cur.execute(alter_statement)
                conn.commit()
                print(f"✅ Added {len(columns_to_add)} handoff columns to custody table")
            else:
                print("✅ All handoff columns already exist")
                
        except Exception as e:
            conn.rollback()
            print(f"❌ Error adding handoff columns: {e}")
            raise

def get_family_users(conn, family_id):
    """Get family users to map custodian IDs to names."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT id, first_name 
            FROM users 
            WHERE family_id = %s 
            ORDER BY created_at ASC
        """, (family_id,))
        
        users = cur.fetchall()
        return {str(user[0]): user[1] for user in users}

def is_weekend(date_obj):
    """Check if a date falls on a weekend (Saturday or Sunday)."""
    return date_obj.weekday() in [5, 6]  # Saturday = 5, Sunday = 6

def update_handoff_data(conn, dry_run=False):
    """Update handoff data in the custody table."""
    print("🔄 Processing custody records to identify handoff days...")
    
    with conn.cursor() as cur:
        # Get all custody records ordered by family and date
        cur.execute("""
            SELECT id, family_id, date, custodian_id 
            FROM custody 
            ORDER BY family_id, date ASC
        """)
        
        custody_records = cur.fetchall()
        print(f"📊 Found {len(custody_records)} custody records")
        
        if not custody_records:
            print("⚠️  No custody records found")
            return
        
        # Group records by family
        family_records = {}
        for record in custody_records:
            record_id, family_id, date_obj, custodian_id = record
            
            if family_id not in family_records:
                family_records[family_id] = []
            
            family_records[family_id].append({
                'id': record_id,
                'date': date_obj,
                'custodian_id': str(custodian_id)
            })
        
        # Get family user mappings
        family_users = {}
        for family_id in family_records.keys():
            family_users[family_id] = get_family_users(conn, family_id)
        
        total_handoff_days = 0
        total_updates = 0
        
        # Process each family
        for family_id, records in family_records.items():
            print(f"\n👨‍👩‍👧‍👦 Processing family: {family_id}")
            print(f"   Found {len(records)} custody records")
            
            users = family_users[family_id]
            
            # Identify handoff days and prepare updates
            updates = []
            previous_custodian = None
            handoff_count = 0
            
            for record in records:
                is_handoff_day = False
                handoff_time_val = None
                handoff_location_val = None
                
                # Check if this is a handoff day (custodian different from previous day)
                if previous_custodian is not None and previous_custodian != record['custodian_id']:
                    is_handoff_day = True
                    handoff_count += 1
                    
                    # If it's a weekend handoff, set time and location
                    if is_weekend(record['date']):
                        handoff_time_val = time(17, 0)  # 5:00 PM
                        
                        # Get the custodian's name for location
                        custodian_name = users.get(record['custodian_id'], 'unknown')
                        handoff_location_val = f"{custodian_name.lower()}'s home"
                
                updates.append({
                    'id': record['id'],
                    'date': record['date'],
                    'handoff_day': is_handoff_day,
                    'handoff_time': handoff_time_val,
                    'handoff_location': handoff_location_val,
                    'custodian_name': users.get(record['custodian_id'], 'unknown')
                })
                
                previous_custodian = record['custodian_id']
            
            print(f"   🔄 Found {handoff_count} handoff days")
            total_handoff_days += handoff_count
            
            # Show sample of what will be updated
            handoff_examples = [u for u in updates if u['handoff_day']][:3]
            if handoff_examples:
                print("   📅 Sample handoff days:")
                for example in handoff_examples:
                    date_str = example['date'].strftime('%Y-%m-%d (%A)')
                    time_str = example['handoff_time'].strftime('%H:%M') if example['handoff_time'] else 'None'
                    location = example['handoff_location'] or 'None'
                    custodian = example['custodian_name']
                    weekend_indicator = " (Weekend)" if is_weekend(example['date']) else ""
                    print(f"      {date_str}{weekend_indicator}: {custodian}, Time: {time_str}, Location: {location}")
            
            if not dry_run:
                # Execute the updates
                for update in updates:
                    cur.execute("""
                        UPDATE custody 
                        SET handoff_day = %s, handoff_time = %s, handoff_location = %s
                        WHERE id = %s
                    """, (
                        update['handoff_day'],
                        update['handoff_time'],
                        update['handoff_location'],
                        update['id']
                    ))
                    total_updates += 1
        
        if not dry_run:
            conn.commit()
            print(f"\n✅ Successfully updated {total_updates} custody records")
        else:
            print(f"\n🔍 DRY RUN - Would update {len(custody_records)} custody records")
        
        print(f"📊 Total handoff days identified: {total_handoff_days}")

def verify_updates(conn):
    """Verify the handoff updates."""
    print("\n🔍 Verifying handoff updates...")
    
    with conn.cursor() as cur:
        # Count handoff days
        cur.execute("SELECT COUNT(*) FROM custody WHERE handoff_day = TRUE")
        handoff_count = cur.fetchone()[0]
        
        # Count weekend handoffs with time/location
        cur.execute("""
            SELECT COUNT(*) FROM custody 
            WHERE handoff_day = TRUE 
            AND handoff_time IS NOT NULL 
            AND handoff_location IS NOT NULL
        """)
        weekend_handoff_count = cur.fetchone()[0]
        
        # Get sample of handoff records
        cur.execute("""
            SELECT c.date, c.handoff_day, c.handoff_time, c.handoff_location, u.first_name
            FROM custody c
            JOIN users u ON c.custodian_id = u.id
            WHERE c.handoff_day = TRUE
            ORDER BY c.date
            LIMIT 5
        """)
        samples = cur.fetchall()
        
        print(f"📊 Total handoff days: {handoff_count}")
        print(f"📊 Weekend handoffs with time/location: {weekend_handoff_count}")
        
        if samples:
            print("\n📅 Sample handoff records:")
            for sample in samples:
                date_obj, handoff_day, handoff_time, handoff_location, custodian_name = sample
                date_str = date_obj.strftime('%Y-%m-%d (%A)')
                time_str = handoff_time.strftime('%H:%M') if handoff_time else 'None'
                location = handoff_location or 'None'
                print(f"   {date_str}: {custodian_name}, Time: {time_str}, Location: {location}")

def main():
    parser = argparse.ArgumentParser(description='Update custody table with handoff information')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be done without making changes')
    
    args = parser.parse_args()
    
    # Validate environment variables
    if not all([DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD]):
        sys.exit("❌ Missing required database environment variables")
    
    print("🚀 Starting custody table handoff update...")
    if args.dry_run:
        print("🔍 DRY RUN MODE - No changes will be made")
    print()
    
    try:
        conn = get_connection()
        
        # Add handoff columns if they don't exist
        if not args.dry_run:
            add_handoff_columns(conn)
        else:
            print("🔍 DRY RUN - Skipping column addition")
        
        # Update handoff data
        update_handoff_data(conn, args.dry_run)
        
        # Verify updates if not dry run
        if not args.dry_run:
            verify_updates(conn)
        
        print("\n✅ Custody table handoff update completed successfully!")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)
    finally:
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    main() 