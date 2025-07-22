#!/usr/bin/env python3
"""
Test script with enhanced logging to debug event extraction.
"""

import asyncio
import logging
from scrape_school_calendar import SchoolCalendarScraper

# Set logging level to show key information
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

async def test_with_logging():
    """Test scraping with focused logging output."""
    
    calendar_url = "https://gregory.nhcs.net/about-us/calendar"
    
    print("🎓 Testing School Calendar Scraper with Enhanced Logging")
    print("=" * 60)
    
    async with SchoolCalendarScraper(calendar_url) as scraper:
        # Test just a few months to see the pattern
        test_months = [(2025, 7), (2025, 9), (2025, 12)]
        
        all_events = []
        
        for year, month in test_months:
            print(f"\n📅 Testing {year}-{month:02d}")
            print("-" * 30)
            
            soup = await scraper.fetch_calendar_page(year, month)
            
            if soup:
                events = scraper.parse_finalsite_calendar(soup, year, month)
                all_events.extend(events)
                
                if events:
                    print(f"✅ Found {len(events)} events:")
                    for event in events:
                        print(f"  • {event['date']}: {event['title']}")
                else:
                    print(f"❌ No events found")
            else:
                print(f"❌ Failed to fetch calendar")
        
        print(f"\n🎉 Test Complete!")
        print(f"📊 Total events found: {len(all_events)}")
        
        if all_events:
            # Show all unique events
            unique_events = {}
            for event in all_events:
                key = (event['date'], event['title'])
                if key not in unique_events:
                    unique_events[key] = event
            
            print(f"📋 Unique events:")
            for event in sorted(unique_events.values(), key=lambda x: x['date']):
                print(f"  • {event['date']}: {event['title']}")

if __name__ == "__main__":
    asyncio.run(test_with_logging()) 