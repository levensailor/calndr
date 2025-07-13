#!/usr/bin/env python3

import os
import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
from dotenv import load_dotenv
import logging
from datetime import datetime

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Database connection parameters
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME")

def create_daycare_providers_table():
    """Create the daycare_providers table."""
    
    connection = None
    cursor = None
    
    try:
        # Connect to the database
        connection = psycopg2.connect(
            user=DB_USER,
            password=DB_PASSWORD,
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME
        )
        connection.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cursor = connection.cursor()
        
        logger.info("Connected to database successfully")
        
        # Check if table already exists
        cursor.execute("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name = 'daycare_providers'
            );
        """)
        
        table_exists = cursor.fetchone()[0]
        
        if table_exists:
            logger.info("Table 'daycare_providers' already exists")
            return
        
        # Create the daycare_providers table
        create_table_query = """
        CREATE TABLE daycare_providers (
            id SERIAL PRIMARY KEY,
            family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
            name VARCHAR(255) NOT NULL,
            address TEXT,
            phone_number VARCHAR(20),
            email VARCHAR(255),
            hours VARCHAR(255),
            notes TEXT,
            google_place_id VARCHAR(255),
            rating DECIMAL(3, 2),
            website VARCHAR(500),
            created_by_user_id UUID NOT NULL REFERENCES users(id),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        """
        
        cursor.execute(create_table_query)
        logger.info("Created 'daycare_providers' table successfully")
        
        # Create indexes for better performance
        cursor.execute("CREATE INDEX idx_daycare_providers_family_id ON daycare_providers(family_id);")
        cursor.execute("CREATE INDEX idx_daycare_providers_created_by_user_id ON daycare_providers(created_by_user_id);")
        cursor.execute("CREATE INDEX idx_daycare_providers_google_place_id ON daycare_providers(google_place_id);")
        
        logger.info("Created indexes for 'daycare_providers' table successfully")
        
        # Create trigger to automatically update updated_at timestamp
        cursor.execute("""
            CREATE OR REPLACE FUNCTION update_updated_at_column()
            RETURNS TRIGGER AS $$
            BEGIN
                NEW.updated_at = CURRENT_TIMESTAMP;
                RETURN NEW;
            END;
            $$ language 'plpgsql';
        """)
        
        cursor.execute("""
            CREATE TRIGGER update_daycare_providers_updated_at 
            BEFORE UPDATE ON daycare_providers 
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
        """)
        
        logger.info("Created trigger for automatic updated_at timestamp")
        
        logger.info("Migration completed successfully!")
        
    except psycopg2.Error as e:
        logger.error(f"Database error: {e}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        raise
    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()
        logger.info("Database connection closed")

if __name__ == "__main__":
    logger.info("Starting daycare_providers table migration...")
    create_daycare_providers_table()
    logger.info("Migration completed!") 