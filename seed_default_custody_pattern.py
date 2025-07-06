#!/usr/bin/env python3

"""
Seed Default Custody Pattern Script

This script populates the custody table with default custody assignments based on 
day-of-week patterns. This is intended for onboarding new users to establish a 
baseline custody schedule.

Default Pattern:
- Sunday, Monday, Saturday: Parent 1 (custodian_one)  
- Tuesday, Wednesday, Thursday, Friday: Parent 2 (custodian_two)

Usage:
    python seed_default_custody_pattern.py --family-id <uuid> --start-date 2024-01-01 --end-date 2024-12-31
    python seed_default_custody_pattern.py --family-id <uuid> --year 2024
"""

import os
import sys
import argparse
import psycopg2
from datetime import datetime, timedelta
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

def get_family_custodians(conn, family_id):
    """Get the custodian IDs for a family."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT id, first_name 
            FROM users 
            WHERE family_id = %s 
            ORDER BY created_at ASC
            LIMIT 2
        """, (family_id,))
        
        custodians = cur.fetchall()
        
        if len(custodians) < 2:
            raise ValueError(f"Family {family_id} must have at least 2 users (parents)")
        
        return {
            'custodian_one': {'id': custodians[0][0], 'name': custodians[0][1]},
            'custodian_two': {'id': custodians[1][0], 'name': custodians[1][1]}
        }

def get_custody_owner_for_date(date, custodians):
    """
    Determine custody owner based on day of week.
    
    Default pattern:
    - Sunday (0), Monday (1), Saturday (6): custodian_one
    - Tuesday (2), Wednesday (3), Thursday (4), Friday (5): custodian_two
    """
    day_of_week = date.weekday()  # Monday = 0, Sunday = 6
    
    # Convert to match iOS weekday format (Sunday = 1, Monday = 2, etc.)
    ios_weekday = (day_of_week + 2) % 7
    if ios_weekday == 0:
        ios_weekday = 7
    
    # Default logic: Parent1 (custodian one) has Sun (1), Mon (2), Sat (7)
    if ios_weekday in [1, 2, 7]:  # Sunday, Monday, Saturday
        return custodians['custodian_one']
    else:  # Tuesday, Wednesday, Thursday, Friday
        return custodians['custodian_two']

def seed_custody_pattern(family_id, start_date, end_date, dry_run=False, force=False):
    """Seed the database with default custody pattern for the specified date range."""
    
    conn = get_connection()
    
    try:
        # Get family custodians
        custodians = get_family_custodians(conn, family_id)
        
        print(f"👥 Family custodians:")
        print(f"   Custodian 1: {custodians['custodian_one']['name']} ({custodians['custodian_one']['id']})")
        print(f"   Custodian 2: {custodians['custodian_two']['name']} ({custodians['custodian_two']['id']})")
        print()
        
        # Generate custody records for date range
        current_date = start_date
        custody_records = []
        
        while current_date <= end_date:
            owner = get_custody_owner_for_date(current_date, custodians)
            
            custody_records.append({
                'date': current_date.strftime('%Y-%m-%d'),
                'custodian_id': owner['id'],
                'custodian_name': owner['name']
            })
            
            current_date += timedelta(days=1)
        
        print(f"📅 Generated {len(custody_records)} custody records from {start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')}")
        
        # Show sample of the pattern
        print("\n📋 Sample custody pattern:")
        for i, record in enumerate(custody_records[:14]):  # Show first 2 weeks
            date_obj = datetime.strptime(record['date'], '%Y-%m-%d')
            day_name = date_obj.strftime('%A')
            print(f"   {record['date']} ({day_name}): {record['custodian_name']}")
        
        if len(custody_records) > 14:
            print(f"   ... and {len(custody_records) - 14} more records")
        
        if dry_run:
            print("\n🔍 DRY RUN - No changes made to database")
            return
        
        # Insert custody records
        print(f"\n💾 Inserting custody records into database...")
        
        with conn.cursor() as cur:
            # Check for existing records first
            date_list = [record['date'] for record in custody_records]
            cur.execute("""
                SELECT date 
                FROM custody 
                WHERE family_id = %s AND date = ANY(%s)
            """, (family_id, date_list))
            
            existing_dates = {row[0] for row in cur.fetchall()}
            
            if existing_dates and not force:
                print(f"⚠️  Found {len(existing_dates)} existing custody records")
                print("   Use --force to overwrite existing records")
                return
            
            # Delete existing records if force is enabled
            if existing_dates and force:
                print(f"🗑️  Deleting {len(existing_dates)} existing custody records...")
                cur.execute("""
                    DELETE FROM custody 
                    WHERE family_id = %s AND date = ANY(%s)
                """, (family_id, date_list))
            
            # Insert new records into the custody table
            insert_count = 0
            for record in custody_records:
                try:
                    # Use the first custodian as the actor (the one setting up the pattern)
                    actor_id = custodians['custodian_one']['id']
                    
                    cur.execute("""
                        INSERT INTO custody (family_id, date, actor_id, custodian_id, created_at)
                        VALUES (%s, %s, %s, %s, CURRENT_TIMESTAMP)
                    """, (
                        family_id,
                        record['date'],
                        actor_id,
                        record['custodian_id']
                    ))
                    insert_count += 1
                except Exception as e:
                    print(f"❌ Error inserting record for {record['date']}: {e}")
            
            conn.commit()
            print(f"✅ Successfully inserted {insert_count} custody records")
        
    except Exception as e:
        conn.rollback()
        print(f"❌ Error: {e}")
        raise
    finally:
        conn.close()

def main():
    parser = argparse.ArgumentParser(description='Seed database with default custody pattern')
    parser.add_argument('--family-id', required=True, help='Family UUID')
    parser.add_argument('--start-date', help='Start date (YYYY-MM-DD)')
    parser.add_argument('--end-date', help='End date (YYYY-MM-DD)')
    parser.add_argument('--year', type=int, help='Year to seed (alternative to start/end dates)')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be done without making changes')
    parser.add_argument('--force', action='store_true', help='Overwrite existing custody records')
    
    args = parser.parse_args()
    
    # Validate environment variables
    if not all([DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD]):
        sys.exit("❌ Missing required database environment variables")
    
    # Determine date range
    if args.year:
        start_date = datetime(args.year, 1, 1)
        end_date = datetime(args.year, 12, 31)
    elif args.start_date and args.end_date:
        try:
            start_date = datetime.strptime(args.start_date, '%Y-%m-%d')
            end_date = datetime.strptime(args.end_date, '%Y-%m-%d')
        except ValueError as e:
            sys.exit(f"❌ Invalid date format: {e}")
    else:
        sys.exit("❌ Must specify either --year or both --start-date and --end-date")
    
    if start_date > end_date:
        sys.exit("❌ Start date must be before end date")
    
    print("🚀 Seeding default custody pattern...")
    print(f"   Family ID: {args.family_id}")
    print(f"   Date range: {start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')}")
    print(f"   Total days: {(end_date - start_date).days + 1}")
    print()
    
    try:
        seed_custody_pattern(args.family_id, start_date, end_date, args.dry_run, args.force)
    except Exception as e:
        sys.exit(f"❌ Failed to seed custody pattern: {e}")

if __name__ == "__main__":
    main() 