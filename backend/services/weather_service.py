import time
import hashlib
from typing import Optional, Dict
from core.logging import logger

# Simple in-memory cache with TTL (time-to-live) expiration
weather_cache = {}

def get_cache_key(latitude: float, longitude: float, start_date: str, end_date: str, endpoint_type: str) -> str:
    """Generate a unique cache key for weather data."""
    key_string = f"{endpoint_type}:{latitude}:{longitude}:{start_date}:{end_date}"
    return hashlib.md5(key_string.encode()).hexdigest()

def get_cached_weather(cache_key: str) -> Optional[Dict]:
    """Get cached weather data if it exists and hasn't expired."""
    if cache_key in weather_cache:
        cached_data, timestamp = weather_cache[cache_key]
        # Cache expires after 1 hour for forecast, 24 hours for historic
        cache_ttl = 3600 if "forecast" in cache_key else 259200
        if time.time() - timestamp < cache_ttl:
            return cached_data
        else:
            # Remove expired cache entry
            del weather_cache[cache_key]
    return None

def cache_weather_data(cache_key: str, data: Dict):
    """Cache weather data with timestamp."""
    weather_cache[cache_key] = (data, time.time())
