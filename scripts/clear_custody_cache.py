#!/usr/bin/env python3
import os
import sys
import redis
import logging
from datetime import datetime, timedelta

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %I:%M:%S %p EST'
)
logger = logging.getLogger(__name__)

def get_redis_client():
    """Create Redis client from environment variables."""
    try:
        # Get Redis configuration from environment
        redis_host = os.getenv('REDIS_HOST', 'localhost')
        redis_port = int(os.getenv('REDIS_PORT', '6379'))
        redis_password = os.getenv('REDIS_PASSWORD')
        redis_db = int(os.getenv('REDIS_DB', '0'))

        # Create Redis client
        client = redis.Redis(
            host=redis_host,
            port=redis_port,
            password=redis_password,
            db=redis_db,
            decode_responses=True,
            socket_timeout=5
        )

        # Test connection
        client.ping()
        logger.info(f"✅ Connected to Redis at {redis_host}:{redis_port}")
        return client
    except Exception as e:
        logger.error(f"❌ Failed to connect to Redis: {e}")
        sys.exit(1)

def clear_custody_cache(redis_client, family_id=None):
    """Clear custody-related caches for a family or all families."""
    try:
        # Get current date for logging
        now = datetime.now()
        
        # Clear pattern-based caches
        if family_id:
            patterns = [
                f"custody*:family:{family_id}:*",
                f"custody_opt:family:{family_id}:*",
                f"handoff_only:family:{family_id}:*"
            ]
            logger.info(f"🔍 Clearing caches for family {family_id}")
        else:
            patterns = [
                "custody*:family:*",
                "custody_opt:family:*",
                "handoff_only:family:*"
            ]
            logger.info("🔍 Clearing caches for all families")

        # Clear each pattern
        total_keys = 0
        for pattern in patterns:
            # Get all keys matching pattern
            keys = list(redis_client.scan_iter(match=pattern))
            if keys:
                # Delete keys in batches
                pipeline = redis_client.pipeline()
                for key in keys:
                    pipeline.delete(key)
                    total_keys += 1
                pipeline.execute()
                logger.info(f"✅ Cleared {len(keys)} keys matching pattern: {pattern}")
            else:
                logger.info(f"ℹ️ No keys found matching pattern: {pattern}")

        # Also clear specific month caches for recent months
        if family_id:
            # Clear last 3 months and next 3 months
            for i in range(-3, 4):
                target_date = now + timedelta(days=i*30)
                year = target_date.year
                month = target_date.month
                
                # Clear main custody cache
                custody_key = f"custody_opt:family:{family_id}:{year}:{month:02d}"
                if redis_client.delete(custody_key):
                    total_keys += 1
                    logger.info(f"✅ Cleared custody cache for {year}/{month:02d}")
                
                # Clear handoff cache
                handoff_key = f"handoff_only:family:{family_id}:{year}:{month:02d}"
                if redis_client.delete(handoff_key):
                    total_keys += 1
                    logger.info(f"✅ Cleared handoff cache for {year}/{month:02d}")

        logger.info(f"✨ Successfully cleared {total_keys} cache keys")
        return True

    except Exception as e:
        logger.error(f"❌ Error clearing cache: {e}")
        return False

def main():
    """Main function to clear custody caches."""
    # Get family ID from command line argument if provided
    family_id = sys.argv[1] if len(sys.argv) > 1 else None
    
    # Connect to Redis
    redis_client = get_redis_client()
    
    # Clear caches
    if clear_custody_cache(redis_client, family_id):
        logger.info("✅ Cache clearing completed successfully")
    else:
        logger.error("❌ Failed to clear caches")
        sys.exit(1)

if __name__ == "__main__":
    main()
