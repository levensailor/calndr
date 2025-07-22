#!/usr/bin/env python3
"""
School Calendar Event Scraper
Navigates through all months of a school year calendar and extracts events.
Designed for Finalsite-based school calendars like NHCS schools.
"""

import asyncio
import httpx
import re
from datetime import datetime, date, timedelta
from typing import List, Dict, Optional, Tuple
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse, parse_qs
import json
import logging

# Configure logging
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class SchoolCalendarScraper:
    def __init__(self, base_calendar_url: str, timeout: float = 15.0):
        """
        Initialize the calendar scraper.
        
        Args:
            base_calendar_url: Base URL of the school calendar (e.g., https://gregory.nhcs.net/about-us/calendar)
            timeout: HTTP request timeout in seconds
        """
        self.base_url = base_calendar_url
        self.timeout = timeout
        self.events = []
        self.session = None
        
    async def __aenter__(self):
        """Async context manager entry."""
        self.session = httpx.AsyncClient(
            follow_redirects=True,
            timeout=self.timeout,
            headers={
                'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            }
        )
        return self
        
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit."""
        if self.session:
            await self.session.aclose()
    
    def get_school_year_months(self, start_year: int = None) -> List[Tuple[int, int]]:
        """
        Generate list of (year, month) tuples for a complete school year.
        School year typically runs August to June.
        
        Args:
            start_year: Starting year of school year (defaults to current year logic)
            
        Returns:
            List of (year, month) tuples
        """
        if start_year is None:
            current_date = datetime.now()
            # If we're past July, use current year as start year, otherwise previous year
            start_year = current_date.year if current_date.month >= 7 else current_date.year - 1
        
        months = []
        
        # August through December of start year
        for month in range(8, 13):
            months.append((start_year, month))
            
        # January through June of next year
        for month in range(1, 7):
            months.append((start_year + 1, month))
            
        return months
    
    def build_calendar_url(self, year: int, month: int, day: int = 1) -> str:
        """
        Build calendar URL with date parameter.
        
        Args:
            year: Year
            month: Month (1-12)
            day: Day (defaults to 1)
            
        Returns:
            Complete calendar URL with date parameter
        """
        date_str = f"{year:04d}-{month:02d}-{day:02d}"
        return f"{self.base_url}?cal_date={date_str}"
    
    async def fetch_calendar_page(self, year: int, month: int) -> Optional[BeautifulSoup]:
        """
        Fetch calendar page for specific month.
        
        Args:
            year: Year
            month: Month
            
        Returns:
            BeautifulSoup object or None if failed
        """
        url = self.build_calendar_url(year, month)
        logger.info(f"📅 Fetching calendar for {year}-{month:02d}: {url}")
        
        try:
            response = await self.session.get(url)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.text, 'html.parser')
            logger.info(f"✅ Successfully fetched calendar for {year}-{month:02d}")
            return soup
            
        except Exception as e:
            logger.error(f"❌ Failed to fetch calendar for {year}-{month:02d}: {e}")
            return None
    
    def extract_calendar_title(self, soup: BeautifulSoup) -> Optional[str]:
        """Extract the calendar title (e.g., '< July 2025 >')."""
        # Look for month/year navigation elements
        title_patterns = [
            r'<\s*(\w+\s+\d{4})\s*>',  # < July 2025 >
            r'(\w+\s+\d{4})',          # July 2025
        ]
        
        text = soup.get_text()
        for pattern in title_patterns:
            match = re.search(pattern, text)
            if match:
                return match.group(1).strip()
        
        return None
    
    def parse_finalsite_calendar(self, soup: BeautifulSoup, year: int, month: int) -> List[Dict]:
        """
        Parse Finalsite calendar structure to extract events.
        
        Args:
            soup: BeautifulSoup object of calendar page
            year: Year for context
            month: Month for context
            
        Returns:
            List of event dictionaries
        """
        events = []
        
        logger.info(f"🏫 Starting Finalsite calendar parsing for {year}-{month:02d}")
        
        # Find the main calendar container
        calendar_container = soup.find('div', class_=re.compile(r'fsCalendar'))
        
        if not calendar_container:
            logger.warning(f"⚠️ No Finalsite calendar container found for {year}-{month:02d}")
            # Try alternative selectors
            alternative_containers = soup.find_all('div', class_=lambda x: x and any(cls for cls in x if 'calendar' in cls.lower()))
            logger.info(f"🔍 Found {len(alternative_containers)} alternative calendar containers")
            for i, container in enumerate(alternative_containers):
                logger.debug(f"  Container {i+1}: classes={container.get('class', [])}")
            return events
        
        logger.info(f"✅ Found Finalsite calendar container with classes: {calendar_container.get('class', [])}")
        
        # Find all day boxes that have events
        day_boxes = calendar_container.find_all('div', class_=re.compile(r'fsCalendarDaybox'))
        
        logger.info(f"🔍 Found {len(day_boxes)} calendar day boxes")
        
        # Count how many have events
        event_boxes = [box for box in day_boxes if 'fsStateHasEvents' in box.get('class', [])]
        logger.info(f"📊 {len(event_boxes)} day boxes have events (fsStateHasEvents)")
        
        for i, day_box in enumerate(day_boxes):
            logger.debug(f"🔄 Processing day box {i+1}/{len(day_boxes)}")
            try:
                box_events = self.extract_finalsite_events_from_daybox(day_box, year, month)
                events.extend(box_events)
                if box_events:
                    logger.info(f"📈 Day box {i+1} contributed {len(box_events)} events")
            except Exception as e:
                logger.error(f"❌ Error processing day box {i+1}: {e}")
                continue
        
        logger.info(f"📊 Finalsite parsing complete: extracted {len(events)} total events for {year}-{month:02d}")
        return events
    
    def extract_finalsite_events_from_daybox(self, day_box, year: int, month: int) -> List[Dict]:
        """
        Extract events from a Finalsite calendar day box.
        
        Args:
            day_box: BeautifulSoup element representing a calendar day box
            year: Year for context
            month: Month for context
            
        Returns:
            List of event dictionaries
        """
        events = []
        
        # Check if this day box has events
        has_events = 'fsStateHasEvents' in (day_box.get('class', []))
        day_box_classes = day_box.get('class', [])
        
        logger.debug(f"🔍 Processing day box with classes: {day_box_classes}")
        logger.debug(f"📋 Has events flag: {has_events}")
        
        if not has_events:
            logger.debug(f"⏭️ Skipping day box - no events flag")
            return events
        
        # Find the date within this day box
        date_element = day_box.find('div', class_='fsCalendarDate')
        if not date_element:
            logger.debug(f"❌ No fsCalendarDate element found in day box")
            return events
        
        # Extract day number - handle different formats
        day_text = date_element.get_text(strip=True)
        logger.info(f"📅 Processing date element: '{day_text}'")
        
        # Try different patterns for day extraction
        day_match = (
            re.search(r'(\d{1,2})$', day_text) or  # Day at end: "Monday,September1"
            re.search(r'^(\d{1,2})', day_text) or  # Day at start: "1"
            re.search(r',(\d{1,2})', day_text)     # Day after comma: ",1"
        )
        
        if not day_match:
            logger.warning(f"❌ Could not extract day from: '{day_text}'")
            return events
        
        day = int(day_match.group(1))
        logger.info(f"📊 Extracted day: {day}")
        
        # Extract month information from the day text if available
        extracted_month = month  # Default to requested month
        original_year = year
        
        # Check if day text contains month name
        month_names = {
            'january': 1, 'february': 2, 'march': 3, 'april': 4, 'may': 5, 'june': 6,
            'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12
        }
        
        day_text_lower = day_text.lower()
        logger.debug(f"🔍 Checking for month names in: '{day_text_lower}'")
        
        for month_name, month_num in month_names.items():
            if month_name in day_text_lower:
                extracted_month = month_num
                logger.info(f"📆 Found month '{month_name}' = {month_num}")
                # Adjust year if needed (for calendar views showing multiple months)
                if extracted_month < month and month >= 8:  # School year transition
                    year = year + 1
                    logger.info(f"🗓️ Adjusted year to {year} for school year transition")
                elif extracted_month > month and month <= 6:  # School year transition  
                    year = year
                    logger.debug(f"🗓️ Keeping year {year}")
                break
        
        logger.info(f"📋 Final date components: year={year}, month={extracted_month}, day={day}")
        
        # Validate day is reasonable for the extracted month
        try:
            event_date = date(year, extracted_month, day)
            logger.info(f"✅ Valid event date: {event_date.isoformat()}")
        except ValueError as e:
            logger.error(f"❌ Invalid date: {year}-{extracted_month}-{day}: {e}")
            return events
        
        # Skip if this is an out-of-range day (previous/next month) and we want current month only
        if 'fsCalendarOutOfRange' in day_box.get('class', []):
            logger.debug(f"⏭️ Skipping out-of-range day")
            return events
        
        # Find event information in this day box
        event_info_elements = day_box.find_all('div', class_='fsCalendarInfo')
        logger.info(f"🔍 Found {len(event_info_elements)} fsCalendarInfo elements")
        
        for i, info_element in enumerate(event_info_elements):
            logger.debug(f"📋 Processing info element {i+1}")
            
            # Get raw HTML for debugging
            logger.debug(f"🔍 Info element HTML: {info_element}")
            
            # Look for event details within the info element
            event_links = info_element.find_all('a')
            logger.info(f"🔗 Found {len(event_links)} links in info element {i+1}")
            
            for j, link in enumerate(event_links):
                event_text = link.get_text(strip=True)
                link_href = link.get('href', 'no-href')
                
                logger.info(f"🔗 Link {j+1}: text='{event_text}', href='{link_href}'")
                
                if event_text:
                    # Clean up event text
                    original_text = event_text
                    event_text = self.normalize_event_text(event_text)
                    
                    logger.info(f"🧹 Normalized: '{original_text}' → '{event_text}'")
                    
                    if event_text:  # Only add if we have meaningful text after normalization
                        event = {
                            'date': event_date.isoformat(),
                            'title': event_text,
                            'year': event_date.year,
                            'month': event_date.month,
                            'day': event_date.day,
                            'source_url': self.build_calendar_url(event_date.year, event_date.month, event_date.day),
                            'event_link': link.get('href') if link.get('href') else None
                        }
                        events.append(event)
                        logger.info(f"✅ Added event: {event_date.isoformat()} - {event_text}")
                    else:
                        logger.debug(f"⏭️ Skipping normalized empty text")
                else:
                    logger.debug(f"⏭️ Skipping empty link text")
            
            # Also check for plain text events (not in links)
            info_text = info_element.get_text(strip=True)
            logger.debug(f"📄 Full info text: '{info_text}'")
            
            # Remove link text from the full text to see if there's additional text
            remaining_text = info_text
            for link in event_links:
                link_text = link.get_text(strip=True)
                remaining_text = remaining_text.replace(link_text, '').strip()
                logger.debug(f"🧹 After removing '{link_text}': '{remaining_text}'")
            
            if remaining_text and remaining_text not in [link.get_text(strip=True) for link in event_links]:
                logger.info(f"📄 Found additional text: '{remaining_text}'")
                event_text = self.normalize_event_text(remaining_text)
                
                if event_text:
                    event = {
                        'date': event_date.isoformat(),
                        'title': event_text,
                        'year': event_date.year,
                        'month': event_date.month,
                        'day': event_date.day,
                        'source_url': self.build_calendar_url(event_date.year, event_date.month, event_date.day),
                        'event_link': None
                    }
                    events.append(event)
                    logger.info(f"✅ Added text event: {event_date.isoformat()} - {event_text}")
                else:
                    logger.debug(f"⏭️ Skipping normalized empty additional text")
        
        logger.info(f"📊 Day box processing complete: {len(events)} events extracted")
        return events
    
    def parse_calendar_grid(self, soup: BeautifulSoup, year: int, month: int) -> List[Dict]:
        """
        Parse calendar grid to extract events.
        Main method that tries different calendar structures.
        
        Args:
            soup: BeautifulSoup object of calendar page
            year: Year for context
            month: Month for context
            
        Returns:
            List of event dictionaries
        """
        # First try Finalsite structure
        events = self.parse_finalsite_calendar(soup, year, month)
        
        if events:
            return events
        
        # Fallback to generic parsing for other calendar systems
        return self.parse_generic_calendar(soup, year, month)
    
    def parse_generic_calendar(self, soup: BeautifulSoup, year: int, month: int) -> List[Dict]:
        """
        Generic calendar parsing for non-Finalsite calendars.
        
        Args:
            soup: BeautifulSoup object of calendar page
            year: Year for context
            month: Month for context
            
        Returns:
            List of event dictionaries
        """
        events = []
        
        # Find calendar table or grid
        calendar_container = soup.find('table') or soup.find('div', class_=re.compile(r'calendar|grid'))
        
        if not calendar_container:
            logger.warning(f"⚠️ No calendar grid found for {year}-{month:02d}")
            return events
        
        # Find all date cells - look for various patterns
        date_cells = calendar_container.find_all(['td', 'div'], class_=re.compile(r'day|date|cell'))
        
        if not date_cells:
            # Fallback: look for any element containing day numbers
            day_elements = soup.find_all(string=re.compile(r'^\d{1,2}$'))
            date_cells = [elem.parent for elem in day_elements if elem.parent]
        
        logger.info(f"🔍 Found {len(date_cells)} potential date cells")
        
        for cell in date_cells:
            try:
                events.extend(self.extract_events_from_cell(cell, year, month))
            except Exception as e:
                logger.debug(f"Error processing cell: {e}")
                continue
        
        logger.info(f"📊 Extracted {len(events)} events for {year}-{month:02d}")
        return events
    
    def extract_events_from_cell(self, cell, year: int, month: int) -> List[Dict]:
        """
        Extract events from a single calendar cell (generic method).
        
        Args:
            cell: BeautifulSoup element representing a calendar cell
            year: Year for context
            month: Month for context
            
        Returns:
            List of event dictionaries
        """
        events = []
        
        # Try to find day number
        day_text = cell.get_text(strip=True)
        day_match = re.search(r'^(\d{1,2})', day_text)
        
        if not day_match:
            return events
        
        day = int(day_match.group(1))
        
        # Validate day is reasonable for the month
        try:
            event_date = date(year, month, day)
        except ValueError:
            return events
        
        # Look for event indicators in the cell
        event_elements = []
        
        # Method 1: Look for links with event text
        links = cell.find_all('a')
        for link in links:
            link_text = link.get_text(strip=True)
            if link_text and link_text.lower() not in ['more', 'view', 'details', str(day)]:
                event_elements.append(link)
        
        # Method 2: Look for spans or divs with event-like classes
        event_containers = cell.find_all(['span', 'div'], class_=re.compile(r'event|title|summary'))
        event_elements.extend(event_containers)
        
        # Method 3: Look for text that appears to be events (not just the day number)
        cell_text = cell.get_text()
        lines = [line.strip() for line in cell_text.split('\n') if line.strip()]
        
        for line in lines:
            # Skip day numbers and common non-event text
            if re.match(r'^\d{1,2}$', line) or line.lower() in ['more', 'view', 'details']:
                continue
            
            # If line contains meaningful text, it might be an event
            if len(line) > 3 and not re.match(r'^\d+$', line):
                # Create a pseudo-element for text-based events
                event_elements.append(type('TextEvent', (), {'get_text': lambda strip=False: line})())
        
        # Process found event elements
        for element in event_elements:
            event_text = element.get_text(strip=True) if hasattr(element, 'get_text') else str(element)
            
            if event_text and len(event_text) > 1:
                # Clean up event text
                event_text = self.normalize_event_text(event_text)
                
                if event_text:  # Only add if we have meaningful text after normalization
                    event = {
                        'date': event_date.isoformat(),
                        'title': event_text,
                        'year': event_date.year,
                        'month': event_date.month,
                        'day': event_date.day,
                        'source_url': self.build_calendar_url(event_date.year, event_date.month, event_date.day),
                        'event_link': None
                    }
                    events.append(event)
                    logger.debug(f"📌 Found event: {event_date.isoformat()} - {event_text}")
        
        return events
    
    def normalize_event_text(self, text: str) -> Optional[str]:
        """
        Normalize and clean event text.
        
        Args:
            text: Raw event text
            
        Returns:
            Cleaned event text or None if not meaningful
        """
        if not text:
            logger.debug(f"🧹 Normalization: empty input")
            return None
        
        original_text = text
        logger.debug(f"🧹 Normalizing: '{original_text}'")
        
        # Basic cleaning
        text = text.strip()
        text = re.sub(r'\s+', ' ', text)  # Normalize whitespace
        logger.debug(f"🧹 After basic cleaning: '{text}'")
        
        # Skip if it's just a number (day number)
        if re.match(r'^\d+$', text):
            logger.debug(f"🧹 Rejected: just a number")
            return None
        
        # Skip very short text that's likely not an event
        if len(text) < 3:
            logger.debug(f"🧹 Rejected: too short ({len(text)} chars)")
            return None
        
        # Skip common non-event text
        skip_patterns = [
            r'^(more|view|details|all day)$',
            r'^\d{1,2}$',  # Just day numbers
        ]
        
        for pattern in skip_patterns:
            if re.match(pattern, text, re.IGNORECASE):
                logger.debug(f"🧹 Rejected: matches skip pattern '{pattern}'")
                return None
        
        # Remove "All Day" suffix if present
        if text.lower().endswith('all day'):
            text = text[:-7].strip()
            logger.debug(f"🧹 Removed 'All Day' suffix: '{text}'")
        
        # Capitalize first letter
        if len(text) > 1:
            text = text[0].upper() + text[1:]
        else:
            text = text.upper()
        
        logger.debug(f"🧹 Final normalized text: '{text}'")
        return text
    
    async def scrape_school_year(self, start_year: int = None) -> List[Dict]:
        """
        Scrape events for an entire school year.
        
        Args:
            start_year: Starting year of school year
            
        Returns:
            List of all events found
        """
        months = self.get_school_year_months(start_year)
        all_events = []
        
        logger.info(f"🏫 Starting calendar scrape for school year {start_year or 'current'}")
        logger.info(f"📅 Will scrape {len(months)} months: {[f'{y}-{m:02d}' for y, m in months]}")
        
        for year, month in months:
            soup = await self.fetch_calendar_page(year, month)
            
            if soup:
                # Extract calendar title for verification
                title = self.extract_calendar_title(soup)
                if title:
                    logger.info(f"📋 Calendar title: {title}")
                
                # Parse events from this month
                month_events = self.parse_calendar_grid(soup, year, month)
                
                # If no events found, log page structure for debugging
                if not month_events:
                    logger.warning(f"❌ No events found for {year}-{month:02d}")
                    
                    # Log some page structure for debugging
                    all_divs = soup.find_all('div')
                    calendar_divs = [d for d in all_divs if d.get('class') and any('calendar' in str(c).lower() for c in d.get('class', []))]
                    event_divs = [d for d in all_divs if d.get('class') and any('event' in str(c).lower() for c in d.get('class', []))]
                    
                    logger.debug(f"🔍 Page structure debug:")
                    logger.debug(f"  Total divs: {len(all_divs)}")
                    logger.debug(f"  Calendar-related divs: {len(calendar_divs)}")
                    logger.debug(f"  Event-related divs: {len(event_divs)}")
                    
                    # Sample some calendar div classes
                    for i, div in enumerate(calendar_divs[:5]):
                        logger.debug(f"    Calendar div {i+1}: {div.get('class', [])}")
                    
                    # Check for any text that might be events
                    page_text = soup.get_text()
                    holiday_keywords = ['holiday', 'day off', 'break', 'vacation', 'closed', 'workday', 'teacher', 'report']
                    found_keywords = [kw for kw in holiday_keywords if kw.lower() in page_text.lower()]
                    if found_keywords:
                        logger.info(f"🔍 Found potential event keywords in page: {found_keywords}")
                    
                all_events.extend(month_events)
                
                # Small delay to be respectful
                await asyncio.sleep(0.5)
            else:
                logger.warning(f"⚠️ Skipping {year}-{month:02d} due to fetch failure")
        
        # Remove duplicates and sort by date
        logger.info(f"📊 Before deduplication: {len(all_events)} events")
        all_events = self.deduplicate_events(all_events)
        all_events.sort(key=lambda x: x['date'])
        
        logger.info(f"🎉 Scraping complete! Found {len(all_events)} total events")
        
        # Log summary of found events
        if all_events:
            logger.info(f"📅 Date range: {all_events[0]['date']} to {all_events[-1]['date']}")
            logger.info(f"📋 Sample events:")
            for event in all_events[:3]:
                logger.info(f"  • {event['date']}: {event['title']}")
            if len(all_events) > 3:
                logger.info(f"  ... and {len(all_events) - 3} more events")
        else:
            logger.warning(f"❌ No events found across entire school year!")
        
        return all_events
    
    def deduplicate_events(self, events: List[Dict]) -> List[Dict]:
        """
        Remove duplicate events based on date and title.
        
        Args:
            events: List of event dictionaries
            
        Returns:
            List of unique events
        """
        seen = set()
        unique_events = []
        
        for event in events:
            key = (event['date'], event['title'].lower())
            if key not in seen:
                seen.add(key)
                unique_events.append(event)
        
        logger.info(f"🔄 Deduplicated {len(events)} -> {len(unique_events)} events")
        return unique_events
    
    def save_events(self, events: List[Dict], filename: str = None) -> str:
        """
        Save events to JSON file.
        
        Args:
            events: List of events to save
            filename: Output filename (auto-generated if None)
            
        Returns:
            Filename used
        """
        if filename is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            school_name = urlparse(self.base_url).netloc.split('.')[0]
            filename = f"school_calendar_{school_name}_{timestamp}.json"
        
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump({
                'metadata': {
                    'scraped_at': datetime.now().isoformat(),
                    'source_url': self.base_url,
                    'total_events': len(events),
                    'date_range': {
                        'start': events[0]['date'] if events else None,
                        'end': events[-1]['date'] if events else None
                    }
                },
                'events': events
            }, f, indent=2, ensure_ascii=False)
        
        logger.info(f"💾 Saved {len(events)} events to {filename}")
        return filename


async def main():
    """Main function demonstrating usage."""
    
    # Example usage with Gregory school
    calendar_url = "https://gregory.nhcs.net/about-us/calendar"
    
    async with SchoolCalendarScraper(calendar_url) as scraper:
        # Scrape current school year
        events = await scraper.scrape_school_year()
        
        # Save to file
        filename = scraper.save_events(events)
        
        # Print summary
        print(f"\n🎓 School Calendar Scrape Summary")
        print(f"📅 Total Events: {len(events)}")
        print(f"💾 Saved to: {filename}")
        
        if events:
            print(f"📊 Date Range: {events[0]['date']} to {events[-1]['date']}")
            
            # Show sample events
            print(f"\n📝 Sample Events:")
            for event in events[:5]:
                print(f"  • {event['date']}: {event['title']}")
            
            if len(events) > 5:
                print(f"  ... and {len(events) - 5} more events")


if __name__ == "__main__":
    # Run the scraper
    asyncio.run(main()) 