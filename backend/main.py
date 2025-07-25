from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from core.config import settings
from core.database import database
from core.middleware import add_no_cache_headers
from services.redis_service import redis_service
from api.v1.api import api_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    """FastAPI lifespan event handler."""
    # Initialize database connection
    await database.connect()
    
    # Initialize Redis connection
    await redis_service.connect()
    
    yield
    
    # Cleanup connections
    await redis_service.disconnect()
    await database.disconnect()

def create_app() -> FastAPI:
    """Create FastAPI application with all configurations."""
    app = FastAPI(
        title=settings.PROJECT_NAME,
        version=settings.VERSION,
        description=settings.DESCRIPTION,
        lifespan=lifespan
    )
    
    # Add middleware
    app.middleware("http")(add_no_cache_headers)
    
    # Add CORS middleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],  # Allow all origins like the original app.py
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"]
    )
    
    # Include API routes under /api/v1 to match client expectations
    app.include_router(api_router, prefix="/api/v1")
    
    # Add health check endpoint
    @app.get("/health")
    async def health_check():
        """Health check endpoint for monitoring."""
        try:
            # Test database connection
            await database.fetch_one("SELECT 1 as test")
            db_status = "connected"
        except Exception as e:
            db_status = f"error: {str(e)}"
        
        return {
            "status": "healthy" if db_status == "connected" else "unhealthy",
            "service": "calndr-backend", 
            "version": settings.VERSION,
            "database": db_status
        }
    
    # Add database connection info endpoint for debugging
    @app.get("/db-info")
    async def database_info():
        """Database connection information for debugging."""
        try:
            # Get current connection info
            pool_info = {
                "min_size": getattr(database._backend._pool, "minsize", "unknown"),
                "max_size": getattr(database._backend._pool, "maxsize", "unknown"),
                "size": getattr(database._backend._pool, "size", "unknown"),
                "freesize": getattr(database._backend._pool, "freesize", "unknown"),
            }
        except AttributeError:
            pool_info = {"error": "Pool information not available"}
        
        return {
            "database_url_host": settings.DB_HOST,
            "database_name": settings.DB_NAME,
            "pool_info": pool_info
        }
    
    # Add cache status endpoint
    @app.get("/cache-status")
    async def cache_status():
        """Cache status information for monitoring."""
        cache_stats = await redis_service.get_cache_stats()
        return {
            "cache": cache_stats,
            "cache_config": {
                "redis_host": settings.REDIS_HOST,
                "redis_port": settings.REDIS_PORT,
                "redis_db": settings.REDIS_DB,
                "ttl_events": settings.CACHE_TTL_EVENTS,
                "ttl_weather_forecast": settings.CACHE_TTL_WEATHER_FORECAST,
                "ttl_weather_historic": settings.CACHE_TTL_WEATHER_HISTORIC,
                "ttl_user_profile": settings.CACHE_TTL_USER_PROFILE,
                "ttl_family_data": settings.CACHE_TTL_FAMILY_DATA
            }
        }
    
    return app

app = create_app()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
