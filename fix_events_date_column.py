import os
import asyncio
import databases
from dotenv import load_dotenv
import logging

# Basic logging setup
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

async def run_migration():
    """
    Connects to the database and performs the following migrations on the 'events' table:
    1. Renames the 'event_date' column to 'date' if it exists.
    2. Changes the data type of the 'date' column to DATE if it is not already.
    """
    load_dotenv()
    
    DB_USER = os.getenv('DB_USER')
    DB_PASSWORD = os.getenv('DB_PASSWORD') 
    DB_HOST = os.getenv('DB_HOST')
    DB_PORT = os.getenv('DB_PORT', '5432')
    DB_NAME = os.getenv('DB_NAME')
    
    if not all([DB_USER, DB_PASSWORD, DB_HOST, DB_NAME]):
        logger.error("Database environment variables are not fully set. Aborting migration.")
        return

    DATABASE_URL = f'postgresql+asyncpg://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}'
    database = databases.Database(DATABASE_URL)
    
    try:
        await database.connect()
        logger.info("Successfully connected to the database.")

        # Check column existence
        columns_result = await database.fetch_all("""
            SELECT column_name, data_type 
            FROM information_schema.columns 
            WHERE table_name = 'events' AND table_schema = 'public'
        """)
        column_details = {col['column_name']: col['data_type'] for col in columns_result}

        # Step 1: Rename column if 'event_date' exists and 'date' does not
        if 'event_date' in column_details and 'date' not in column_details:
            logger.info("Found 'event_date' column. Renaming it to 'date'.")
            await database.execute("ALTER TABLE events RENAME COLUMN event_date TO date")
            logger.info("✅ Successfully renamed column 'event_date' to 'date'.")
            # Update local state for next step
            column_details['date'] = column_details.pop('event_date')
        
        # Step 2: Change column type if 'date' exists and is not of type 'date'
        if 'date' in column_details and column_details['date'] != 'date':
            logger.info(f"Column 'date' is of type '{column_details['date']}'. Changing to DATE.")
            # The 'using' clause converts the old string data to the new date type
            await database.execute("ALTER TABLE events ALTER COLUMN date TYPE DATE using to_date(date, 'YYYY-MM-DD')")
            logger.info("✅ Successfully changed column type of 'date' to DATE.")
        elif 'date' in column_details:
             logger.info("✅ Column 'date' already exists with the correct type (DATE). No changes needed.")
        else:
            logger.warning("Could not find 'event_date' or 'date' column. No action taken.")

    except Exception as e:
        logger.error(f"An error occurred during migration: {e}")
        import traceback
        logger.error(traceback.format_exc())
    finally:
        if database.is_connected:
            await database.disconnect()
            logger.info("Database connection closed.")

if __name__ == "__main__":
    logger.info("Starting events table column migration...")
    asyncio.run(run_migration())
    logger.info("Migration script finished.") 