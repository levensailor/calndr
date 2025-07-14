from fastapi import Request
from fastapi.responses import Response

async def add_no_cache_headers(request: Request, call_next):
    """Add no-cache headers to API responses."""
    response = await call_next(request)
    if request.url.path.startswith("/api/"):
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
    return response
