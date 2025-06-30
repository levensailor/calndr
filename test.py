import httpx
import re
from bs4 import BeautifulSoup
from datetime import datetime
import logging
import pprint
import lxml

# Set up logging to see the script's progress
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def scrape_school_events():
    """
    Scrapes school closing events from The Learning Tree website and returns them.
    """
    logger.info("Fetching school events from the website...")
    events = {}
    try:
        url = "https://www.thelearningtreewilmington.com/calendar-of-events/"
        # Use a synchronous httpx call for this simple script
        response = httpx.get(url, follow_redirects=True, timeout=10)
        response.raise_for_status()

        soup = BeautifulSoup(response.text, 'lxml')
        
        # Find the header for the 2025 closings to anchor the search
        # Corrected from 'h3' to 'p' based on actual page structure
        header = soup.find('p', string=re.compile(r'THE LEARNING TREE CLOSINGS IN 2025'))
        if header:
            # The events are in subsequent <p> tags, not a <ul>
            for sibling in header.find_next_siblings():
                # Stop if we hit something that's not a <p> tag
                if sibling.name != 'p':
                    break
                
                text = sibling.get_text(separator=' ', strip=True)
                # Skip empty paragraphs
                if not text:
                    continue

                # The date and event are separated by a hyphen or are the last part of the string
                parts = text.split('-')
                
                if len(parts) > 1:
                    event_name = parts[0].strip()
                    date_str = "-".join(parts[1:]).strip()
                else:
                    # Handle cases where there is no hyphen, assume event is the whole text for now
                    # This might need refinement based on other patterns
                    event_name = text
                    date_str = "" # No date found in this pattern

                # Try to extract a date from the text, as the hyphen split is not always reliable
                date_match = re.search(r'(\w+\s+\d+)', text)
                if date_match:
                    date_str = date_match.group(1)

                # Extract the year from the header text (e.g., "2025")
                year_match = re.search(r'(\d{4})', header.text)
                year = year_match.group(1) if year_match else "2025"
                
                # Handle the edge case for New Year's Day of the following year
                if "new year" in event_name.lower() and "2026" in text.lower():
                    year = "2026"

                # Clean up event name by removing the date part if it was included
                event_name = event_name.replace(date_str, "").strip()
                # Remove trailing hyphens or other characters from the name
                event_name = re.sub(r'\s*-\s*$', '', event_name)

                try:
                    # Remove the day of the week (e.g., "Monday, ") to parse the date
                    date_str_no_weekday = re.sub(r'^\w+,\s*', '', date_str)
                    full_date_str = f"{date_str_no_weekday}, {year}"
                    
                    # Standardize month abbreviations like "Jan" to "January"
                    full_date_str = full_date_str.replace("Jan ", "January ")

                    event_date = datetime.strptime(full_date_str, '%B %d, %Y')
                    iso_date = event_date.strftime('%Y-%m-%d')
                    # Don't add events without a clear name
                    if event_name:
                        events[iso_date] = event_name
                except ValueError:
                    logger.warning(f"Could not parse date from: '{date_str}' in text: '{text}'")

    except Exception as e:
        logger.error(f"Failed to scrape or parse school events: {e}")
        return {}

    logger.info(f"Successfully scraped {len(events)} school events.")
    return events

if __name__ == "__main__":
    scraped_events = scrape_school_events()
    print("\n--- Scraped School Events ---")
    pprint.pprint(scraped_events)
    print("---------------------------\n")
