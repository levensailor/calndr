#!/usr/bin/env python3

"""
Fix Custody Handoff Flags Script

This script analyzes existing custody records and updates them to properly set:
1. handoff_day = true when the custodian is different from the previous day
2. handoff_time = "17:00" for weekdays (Mon-Fri), "12:00" for weekends
3. handoff_location = "daycare" for weekdays, "other" for weekends

This corrects any custody records that were seeded without proper handoff information.

Usage:
    python fix_custody_handoff_flags.py --dry-run    # Preview changes
    python fix_custody_handoff_flags.py              # Apply changes
    python fix_custody_handoff_flags.py --family-id <uuid>  # Fix specific family
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

def get_families_with_custody(conn):
    """Get all families that have custody records."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT DISTINCT c.family_id, f.name as family_name
            FROM custody c
            JOIN families f ON c.family_id = f.id
            ORDER BY f.name
        """)
        return cur.fetchall()

def get_family_custodians(conn, family_id):
    """Get the custodian information for a family."""
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
            print(f"⚠️  Family {family_id} has only {len(custodians)} users - skipping")
            return None
        
        return {
            'custodian_one': {'id': custodians[0][0], 'name': custodians[0][1]},
            'custodian_two': {'id': custodians[1][0], 'name': custodians[1][1]}
        }

def get_custody_records_for_family(conn, family_id):
    """Get all custody records for a family, ordered by date."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT id, date, custodian_id, handoff_day, handoff_time, handoff_location
            FROM custody 
            WHERE family_id = %s 
            ORDER BY date ASC
        """, (family_id,))
        
        return cur.fetchall()

def determine_handoff_time_and_location(date, custodians, to_custodian_id):
    """Determine appropriate handoff time and location based on the date."""
    # Monday = 0, Sunday = 6
    day_of_week = date.weekday()
    
    # Weekend = Saturday (5) or Sunday (6)
    is_weekend = day_of_week >= 5
    
    if is_weekend:
        # Weekend: noon at "other" (generic location)
        handoff_time = "12:00"
        handoff_location = "other"
    else:
        # Weekday: 5pm at daycare
        handoff_time = "17:00"
        handoff_location = "daycare"
    
    return handoff_time, handoff_location

def analyze_and_fix_family_custody(conn, family_id, dry_run=False):
    """Analyze and fix custody records for a specific family."""
    
    # Get family custodians
    custodians = get_family_custodians(conn, family_id)
    if not custodians:
        return 0, 0  # Skip family
    
    # Get all custody records for this family
    custody_records = get_custody_records_for_family(conn, family_id)
    
    if not custody_records:
        print(f"   No custody records found for family {family_id}")
        return 0, 0
    
    print(f"   Analyzing {len(custody_records)} custody records...")
    
    updates_needed = []
    previous_custodian_id = None
    
    for record in custody_records:
        record_id, date, custodian_id, handoff_day, handoff_time, handoff_location = record
        
        # Check if this is a handoff day (custodian different from previous day)
        is_handoff_day = (previous_custodian_id is not None and 
                         previous_custodian_id != custodian_id)
        
        needs_update = False
        new_handoff_day = handoff_day
        new_handoff_time = handoff_time
        new_handoff_location = handoff_location
        
        if is_handoff_day:
            # This should be a handoff day
            if not handoff_day:
                needs_update = True
                new_handoff_day = True
            
            # Determine proper handoff time and location if not set
            if not handoff_time or not handoff_location:
                needs_update = True
                time_str, location_str = determine_handoff_time_and_location(
                    date, custodians, custodian_id
                )
                
                if not handoff_time:
                    new_handoff_time = time_str
                if not handoff_location:
                    new_handoff_location = location_str
        
        elif handoff_day:
            # This is marked as handoff day but shouldn't be (no custody change)
            # Only clear it if there's no explicit handoff time/location set by user
            if not handoff_time and not handoff_location:
                needs_update = True
                new_handoff_day = False
        
        if needs_update:
            updates_needed.append({
                'id': record_id,
                'date': date,
                'current_handoff_day': handoff_day,
                'current_handoff_time': handoff_time,
                'current_handoff_location': handoff_location,
                'new_handoff_day': new_handoff_day,
                'new_handoff_time': new_handoff_time,
                'new_handoff_location': new_handoff_location,
                'reason': 'custody_change' if is_handoff_day else 'false_positive'
            })
        
        previous_custodian_id = custodian_id
    
    print(f"   Found {len(updates_needed)} records that need updates")
    
    if updates_needed and not dry_run:
        apply_custody_updates(conn, updates_needed)
    
    return len(custody_records), len(updates_needed)

def apply_custody_updates(conn, updates):
    """Apply the custody updates to the database."""
    with conn.cursor() as cur:
        for update in updates:
            try:
                # Convert time string to time object if needed
                time_param = None
                if update['new_handoff_time']:
                    if isinstance(update['new_handoff_time'], str):
                        time_param = datetime.strptime(update['new_handoff_time'], '%H:%M').time()
                    else:
                        time_param = update['new_handoff_time']
                
                cur.execute("""
                    UPDATE custody 
                    SET handoff_day = %s, 
                        handoff_time = %s, 
                        handoff_location = %s
                    WHERE id = %s
                """, (
                    update['new_handoff_day'],
                    time_param,
                    update['new_handoff_location'],
                    update['id']
                ))
                
                print(f"      ✅ Updated record {update['id']} for {update['date']}")
                
            except Exception as e:
                print(f"      ❌ Error updating record {update['id']}: {e}")
        
        conn.commit()

def print_update_summary(updates):
    """Print a summary of the updates that would be applied."""
    if not updates:
        return
    
    print("   📋 Changes to be applied:")
    for update in updates:
        date_str = update['date'].strftime('%Y-%m-%d')
        reason = update['reason']
        
        if reason == 'custody_change':
            print(f"      {date_str}: Set handoff_day=True, time={update['new_handoff_time']}, location={update['new_handoff_location']}")
        else:
            print(f"      {date_str}: Set handoff_day=False (no custody change)")

def main():
    parser = argparse.ArgumentParser(description='Fix custody handoff flags in database')
    parser.add_argument('--family-id', help='Fix specific family UUID (optional)')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be done without making changes')
    
    args = parser.parse_args()
    
    # Validate environment variables
    if not all([DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD]):
        sys.exit("❌ Missing required database environment variables")
    
    print("🚀 Fixing custody handoff flags...")
    if args.dry_run:
        print("🔍 DRY RUN MODE - No changes will be made")
    print()
    
    conn = get_connection()
    
    try:
        total_records = 0
        total_updates = 0
        
        if args.family_id:
            # Fix specific family
            print(f"📋 Processing family: {args.family_id}")
            records, updates = analyze_and_fix_family_custody(conn, args.family_id, args.dry_run)
            total_records += records
            total_updates += updates
        else:
            # Fix all families
            families = get_families_with_custody(conn)
            print(f"📋 Found {len(families)} families with custody records")
            print()
            
            for family_id, family_name in families:
                print(f"👥 Processing family: {family_name} ({family_id})")
                records, updates = analyze_and_fix_family_custody(conn, family_id, args.dry_run)
                total_records += records
                total_updates += updates
                print()
        
        print("=" * 60)
        print(f"📊 Summary:")
        print(f"   Total custody records processed: {total_records}")
        print(f"   Records needing updates: {total_updates}")
        
        if args.dry_run and total_updates > 0:
            print(f"   Run without --dry-run to apply these {total_updates} updates")
        elif total_updates > 0:
            print(f"   ✅ Successfully applied {total_updates} updates")
        else:
            print("   ✅ All custody records are already properly configured")
        
    except Exception as e:
        conn.rollback()
        print(f"❌ Error: {e}")
        raise
    finally:
        conn.close()

if __name__ == "__main__":
    main() 