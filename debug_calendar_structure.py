#!/usr/bin/env python3
"""
Debug script to examine the HTML structure of school calendar pages.
"""

import asyncio
import httpx
from bs4 import BeautifulSoup
import re

async def debug_calendar_structure():
    """Debug the HTML structure of Gregory school calendar."""
    
    url = "https://gregory.nhcs.net/about-us/calendar?cal_date=2025-07-01"
    
    async with httpx.AsyncClient(follow_redirects=True, timeout=15.0) as client:
        print(f"🔍 Fetching: {url}")
        response = await client.get(url)
        response.raise_for_status()
        
        soup = BeautifulSoup(response.text, 'html.parser')
        
        print(f"✅ Page fetched successfully")
        
        # Look for calendar-related elements
        print(f"\n📋 Looking for calendar structures...")
        
        # Check for tables
        tables = soup.find_all('table')
        print(f"📊 Found {len(tables)} tables")
        for i, table in enumerate(tables):
            print(f"  Table {i+1}: classes={table.get('class', 'none')}")
            if table.find('td'):
                print(f"    Has {len(table.find_all('td'))} td elements")
        
        # Check for divs with calendar-like classes
        calendar_divs = soup.find_all('div', class_=re.compile(r'calendar|grid|month|week|day', re.I))
        print(f"📅 Found {len(calendar_divs)} calendar-like divs")
        for i, div in enumerate(calendar_divs):
            print(f"  Div {i+1}: classes={div.get('class', 'none')}")
        
        # Look for any elements containing "July 4th Holiday"
        holiday_elements = soup.find_all(text=re.compile(r'July 4th Holiday', re.I))
        print(f"🎆 Found {len(holiday_elements)} elements with 'July 4th Holiday'")
        for element in holiday_elements:
            parent = element.parent
            print(f"  Text: '{element.strip()}'")
            print(f"  Parent: {parent.name if parent else 'None'}")
            print(f"  Parent classes: {parent.get('class', 'none') if parent else 'none'}")
            
            # Look at grandparent structure
            if parent and parent.parent:
                grandparent = parent.parent
                print(f"  Grandparent: {grandparent.name}")
                print(f"  Grandparent classes: {grandparent.get('class', 'none')}")
        
        # Look for any elements containing day numbers
        day_elements = soup.find_all(text=re.compile(r'^\d{1,2}$'))
        print(f"📅 Found {len(day_elements)} potential day number elements")
        
        # Sample a few day elements
        for i, element in enumerate(day_elements[:5]):
            parent = element.parent
            print(f"  Day {element}: parent={parent.name if parent else 'None'}, classes={parent.get('class', 'none') if parent else 'none'}")
        
        # Look for Sunday/Monday headers
        weekday_elements = soup.find_all(text=re.compile(r'(Sunday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday)', re.I))
        print(f"📆 Found {len(weekday_elements)} weekday elements")
        
        # Check for any hidden or script-based calendar data
        scripts = soup.find_all('script')
        print(f"📜 Found {len(scripts)} script tags")
        for script in scripts:
            if script.string and ('calendar' in script.string.lower() or 'event' in script.string.lower()):
                print(f"  Script contains calendar/event data")
                print(f"  Script preview: {script.string[:200]}...")
        
        # Save a sample of the HTML for manual inspection
        with open('debug_calendar_sample.html', 'w', encoding='utf-8') as f:
            f.write(soup.prettify())
        print(f"\n💾 Saved HTML sample to debug_calendar_sample.html")
        
        # Look specifically for calendar month view
        print(f"\n🔍 Specific calendar structure analysis...")
        
        # Method 1: Look for calendar by day structure
        calendar_tables = soup.find_all('table')
        for table in calendar_tables:
            cells = table.find_all(['td', 'th'])
            if len(cells) >= 35:  # Typical calendar has ~35-42 cells
                print(f"📅 Potential calendar table found with {len(cells)} cells")
                # Sample first few cells
                for i, cell in enumerate(cells[:10]):
                    cell_text = cell.get_text(strip=True)
                    print(f"    Cell {i}: '{cell_text}' classes={cell.get('class', 'none')}")
        
        # Method 2: Look for specific calendar structure patterns
        calendar_containers = soup.find_all(['div', 'section'], class_=re.compile(r'calendar|view', re.I))
        for container in calendar_containers:
            print(f"📋 Calendar container: {container.name}, classes={container.get('class', 'none')}")
            # Look for nested structure
            nested_divs = container.find_all('div')
            print(f"  Contains {len(nested_divs)} nested divs")

if __name__ == "__main__":
    asyncio.run(debug_calendar_structure()) 