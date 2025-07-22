#!/usr/bin/env python3
"""
Clear Daycare Events Script
Removes any daycare events from the backend database.
"""

import asyncio
import asyncpg
import os
from datetime import datetime

# Database configuration
DATABASE_URL = "postgresql+asyncpg://postgres:Money4cookies@cal-db-instance.cjy8vmu6rtrc.us-east-1.rds.amazonaws.com:5432/postgres"
POSTGRES_URL = "postgresql://postgres:Money4cookies@cal-db-instance.cjy8vmu6rtrc.us-east-1.rds.amazonaws.com:5432/postgres"

async def clear_daycare_events():
    """Clear potential daycare events from the database."""
    
    print("🧹 Starting daycare events cleanup...")
    
    try:
        # Connect to the database
        conn = await asyncpg.connect(POSTGRES_URL)
        print("✅ Connected to database")
        
        # Find potential daycare events
        print("\n🔍 Searching for potential daycare events...")
        
        # Search for events that might be daycare-related
        daycare_patterns = [
            '%daycare%', '%childcare%', '%preschool%', '%nursery%',
            '%little%learn%', '%tiny%tot%', '%kids%club%', '%academy%',
            '%child%care%', '%early%learn%', '%kindercare%'
        ]
        
        all_events = []
        for pattern in daycare_patterns:
            query = """
            SELECT id, family_id, date, content, position, event_type 
            FROM events 
            WHERE content ILIKE $1
            ORDER BY date DESC
            """
            events = await conn.fetch(query, pattern)
            all_events.extend(events)
        
        # Remove duplicates
        seen_ids = set()
        unique_events = []
        for event in all_events:
            if event['id'] not in seen_ids:
                unique_events.append(event)
                seen_ids.add(event['id'])
        
        if not unique_events:
            print("✅ No daycare events found in database")
            await conn.close()
            return
        
        print(f"\n📋 Found {len(unique_events)} potential daycare events:")
        for event in unique_events:
            print(f"  ID: {event['id']} | Date: {event['date']} | Content: {event['content'][:50]}...")
        
        # Ask for confirmation
        response = input(f"\n❓ Do you want to delete these {len(unique_events)} events? (y/N): ")
        
        if response.lower() in ['y', 'yes']:
            # Delete the events
            deleted_count = 0
            for event in unique_events:
                await conn.execute("DELETE FROM events WHERE id = $1", event['id'])
                deleted_count += 1
                print(f"   ✅ Deleted event {event['id']}: {event['content'][:30]}...")
            
            print(f"\n🎉 Successfully deleted {deleted_count} daycare events!")
        else:
            print("❌ Deletion cancelled.")
        
        await conn.close()
        
    except Exception as e:
        print(f"❌ Error: {e}")

async def check_database_stats():
    """Check database statistics for events."""
    
    try:
        conn = await asyncpg.connect(POSTGRES_URL)
        
        # Total events
        total_events = await conn.fetchval("SELECT COUNT(*) FROM events")
        print(f"📊 Total events in database: {total_events}")
        
        # Events by type
        event_types = await conn.fetch("SELECT event_type, COUNT(*) as count FROM events GROUP BY event_type")
        print("📊 Events by type:")
        for row in event_types:
            print(f"   {row['event_type']}: {row['count']}")
        
        # Recent events
        recent_events = await conn.fetch("""
            SELECT id, date, content, event_type 
            FROM events 
            ORDER BY date DESC 
            LIMIT 10
        """)
        
        print("\n📊 Most recent 10 events:")
        for event in recent_events:
            print(f"   {event['date']} | {event['event_type']} | {event['content'][:40]}...")
        
        await conn.close()
        
    except Exception as e:
        print(f"❌ Error checking database: {e}")

if __name__ == "__main__":
    print("🔧 Daycare Events Cleanup Tool")
    print("=" * 50)
    
    # First show database stats
    print("\n📊 Database Statistics:")
    asyncio.run(check_database_stats())
    
    print("\n" + "=" * 50)
    
    # Then offer to clear daycare events
    asyncio.run(clear_daycare_events())
    
    print("\n✅ Cleanup complete! The iOS app should no longer show daycare events after refreshing.") 