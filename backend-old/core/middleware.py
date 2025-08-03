from fastapi import Request, HTTPException
from fastapi.responses import Response
import re
from core.logging import logger

# Bot and scanner user agents to filter out
BOT_USER_AGENTS = [
    r'bot', r'crawler', r'spider', r'scraper', r'scanner', 
    r'censys', r'shodan', r'masscan', r'nmap', r'zmap',
    r'nuclei', r'sqlmap', r'dirb', r'gobuster', r'nikto'
]

async def bot_filter_middleware(request: Request, call_next):
    """Filter out bot/scanner requests to reduce invalid HTTP warnings."""
    user_agent = request.headers.get("user-agent", "").lower()
    
    # Check if request is from a known bot/scanner
    for bot_pattern in BOT_USER_AGENTS:
        if re.search(bot_pattern, user_agent):
            logger.debug(f"Filtered bot request from {request.client.host}: {user_agent}")
            return Response(status_code=403, content="Forbidden")
    
    # Check for common scanner paths that cause invalid HTTP requests
    scanner_paths = [
        r'/\.env', r'/config\.php', r'/wp-admin', r'/phpmyadmin',
        r'/admin', r'/login\.php', r'/xmlrpc\.php', r'/wp-content',
        r'/vendor', r'/\.git', r'/backup', r'/sql', r'/db'
    ]
    
    for scanner_path in scanner_paths:
        if re.search(scanner_path, request.url.path):
            logger.debug(f"Filtered scanner path request: {request.url.path}")
            return Response(status_code=404, content="Not Found")
    
    try:
        response = await call_next(request)
        return response
    except Exception as e:
        logger.error(f"Request processing error: {e}")
        return Response(status_code=500, content="Internal Server Error")

async def add_no_cache_headers(request: Request, call_next):
    """Add no-cache headers to API responses."""
    response = await call_next(request)
    if request.url.path.startswith("/api/"):
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
    return response
