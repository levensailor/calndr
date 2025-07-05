#!/usr/bin/env python3

import os
import asyncio
import asyncpg
from datetime import datetime, date, time
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Database connection parameters
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME")

async def seed_enhanced_handoff_times():
    """Seed enhanced handoff records based on existing custody schedule"""
    
    # Connect to the database
    conn = await asyncpg.connect(
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        host=DB_HOST,
        port=DB_PORT
    )
    
    try:
        print("🔄 Starting enhanced handoff times seeding...")
        
        # Get all families
        families = await conn.fetch("SELECT id FROM families")
        print(f"📋 Found {len(families)} families to process")
        
        total_handoffs_created = 0
        
        for family in families:
            family_id = family['id']
            print(f"\n👨‍👩‍👧‍👦 Processing family: {family_id}")
            
            # Get family members (parents)
            parents = await conn.fetch("""
                SELECT id, first_name, last_name 
                FROM users 
                WHERE family_id = $1 
                ORDER BY created_at
            """, family_id)
            
            if len(parents) < 2:
                print(f"  ⚠️ Skipping family {family_id} - not enough parents ({len(parents)})")
                continue
            
            parent1 = parents[0]
            parent2 = parents[1]
            print(f"  👤 Parent 1: {parent1['first_name']} {parent1['last_name']} (ID: {parent1['id']})")
            print(f"  👤 Parent 2: {parent2['first_name']} {parent2['last_name']} (ID: {parent2['id']})")
            
            # Generate location names based on parent names
            parent1_home = f"{parent1['first_name'].lower()}'s home"
            parent2_home = f"{parent2['first_name'].lower()}'s home"
            
            # Get custody records for this family, ordered by date
            custody_records = await conn.fetch("""
                SELECT date, custodian_id 
                FROM custody 
                WHERE family_id = $1 
                ORDER BY date
            """, family_id)
            
            if len(custody_records) < 2:
                print(f"  ⚠️ Skipping family {family_id} - not enough custody records ({len(custody_records)})")
                continue
            
            print(f"  📅 Found {len(custody_records)} custody records")
            
            # Identify handoff days (where custody changes)
            handoff_days = []
            previous_custodian = None
            
            for record in custody_records:
                current_custodian = record['custodian_id']
                current_date = record['date']
                
                if previous_custodian and previous_custodian != current_custodian:
                    # This is a handoff day
                    handoff_days.append({
                        'date': current_date,
                        'from_parent_id': previous_custodian,
                        'to_parent_id': current_custodian
                    })
                
                previous_custodian = current_custodian
            
            print(f"  🔄 Identified {len(handoff_days)} handoff days")
            
            # Process each handoff day
            for handoff in handoff_days:
                handoff_date = handoff['date']
                from_parent_id = handoff['from_parent_id']
                to_parent_id = handoff['to_parent_id']
                
                # Determine location based on day of week
                weekday = handoff_date.weekday()  # Monday = 0, Sunday = 6
                
                if weekday < 5:  # Monday-Friday (weekdays)
                    location = "daycare"
                    handoff_time = time(17, 0)  # 5:00 PM
                else:  # Saturday-Sunday (weekends)
                    # Location is the destination parent's home
                    if to_parent_id == parent1['id']:
                        location = parent1_home
                    else:
                        location = parent2_home
                    handoff_time = time(12, 0)  # 12:00 PM
                
                # Check if handoff already exists for this date
                existing_handoff = await conn.fetchval("""
                    SELECT id FROM handoff_times 
                    WHERE family_id = $1 AND date = $2
                """, family_id, handoff_date)
                
                if existing_handoff:
                    # Update existing handoff with new fields
                    await conn.execute("""
                        UPDATE handoff_times 
                        SET location = $1, 
                            from_parent_id = $2, 
                            to_parent_id = $3,
                            time = $4,
                            updated_at = NOW()
                        WHERE id = $5
                    """, location, from_parent_id, to_parent_id, handoff_time, existing_handoff)
                    print(f"    ✏️ Updated handoff for {handoff_date} - {location}")
                else:
                    # Create new handoff record
                    await conn.execute("""
                        INSERT INTO handoff_times 
                        (family_id, date, time, location, from_parent_id, to_parent_id, created_at, updated_at)
                        VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
                    """, family_id, handoff_date, handoff_time, location, from_parent_id, to_parent_id)
                    print(f"    ➕ Created handoff for {handoff_date} - {location}")
                    total_handoffs_created += 1
        
        # Summary of seeded data
        print(f"\n📊 Seeding Summary:")
        print(f"  ✅ Total handoffs processed: {total_handoffs_created}")
        
        # Show sample of created handoffs
        sample_handoffs = await conn.fetch("""
            SELECT h.date, h.time, h.location, 
                   p1.first_name as from_parent, 
                   p2.first_name as to_parent
            FROM handoff_times h
            LEFT JOIN users p1 ON h.from_parent_id = p1.id
            LEFT JOIN users p2 ON h.to_parent_id = p2.id
            ORDER BY h.date
            LIMIT 10
        """)
        
        print(f"\n📋 Sample handoff records:")
        for handoff in sample_handoffs:
            print(f"  • {handoff['date']} at {handoff['time']} - {handoff['location']}")
            print(f"    From: {handoff['from_parent']} → To: {handoff['to_parent']}")
        
        # Location distribution
        location_stats = await conn.fetch("""
            SELECT location, COUNT(*) as count
            FROM handoff_times
            GROUP BY location
            ORDER BY count DESC
        """)
        
        print(f"\n📍 Location distribution:")
        for stat in location_stats:
            print(f"  • {stat['location']}: {stat['count']} handoffs")
        
        print("\n✅ Enhanced handoff times seeding completed successfully!")
        
    except Exception as e:
        print(f"❌ Seeding failed: {e}")
        import traceback
        traceback.print_exc()
        raise
    
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(seed_enhanced_handoff_times()) 