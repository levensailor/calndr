import re
import httpx
from datetime import datetime, timezone, timedelta
from typing import List, Dict, Optional, Any
from bs4 import BeautifulSoup

from core.logging import logger

# School Events Caching
SCHOOL_EVENTS_CACHE: Optional[List[Dict[str, Any]]] = None
SCHOOL_EVENTS_CACHE_TIME: Optional[datetime] = None
SCHOOL_EVENTS_CACHE_TTL_HOURS = 24

async def fetch_school_events() -> List[Dict[str, str]]:
    """Scrape school closing events and return list of {date, title}. Uses 24-hour in-memory cache."""
    global SCHOOL_EVENTS_CACHE, SCHOOL_EVENTS_CACHE_TIME
    
    # Return cached copy if fresh
    if SCHOOL_EVENTS_CACHE and SCHOOL_EVENTS_CACHE_TIME:
        if datetime.now(timezone.utc) - SCHOOL_EVENTS_CACHE_TIME < timedelta(hours=SCHOOL_EVENTS_CACHE_TTL_HOURS):
            logger.info("Returning cached school events.")
            return SCHOOL_EVENTS_CACHE

    logger.info("Fetching fresh school events from the website...")
    url = "https://www.thelearningtreewilmington.com/calendar-of-events/"
    scraped_events = {}

    try:
        async with httpx.AsyncClient(follow_redirects=True, timeout=10.0) as client:
            response = await client.get(url)
            response.raise_for_status()

        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Find the header for the 2025 closings to anchor the search
        header = soup.find('p', string=re.compile(r'THE LEARNING TREE CLOSINGS IN 2025'))
        if header:
            for sibling in header.find_next_siblings():
                if sibling.name != 'p':
                    break
                
                text = sibling.get_text(separator=' ', strip=True)
                if not text:
                    continue

                parts = text.split('-')
                
                if len(parts) > 1:
                    event_name = parts[0].strip()
                    date_str = "-".join(parts[1:]).strip()
                else:
                    event_name = text
                    date_str = ""

                date_match = re.search(r'(\w+\s+\d+)', text)
                if date_match:
                    date_str = date_match.group(1)

                year_match = re.search(r'(\d{4})', header.text)
                year = year_match.group(1) if year_match else "2025"
                
                if "new year" in event_name.lower() and "2026" in text.lower():
                    year = "2026"

                event_name = event_name.replace(date_str, "").strip()
                event_name = re.sub(r'\s*-\s*$', '', event_name)

                try:
                    date_str_no_weekday = re.sub(r'^\w+,\s*', '', date_str)
                    full_date_str = f"{date_str_no_weekday}, {year}"
                    full_date_str = full_date_str.replace("Jan ", "January ")

                    event_date = datetime.strptime(full_date_str, '%B %d, %Y')
                    iso_date = event_date.strftime('%Y-%m-%d')
                    if event_name:
                        scraped_events[iso_date] = event_name
                except ValueError:
                    logger.warning(f"Could not parse date from: '{date_str}' in text: '{text}'")
        else:
            logger.warning("Could not find the school closings header for 2025.")

    except Exception as e:
        logger.error(f"Failed to scrape or parse school events: {e}", exc_info=True)
        # Return old cache if fetching fails to avoid returning nothing on a temporary error
        if SCHOOL_EVENTS_CACHE:
            return SCHOOL_EVENTS_CACHE
        return []

    logger.info(f"Successfully scraped {len(scraped_events)} school events.")
    SCHOOL_EVENTS_CACHE = [{"date": d, "title": name} for d, name in scraped_events.items()]
    SCHOOL_EVENTS_CACHE_TIME = datetime.now(timezone.utc)
    return SCHOOL_EVENTS_CACHE
