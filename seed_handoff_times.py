#!/usr/bin/env python3

import os
import psycopg2
from dotenv import load_dotenv
from datetime import datetime, date, timedelta
from collections import defaultdict

# Load environment variables
load_dotenv()

# Database connection details
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")

def get_handoff_time_for_day(date_obj):
    """Return handoff time based on day of week: 5pm weekdays, 12pm weekends"""
    # Monday = 0, Sunday = 6
    if date_obj.weekday() >= 5:  # Saturday (5) or Sunday (6)
        return "12:00"  # 12 PM for weekends
    else:
        return "17:00"  # 5 PM for weekdays

def seed_handoff_times():
    """Seed handoff times based on existing custody records."""
    
    conn = None
    try:
        # Connect to PostgreSQL
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        
        cur = conn.cursor()
        
        print("🚀 Starting handoff times seeding...")
        
        # Get all custody records, ordered by family and date
        cur.execute("""
            SELECT family_id, date, custodian_id 
            FROM custody 
            ORDER BY family_id, date ASC
        """)
        
        custody_records = cur.fetchall()
        print(f"📊 Found {len(custody_records)} custody records")
        
        if not custody_records:
            print("⚠️  No custody records found. Cannot seed handoff times.")
            return
        
        # Group custody records by family
        family_custody = defaultdict(list)
        for family_id, custody_date, custodian_id in custody_records:
            family_custody[family_id].append((custody_date, custodian_id))
        
        handoff_times_to_create = []
        
        # Process each family's custody records
        for family_id, family_records in family_custody.items():
            print(f"\n🏠 Processing family: {family_id}")
            print(f"   Found {len(family_records)} custody records")
            
            previous_custodian = None
            handoff_count = 0
            
            for custody_date, custodian_id in family_records:
                # If custodian changed, this is a handoff day
                if previous_custodian is not None and previous_custodian != custodian_id:
                    handoff_time = get_handoff_time_for_day(custody_date)
                    handoff_times_to_create.append((family_id, custody_date, handoff_time))
                    handoff_count += 1
                    
                    day_name = custody_date.strftime("%A")
                    print(f"   📅 Handoff on {custody_date} ({day_name}) at {handoff_time}")
                
                previous_custodian = custodian_id
            
            print(f"   ✅ Found {handoff_count} handoff days for this family")
        
        if not handoff_times_to_create:
            print("\n⚠️  No handoff days found (no custody changes detected)")
            return
        
        print(f"\n📝 Creating {len(handoff_times_to_create)} handoff time records...")
        
        # Check what handoff times already exist to avoid duplicates
        cur.execute("SELECT family_id, date FROM handoff_times")
        existing_handoffs = set(cur.fetchall())
        print(f"📊 Found {len(existing_handoffs)} existing handoff time records")
        
        new_handoffs = []
        for family_id, handoff_date, handoff_time in handoff_times_to_create:
            if (family_id, handoff_date) not in existing_handoffs:
                new_handoffs.append((family_id, handoff_date, handoff_time))
        
        print(f"🆕 {len(new_handoffs)} new handoff times to create")
        
        if new_handoffs:
            # Insert new handoff times
            insert_query = """
                INSERT INTO handoff_times (family_id, date, time, created_at, updated_at)
                VALUES (%s, %s, %s, %s, %s)
            """
            
            now = datetime.now()
            for family_id, handoff_date, handoff_time in new_handoffs:
                cur.execute(insert_query, (family_id, handoff_date, handoff_time, now, now))
            
            conn.commit()
            print(f"✅ Successfully created {len(new_handoffs)} handoff time records!")
        else:
            print("ℹ️  All handoff times already exist, no new records created")
        
        # Show summary
        cur.execute("SELECT COUNT(*) FROM handoff_times")
        total_handoffs = cur.fetchone()[0]
        
        cur.execute("SELECT COUNT(DISTINCT family_id) FROM handoff_times")
        families_with_handoffs = cur.fetchone()[0]
        
        print(f"\n📊 Final Summary:")
        print(f"   Total handoff times in database: {total_handoffs}")
        print(f"   Families with handoff times: {families_with_handoffs}")
        
        # Show sample of created handoff times
        cur.execute("""
            SELECT ht.family_id, ht.date, ht.time, 
                   EXTRACT(DOW FROM ht.date) as day_of_week
            FROM handoff_times ht 
            ORDER BY ht.date DESC 
            LIMIT 10
        """)
        
        sample_handoffs = cur.fetchall()
        print(f"\n📅 Recent handoff times (sample):")
        day_names = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
        
        for family_id, handoff_date, handoff_time, dow in sample_handoffs:
            day_name = day_names[int(dow)]
            time_str = handoff_time.strftime("%I:%M %p")
            print(f"   {handoff_date} ({day_name}) at {time_str} - Family: {str(family_id)[:8]}...")
        
        cur.close()
        
    except psycopg2.Error as e:
        print(f"❌ Database error: {e}")
        if conn:
            conn.rollback()
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    print("🌱 Seeding handoff times based on custody records...")
    seed_handoff_times()
    print("✅ Handoff times seeding completed!") 