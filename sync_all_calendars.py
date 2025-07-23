#!/usr/bin/env python3
"""
Sync all school and daycare calendars.
This script should be run periodically (e.g., daily via cron).
"""

import asyncio
import os
import sys
from datetime import datetime
from dotenv import load_dotenv

# Add backend directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend'))

from core.database import database
from core.logging import logger
from services.event_sync_service import sync_all_enabled_calendars

async def main():
    """Main function to sync all calendars."""
    try:
        logger.info("=" * 50)
        logger.info(f"Starting calendar sync at {datetime.now()}")
        logger.info("=" * 50)
        
        # Run the sync
        results = await sync_all_enabled_calendars()
        
        # Log summary
        logger.info("=" * 50)
        logger.info("SYNC SUMMARY:")
        logger.info(f"Schools: {results['schools']['successful']}/{results['schools']['total']} successful")
        logger.info(f"  Events synced: {results['schools']['events_synced']}")
        logger.info(f"  Failed: {results['schools']['failed']}")
        
        logger.info(f"Daycares: {results['daycares']['successful']}/{results['daycares']['total']} successful")
        logger.info(f"  Events synced: {results['daycares']['events_synced']}")
        logger.info(f"  Failed: {results['daycares']['failed']}")
        logger.info("=" * 50)
        
        # Return exit code based on results
        if results['schools']['failed'] > 0 or results['daycares']['failed'] > 0:
            return 1  # Some failures
        return 0  # All successful
        
    except Exception as e:
        logger.error(f"Fatal error during sync: {e}", exc_info=True)
        return 1
    finally:
        await database.disconnect()

if __name__ == "__main__":
    load_dotenv()
    exit_code = asyncio.run(main())
    sys.exit(exit_code)