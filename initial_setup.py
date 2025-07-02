import os
import databases
import sqlalchemy
from dotenv import load_dotenv
import asyncio
from datetime import date
from passlib.context import CryptContext
from app import metadata, families, users, children, schedules, subscriptions, events, engine

# This script is intended to be run ON THE SERVER during deployment.

# Explicitly provide the path to the .env file
load_dotenv()

# --- DATABASE (PostgreSQL) ---
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME")

DATABASE_URL = f"postgresql+asyncpg://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
db = databases.Database(DATABASE_URL)

# --- Password Hashing ---
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_password_hash(password):
    return pwd_context.hash(password)

async def main():
    """Connects to the DB, clears old data, and seeds it with initial data."""
    print("--- Starting Initial Database Setup ---")
    
    try:
        await db.connect()
        
        # Ensure all tables are created
        print("Creating all database tables if they don't exist...")
        metadata.create_all(engine)
        print("✅ All tables ensured to exist.")
        
        # 1. Clear existing data to ensure a clean slate
        # We delete in reverse order of dependency
        print("Clearing existing user and family data...")
        await db.execute(events.delete())
        await db.execute(schedules.delete())
        await db.execute(subscriptions.delete())
        await db.execute(children.delete())
        await db.execute(users.delete())
        await db.execute(families.delete())
        print("  - Cleared all previous data.")

        # 2. Create the Family
        print("Creating the Levensailor family...")
        family_query = families.insert().values(name="Levensailor").returning(families.c.id)
        family_id = await db.execute(family_query)
        print(f"  - Family created with ID: {family_id}")

        # 3. Hash passwords and create users
        print("Creating user accounts...")
        jeff_password_hash = get_password_hash("rowen")
        deanna_password_hash = get_password_hash("rowen")

        jeff_query = users.insert().values(
            family_id=family_id,
            first_name="Jeff",
            last_name="Levensailor",
            email="jeff@levensailor.com",
            password_hash=jeff_password_hash,
            phone_number="9194289853"
        ).returning(users.c.id)
        jeff_id = await db.execute(jeff_query)
        print(f"  - User 'Jeff' created with ID: {jeff_id}")

        deanna_query = users.insert().values(
            family_id=family_id,
            first_name="Deanna",
            last_name="Levensailor",
            email="deanna@levensailor.com",
            password_hash=deanna_password_hash,
            phone_number="9102741355"
        ).returning(users.c.id)
        deanna_id = await db.execute(deanna_query)
        print(f"  - User 'Deanna' created with ID: {deanna_id}")

        # 4. Create the Child
        print("Creating child record...")
        child_query = children.insert().values(
            family_id=family_id,
            first_name="Rowen",
            last_name="Levensailor",
            dob=date(2023, 1, 5)
        )
        await db.execute(child_query)
        print("  - Child 'Rowen' created.")

        # 5. Create the Schedule
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
        
        # 6. Create a default subscription
        print("Creating subscription...")
        subscription_query = subscriptions.insert().values(
            family_id=family_id,
            plan_type="pro",
            status="active"
        )
        await db.execute(subscription_query)
        print("  - Default 'pro' subscription created.")

        print("\n--- Database Initial Setup Complete ---")

    except Exception as e:
        print(f"An error occurred during initial setup: {e}")
    finally:
        if db.is_connected:
            await db.disconnect()
            print("Database connection closed.")


if __name__ == "__main__":
    if not all([DB_USER, DB_PASSWORD, DB_HOST, DB_NAME]):
        print("ERROR: Missing one or more required environment variables.")
    else:
        asyncio.run(main()) 