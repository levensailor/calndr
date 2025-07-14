import databases
import sqlalchemy
from sqlalchemy import create_engine
from core.config import settings

# Database setup
database = databases.Database(settings.DATABASE_URL)
metadata = sqlalchemy.MetaData()
engine = create_engine(settings.DATABASE_URL.replace("+asyncpg", ""))
