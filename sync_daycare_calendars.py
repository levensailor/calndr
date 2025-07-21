#!/usr/bin/env python3

"""
Weekly Daycare Calendar Sync Job

This script automatically syncs events from all configured daycare calendar URLs.
Run this script via cron weekly to keep daycare events up to date.

Usage:
    python sync_daycare_calendars.py [--dry-run] [--provider-id ID]

Arguments:
    --dry-run: Show what would be synced without making changes
    --provider-id: Sync only a specific daycare provider ID
"""

import os
import sys
import asyncio
import argparse
from datetime import datetime, timezone
from typing import List, Dict, Any

# Add the project root to the Python path
project_root = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, project_root)
sys.path.insert(0, os.path.join(project_root, 'backend'))

from core.database import database
from core.logging import logger
from db.models import daycare_calendar_syncs, daycare_providers, events
from services.daycare_events_service import parse_events_from_url

async def get_sync_configurations(provider_id: int = None) -> List[Dict[str, Any]]:
    """Get all enabled daycare calendar sync configurations."""
    
    query = daycare_calendar_syncs.select().where(
        daycare_calendar_syncs.c.sync_enabled == True
    )
    
    if provider_id:
        query = query.where(daycare_calendar_syncs.c.daycare_provider_id == provider_id)
    
    configs = await database.fetch_all(query)
    
    # Get provider names for better logging
    result = []
    for config in configs:
        provider_query = daycare_providers.select().where(
            daycare_providers.c.id == config['daycare_provider_id']
        )
        provider = await database.fetch_one(provider_query)
        
        result.append({
            "sync_id": config['id'],
            "provider_id": config['daycare_provider_id'],
            "provider_name": provider['name'] if provider else f"Provider {config['daycare_provider_id']}",
            "calendar_url": config['calendar_url'],
            "last_sync_at": config['last_sync_at'],
            "events_count": config['events_count']
        })
    
    return result

async def sync_daycare_calendar(config: Dict[str, Any], dry_run: bool = False) -> Dict[str, Any]:
    """Sync events from a single daycare calendar."""
    
    sync_result = {
        "sync_id": config["sync_id"],
        "provider_name": config["provider_name"],
        "calendar_url": config["calendar_url"],
        "success": False,
        "events_synced": 0,
        "error": None
    }
    
    try:
        logger.info(f"Syncing calendar for {config['provider_name']}: {config['calendar_url']}")
        
        # Parse events from the calendar URL
        events_data = await parse_events_from_url(config['calendar_url'])
        
        if dry_run:
            sync_result.update({
                "success": True,
                "events_synced": len(events_data),
                "dry_run": True
            })
            logger.info(f"DRY RUN: Would sync {len(events_data)} events for {config['provider_name']}")
            return sync_result
        
        # TODO: In a full implementation, you might want to:
        # 1. Store these events in a separate daycare_events table
        # 2. Integrate with the main events table if desired
        # 3. Send notifications about new/changed events
        # 4. Clean up old events that are no longer in the calendar
        
        # For now, we'll just update the sync tracking
        sync_data = {
            "last_sync_at": datetime.now(timezone.utc),
            "last_sync_success": True,
            "last_sync_error": None,
            "events_count": len(events_data)
        }
        
        await database.execute(
            daycare_calendar_syncs.update()
            .where(daycare_calendar_syncs.c.id == config['sync_id'])
            .values(**sync_data)
        )
        
        sync_result.update({
            "success": True,
            "events_synced": len(events_data)
        })
        
        logger.info(f"Successfully synced {len(events_data)} events for {config['provider_name']}")
        
    except Exception as e:
        error_msg = str(e)
        sync_result["error"] = error_msg
        
        # Update sync tracking with error
        if not dry_run:
            try:
                await database.execute(
                    daycare_calendar_syncs.update()
                    .where(daycare_calendar_syncs.c.id == config['sync_id'])
                    .values({
                        "last_sync_at": datetime.now(timezone.utc),
                        "last_sync_success": False,
                        "last_sync_error": error_msg
                    })
                )
            except Exception as update_error:
                logger.error(f"Failed to update sync error status: {update_error}")
        
        logger.error(f"Failed to sync calendar for {config['provider_name']}: {error_msg}")
    
    return sync_result

async def sync_all_daycare_calendars(dry_run: bool = False, provider_id: int = None):
    """Sync all configured daycare calendars."""
    
    logger.info("🚀 Starting daycare calendar sync job...")
    
    if dry_run:
        logger.info("🔍 DRY RUN MODE - No changes will be made")
    
    if provider_id:
        logger.info(f"🎯 Syncing only provider ID: {provider_id}")
    
    try:
        # Get all sync configurations
        configs = await get_sync_configurations(provider_id)
        
        if not configs:
            logger.info("📭 No daycare calendar sync configurations found")
            return
        
        logger.info(f"📋 Found {len(configs)} calendar sync configurations")
        
        # Sync each calendar
        results = []
        for config in configs:
            result = await sync_daycare_calendar(config, dry_run)
            results.append(result)
        
        # Summary
        successful_syncs = [r for r in results if r["success"]]
        failed_syncs = [r for r in results if not r["success"]]
        total_events = sum(r["events_synced"] for r in successful_syncs)
        
        logger.info(f"✅ Sync job completed:")
        logger.info(f"   📊 Total configurations: {len(configs)}")
        logger.info(f"   ✅ Successful syncs: {len(successful_syncs)}")
        logger.info(f"   ❌ Failed syncs: {len(failed_syncs)}")
        logger.info(f"   📅 Total events synced: {total_events}")
        
        if failed_syncs:
            logger.warning("❌ Failed syncs:")
            for failed in failed_syncs:
                logger.warning(f"   - {failed['provider_name']}: {failed['error']}")
        
        if dry_run:
            logger.info("🔍 DRY RUN completed - no changes were made")
    
    except Exception as e:
        logger.error(f"❌ Critical error in sync job: {e}")
        raise

async def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description="Sync daycare calendar events")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be synced without making changes")
    parser.add_argument("--provider-id", type=int, help="Sync only a specific daycare provider ID")
    
    args = parser.parse_args()
    
    try:
        # Connect to database
        await database.connect()
        
        # Run the sync
        await sync_all_daycare_calendars(dry_run=args.dry_run, provider_id=args.provider_id)
        
    except Exception as e:
        logger.error(f"Sync job failed: {e}")
        sys.exit(1)
    finally:
        # Disconnect from database
        await database.disconnect()

if __name__ == "__main__":
    asyncio.run(main()) 