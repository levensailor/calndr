import os
import databases
import sqlalchemy
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from dotenv import load_dotenv
import asyncio
from datetime import date
from passlib.context import CryptContext

# Load environment variables from .env file
load_dotenv()

# --- DATABASE (PostgreSQL) ---
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME")

DATABASE_URL = f"postgresql+asyncpg://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
db = databases.Database(DATABASE_URL)
metadata = sqlalchemy.MetaData()

# --- Password Hashing ---
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_password_hash(password):
    return pwd_context.hash(password)

# --- Table Definitions (must match migrate_to_multitenant.py) ---
families = sqlalchemy.Table("families", metadata, autoload_with=sqlalchemy.create_engine(DATABASE_URL.replace("+asyncpg", "")))
users = sqlalchemy.Table("users", metadata, autoload_with=sqlalchemy.create_engine(DATABASE_URL.replace("+asyncpg", "")))
children = sqlalchemy.Table("children", metadata, autoload_with=sqlalchemy.create_engine(DATABASE_URL.replace("+asyncpg", "")))
schedules = sqlalchemy.Table("schedules", metadata, autoload_with=sqlalchemy.create_engine(DATABASE_URL.replace("+asyncpg", "")))
subscriptions = sqlalchemy.Table("subscriptions", metadata, autoload_with=sqlalchemy.create_engine(DATABASE_URL.replace("+asyncpg", "")))

async def main():
    """Connects to the DB and seeds it with initial data."""
    print("--- Starting Database Seeding ---")
    
    try:
        await db.connect()
        
        # 1. Create the Family
        print("Creating the Levensailor family...")
        family_id = uuid.uuid4()
        family_query = families.insert().values(id=family_id, name="Levensailor")
        await db.execute(family_query)
        print(f"  - Family created with ID: {family_id}")

        # 2. Hash passwords and create users
        print("Creating user accounts...")
        jeff_password_hash = get_password_hash("rowen")
        deanna_password_hash = get_password_hash("rowen")

        jeff_id = uuid.uuid4()
        jeff_query = users.insert().values(
            id=jeff_id,
            family_id=family_id,
            first_name="Jeff",
            last_name="Levensailor",
            email="jeff@levensailor.com",
            password_hash=jeff_password_hash,
            phone_number="9194289853"
        )
        await db.execute(jeff_query)
        print(f"  - User 'Jeff' created with ID: {jeff_id}")

        deanna_id = uuid.uuid4()
        deanna_query = users.insert().values(
            id=deanna_id,
            family_id=family_id,
            first_name="Deanna",
            last_name="Levensailor",
            email="deanna@levensailor.com",
            password_hash=deanna_password_hash,
            phone_number="9102741355"
        )
        await db.execute(deanna_query)
        print(f"  - User 'Deanna' created with ID: {deanna_id}")

        # 3. Create the Child
        print("Creating child record...")
        child_query = children.insert().values(
            family_id=family_id,
            first_name="Rowen",
            last_name="Levensailor",
            dob=date(2023, 1, 5)
        )
        await db.execute(child_query)
        print("  - Child 'Rowen' created.")

        # 4. Create the Schedule
        print("Creating schedule...")
        schedule_query = schedules.insert().values(
            family_id=family_id,
            saturday_guardian_id=jeff_id,
            sunday_guardian_id=jeff_id,
            monday_guardian_id=jeff_id,
            tuesday_guardian_id=deanna_id,
            wednesday_guardian_id=deanna_id,
            thursday_guardian_id=deanna_id,
            friday_guardian_id=deanna_id
        )
        await db.execute(schedule_query)
        print("  - Schedule created.")
        
        # 5. Create a default subscription
        print("Creating subscription...")
        subscription_query = subscriptions.insert().values(
            family_id=family_id,
            plan_type="pro", # Let's give them the pro plan
            status="active"
        )
        await db.execute(subscription_query)
        print("  - Default 'pro' subscription created.")


        print("\n--- Database Seeding Complete ---")

    except Exception as e:
        print(f"An error occurred during seeding: {e}")
    finally:
        if db.is_connected:
            await db.disconnect()
            print("Database connection closed.")


if __name__ == "__main__":
    if not all([DB_USER, DB_PASSWORD, DB_HOST, DB_NAME]):
        print("ERROR: Missing one or more required environment variables.")
    else:
        asyncio.run(main()) 