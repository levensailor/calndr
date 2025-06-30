# This is the database migration script.

import os
import databases
import sqlalchemy
from dotenv import load_dotenv
import asyncio
import sqlite3
from sqlalchemy.sql import text
from sqlalchemy import create_engine, inspect
import logging

# --- Logging ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables from .env file
load_dotenv()

# --- SOURCE DATABASE (SQLite) ---
SQLITE_DATABASE_URL = "sqlite:///calendar.db"
sqlite_db = databases.Database(SQLITE_DATABASE_URL)
metadata_sqlite = sqlalchemy.MetaData()

# Define tables for SQLite (must match original schema)
events_sqlite = sqlalchemy.Table(
    "events",
    metadata_sqlite,
    sqlalchemy.Column("id", sqlalchemy.Integer, primary_key=True),
    sqlalchemy.Column("event_date", sqlalchemy.String),
    sqlalchemy.Column("content", sqlalchemy.String),
    sqlalchemy.Column("position", sqlalchemy.Integer),
)

notification_emails_sqlite = sqlalchemy.Table(
    "notification_emails",
    metadata_sqlite,
    sqlalchemy.Column("id", sqlalchemy.Integer, primary_key=True),
    sqlalchemy.Column("email", sqlalchemy.String, unique=True, nullable=False),
)

app_settings_sqlite = sqlalchemy.Table(
    "app_settings",
    metadata_sqlite,
    sqlalchemy.Column("key", sqlalchemy.String, primary_key=True),
    sqlalchemy.Column("value", sqlalchemy.String),
)

# --- DESTINATION DATABASE (PostgreSQL) ---
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME")

POSTGRES_DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
postgres_db = databases.Database(POSTGRES_DATABASE_URL)
metadata_postgres = sqlalchemy.MetaData()

# Define tables for PostgreSQL (must match app.py schema)
events_postgres = sqlalchemy.Table(
    "events",
    metadata_postgres,
    sqlalchemy.Column("id", sqlalchemy.Integer, primary_key=True),
    sqlalchemy.Column("event_date", sqlalchemy.String),
    sqlalchemy.Column("content", sqlalchemy.String),
    sqlalchemy.Column("position", sqlalchemy.Integer),
)

notification_emails_postgres = sqlalchemy.Table(
    "notification_emails",
    metadata_postgres,
    sqlalchemy.Column("id", sqlalchemy.Integer, primary_key=True),
    sqlalchemy.Column("email", sqlalchemy.String, unique=True, nullable=False),
)

app_settings_postgres = sqlalchemy.Table(
    "app_settings",
    metadata_postgres,
    sqlalchemy.Column("key", sqlalchemy.String, primary_key=True),
    sqlalchemy.Column("value", sqlalchemy.String),
)

async def migrate_table(source_db, source_table, dest_db, dest_table):
    """Generic function to migrate data from a source table to a destination table."""
    print(f"Starting migration for table: {source_table.name}")
    
    # Read data from source
    query_select = source_table.select()
    try:
        records = await source_db.fetch_all(query_select)
    except sqlite3.OperationalError as e:
        if "no such table" in str(e):
            print(f"Warning: Source table '{source_table.name}' does not exist in calendar.db. Skipping.")
            return
        else:
            # Re-raise for other operational errors
            print(f"An unexpected SQLite error occurred: {e}")
            raise
    
    if not records:
        print(f"No records found in {source_table.name}. Nothing to migrate.")
        return
        
    # Write data to destination
    # We will do this record by record to avoid any potential DB-specific bulk insertion issues.
    for record in records:
        # Convert record to a dictionary to pass as values
        record_dict = dict(record)
        query_insert = dest_table.insert().values(**record_dict)
        try:
            await dest_db.execute(query_insert)
        except Exception as e:
            print(f"Could not insert record {record_dict}: {e}")
            print("This may be expected if the data already exists. Continuing...")

    print(f"Finished migration for table: {source_table.name}. Migrated {len(records)} records.")


async def main():
    """Adds the apns_token column to the users table if it doesn't exist."""
    print("--- Starting Database Migration for APNs Token ---")
    
    # We don't use the 'databases' library here, so we don't need to connect/disconnect it.
    # We use a standard SQLAlchemy engine and connection context.
    engine = sqlalchemy.create_engine(POSTGRES_DATABASE_URL)
    
    try:
        with engine.connect() as connection:
            # SQLAlchemy 2.0 requires transactions to be explicitly started
            with connection.begin():
                print("Checking for 'apns_token' column in 'users' table...")
                
                # Check if the column already exists
                check_query = text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name='users' AND column_name='apns_token'
                """)
                result = connection.execute(check_query)

                if result.fetchone():
                    print("  - 'apns_token' column already exists. No changes needed.")
                else:
                    print("  - 'apns_token' column not found. Adding it now...")
                    alter_query = text("ALTER TABLE users ADD COLUMN apns_token VARCHAR(255) NULL")
                    connection.execute(alter_query)
                    print("  - 'apns_token' column added successfully.")
            
        print("\n--- Database Migration Complete ---")

    except Exception as e:
        print(f"An error occurred during migration: {e}")
    finally:
        # Dispose of the engine to close all connections
        engine.dispose()
        print("Database connection resources released.")


def run_migration():
    """
    Connects to the database and applies necessary schema migrations.
    """
    logger.info("--- Starting database migration ---")
    if not all([DB_USER, DB_PASSWORD, DB_HOST, DB_NAME]):
        logger.error("FATAL: Missing one or more required database environment variables.")
        exit(1)

    try:
        engine = create_engine(POSTGRES_DATABASE_URL)
        with engine.connect() as connection:
            # Use a transaction to ensure atomicity
            with connection.begin():
                inspector = inspect(engine)
                columns = [col['name'] for col in inspector.get_columns('users')]

                if 'apns_token' in columns:
                    logger.info("Column 'apns_token' already exists in 'users' table. No migration needed.")
                else:
                    logger.info("Column 'apns_token' not found in 'users' table. Adding it now...")
                    # The VARCHAR length is arbitrary but should be sufficient for an APNS token
                    add_column_query = text('ALTER TABLE users ADD COLUMN apns_token VARCHAR(255);')
                    connection.execute(add_column_query)
                    logger.info("Successfully added 'apns_token' column to 'users' table.")

        logger.info("--- Database migration finished successfully! ---")

    except Exception as e:
        logger.error(f"An error occurred during database migration: {e}")
        exit(1) # Exit with a non-zero status code to indicate failure


if __name__ == "__main__":
    run_migration() 