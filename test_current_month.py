#!/usr/bin/env python3
"""
Test script to scrape just the current month (July 2025) to debug event extraction.
"""

import asyncio
from scrape_school_calendar import SchoolCalendarScraper

async def test_current_month():
    """Test scraping just July 2025 where we know there's a July 4th Holiday event."""
    
    calendar_url = "https://gregory.nhcs.net/about-us/calendar"
    
    async with SchoolCalendarScraper(calendar_url) as scraper:
        # Test July 2025 specifically
        soup = await scraper.fetch_calendar_page(2025, 7)
        
        if soup:
            print("✅ Successfully fetched July 2025 calendar")
            
            # Parse with Finalsite method
            events = scraper.parse_finalsite_calendar(soup, 2025, 7)
            
            print(f"📊 Found {len(events)} events in July 2025")
            
            for event in events:
                print(f"  • {event['date']}: {event['title']}")
            
            # Let's also debug the day boxes with events
            print(f"\n🔍 Debugging day boxes with events...")
            
            calendar_container = soup.find('div', class_=lambda x: x and 'fsCalendar' in x)
            if calendar_container:
                day_boxes = calendar_container.find_all('div', class_=lambda x: x and 'fsCalendarDaybox' in x)
                
                for i, day_box in enumerate(day_boxes):
                    has_events = 'fsStateHasEvents' in (day_box.get('class', []))
                    
                    if has_events:
                        print(f"\n📅 Day box {i+1} has events:")
                        
                        # Find date
                        date_element = day_box.find('div', class_='fsCalendarDate')
                        if date_element:
                            day_text = date_element.get_text(strip=True)
                            print(f"  Day: {day_text}")
                        
                        # Find event info
                        event_info_elements = day_box.find_all('div', class_='fsCalendarInfo')
                        print(f"  Event info elements: {len(event_info_elements)}")
                        
                        for j, info_element in enumerate(event_info_elements):
                            info_text = info_element.get_text(strip=True)
                            print(f"    Info {j+1}: '{info_text}'")
                            
                            # Check for links
                            links = info_element.find_all('a')
                            print(f"    Links: {len(links)}")
                            for link in links:
                                link_text = link.get_text(strip=True)
                                print(f"      Link: '{link_text}'")
        else:
            print("❌ Failed to fetch July 2025 calendar")

if __name__ == "__main__":
    asyncio.run(test_current_month()) 