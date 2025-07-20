import os
from typing import List, Optional
from pydantic_settings import BaseSettings
from dotenv import load_dotenv

load_dotenv()

class Settings(BaseSettings):
    """
    Application settings.
    """
    
    # Application
    PROJECT_NAME: str = "Calndr API"
    VERSION: str = "1.0.0"
    DESCRIPTION: str = "Family Calendar Management API"
    API_V1_STR: str = "/api/v1"
    
    # Security
    SECRET_KEY: str = os.getenv("SECRET_KEY", "a_random_secret_key_for_development")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 30  # 30 days
    
    # CORS
    ALLOWED_ORIGINS: List[str] = [
        "http://localhost:3000",
        "https://calndr.club",
        "https://www.calndr.club",
        "http://localhost:8080",
        "capacitor://localhost",
        "ionic://localhost",
        "http://localhost",
        "http://localhost:8100",
        "https://localhost:8100"
    ]
    
    # Database
    DB_USER: str = os.getenv("DB_USER", "")
    DB_PASSWORD: str = os.getenv("DB_PASSWORD", "")
    DB_HOST: str = os.getenv("DB_HOST", "localhost")
    DB_PORT: str = os.getenv("DB_PORT", "5432")
    DB_NAME: str = os.getenv("DB_NAME", "calndr")
    
    @property
    def DATABASE_URL(self) -> str:
        return f"postgresql+asyncpg://{self.DB_USER}:{self.DB_PASSWORD}@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"
    
    # AWS
    AWS_ACCESS_KEY_ID: str = os.getenv("AWS_ACCESS_KEY_ID", "")
    AWS_SECRET_ACCESS_KEY: str = os.getenv("AWS_SECRET_ACCESS_KEY", "")
    AWS_REGION: str = os.getenv("AWS_REGION", "us-east-1")
    AWS_S3_BUCKET_NAME: str = os.getenv("AWS_S3_BUCKET_NAME", "")
    
    # Push Notifications
    SNS_PLATFORM_APPLICATION_ARN: Optional[str] = os.getenv("SNS_PLATFORM_APPLICATION_ARN")
    
    # External APIs
    GOOGLE_PLACES_API_KEY: Optional[str] = os.getenv("GOOGLE_PLACES_API_KEY")
    
    # Email Configuration
    SMTP_USER: Optional[str] = os.getenv("SMTP_USER")
    SMTP_PASSWORD: Optional[str] = os.getenv("SMTP_PASSWORD")
    SMTP_HOST: Optional[str] = os.getenv("SMTP_HOST")
    SMTP_PORT: Optional[int] = os.getenv("SMTP_PORT")

    # Apple Sign-In
    APPLE_CLIENT_ID: Optional[str] = os.getenv("APPLE_CLIENT_ID")
    APPLE_TEAM_ID: Optional[str] = os.getenv("APPLE_TEAM_ID")
    APPLE_KEY_ID: Optional[str] = os.getenv("APPLE_KEY_ID")
    APPLE_PRIVATE_KEY: Optional[str] = os.getenv("APPLE_PRIVATE_KEY")
    APPLE_REDIRECT_URI: Optional[str] = os.getenv("APPLE_REDIRECT_URI")
    
    class Config:
        case_sensitive = True
        env_file = ".env"
        extra = "ignore"

settings = Settings()
