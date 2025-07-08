import os
import sqlalchemy
from dotenv import load_dotenv
from datetime import date, timedelta

# --- Environment and Database Setup ---
load_dotenv()

DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME")

# Ensure all necessary environment variables are set
if not all([DB_USER, DB_PASSWORD, DB_HOST, DB_PORT, DB_NAME]):
    print("❌ Error: Database environment variables are not fully set.")
    print("Please ensure DB_USER, DB_PASSWORD, DB_HOST, DB_PORT, and DB_NAME are in your .env file.")
    exit(1)

DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
engine = sqlalchemy.create_engine(DATABASE_URL)
metadata = sqlalchemy.MetaData()

# --- Table Definitions ---
# Reflect the existing 'custody' table from the database
try:
    metadata.reflect(engine, only=['custody'])
    custody_table = metadata.tables['custody']
except sqlalchemy.exc.NoSuchTableError:
    print(f"❌ Error: The table 'custody' was not found in the database '{DB_NAME}'.")
    exit(1)

def fix_handoff_days():
    """
    Iterates through the custody table and corrects the handoff_day flag
    based on whether the custodian has changed from the previous day.
    """
    with engine.connect() as connection:
        # Fetch all records, ordered by date
        query = sqlalchemy.select(
            custody_table.c.id,
            custody_table.c.date,
            custody_table.c.custodian_id,
            custody_table.c.handoff_day,
            custody_table.c.family_id # Fetch family_id to process families separately
        ).order_by(custody_table.c.family_id, custody_table.c.date)
        
        try:
            results = connection.execute(query).fetchall()
        except Exception as e:
            print(f"❌ An error occurred while fetching custody records: {e}")
            return

        if not results:
            print("No custody records found to process.")
            return

        print(f"Found {len(results)} custody records to analyze...")

        updates_to_make = []
        previous_custodian_id = None
        previous_family_id = None
        
        for record in results:
            # Reset tracking when family changes
            if record.family_id != previous_family_id:
                previous_custodian_id = None
                previous_family_id = record.family_id

            is_handoff = previous_custodian_id is not None and record.custodian_id != previous_custodian_id
            
            # Check if the current handoff_day value is incorrect
            # Note: record.handoff_day can be None, so we handle that case
            if record.handoff_day != is_handoff:
                updates_to_make.append({'record_id': record.id, 'new_handoff_day': is_handoff})
                
            previous_custodian_id = record.custodian_id

        if not updates_to_make:
            print("✅ All handoff_day flags are already correct. No changes needed.")
            return

        print(f"Found {len(updates_to_make)} records that need correction. Applying updates...")
        
        corrected_count = 0
        try:
            # With SQLAlchemy 2.0 and modern drivers, the transaction begins automatically.
            # We just need to commit it at the end.
            for update in updates_to_make:
                update_statement = (
                    sqlalchemy.update(custody_table)
                    .where(custody_table.c.id == update['record_id'])
                    .values(handoff_day=update['new_handoff_day'])
                )
                connection.execute(update_statement)
                corrected_count += 1
            
            # Commit the transaction after all updates are executed.
            connection.commit()
            print(f"✅ Successfully corrected {corrected_count} records.")
        except Exception as e:
            print(f"❌ An error occurred during the database update: {e}")
            # The engine will automatically roll back the transaction on error.
            connection.rollback()
            print("The transaction has been rolled back. No changes were saved.")

if __name__ == "__main__":
    print("Starting handoff day verification script...")
    fix_handoff_days()
    print("Script finished.") 