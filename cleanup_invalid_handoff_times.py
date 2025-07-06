#!/usr/bin/env python3

"""
Cleanup script for the handoff_times table.

This script performs two tasks:
1. Removes any rows where a handoff could not have taken place because the
   custody did not actually change (i.e. both parent IDs are present and
   identical).
2. Adds a CHECK constraint to prevent future inserts where from_parent_id and
   to_parent_id are both non-NULL and identical.

Run this script once after deploying the updated application logic so the
existing data matches what the client expects.

It is intentionally idempotent – multiple executions will have no additional
side-effects once the table is clean and the constraint exists.
"""

import os
import sys
import psycopg2
from psycopg2 import sql
from dotenv import load_dotenv

# ---------------------------------------------------------------------------
# Load environment variables for DB connection
# ---------------------------------------------------------------------------
load_dotenv()

DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")

if not all([DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD]):
    sys.exit("❌ One or more required DB_* environment variables are missing.")

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

def get_connection():
    """Establish and return a blocking psycopg2 connection."""
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
    )

# ---------------------------------------------------------------------------
# Main routine
# ---------------------------------------------------------------------------

def main():
    print("🔍 Connecting to database…")
    conn = get_connection()
    conn.autocommit = False  # allow explicit transaction control

    try:
        with conn.cursor() as cur:
            # 1. Identify invalid rows (both IDs non-NULL and equal)
            print("\n📋 Checking for invalid handoff rows (no actual parent change)…")
            cur.execute(
                """
                SELECT id, date, from_parent_id, to_parent_id
                  FROM handoff_times
                 WHERE from_parent_id IS NOT NULL
                   AND to_parent_id IS NOT NULL
                   AND from_parent_id = to_parent_id
                """
            )
            invalid_rows = cur.fetchall()
            invalid_count = len(invalid_rows)

            if invalid_count == 0:
                print("✅ No invalid handoff records found – database is already clean.")
            else:
                print(f"⚠️  Found {invalid_count} invalid handoff record(s):")
                for row in invalid_rows:
                    record_id, date, from_id, _ = row
                    print(f"   • id={record_id}, date={date}, parent_id={from_id}")

                # 2. Delete invalid rows
                print("\n🗑️  Deleting invalid handoff records…")
                cur.execute(
                    """
                    DELETE FROM handoff_times
                          WHERE from_parent_id IS NOT NULL
                            AND to_parent_id IS NOT NULL
                            AND from_parent_id = to_parent_id
                    """
                )
                print(f"✅ Deleted {cur.rowcount} row(s).")

            # 3. Ensure a CHECK constraint exists to prevent future bad inserts
            print("\n🔒 Ensuring CHECK constraint exists…")
            constraint_name = "chk_handoff_parent_ids_differ"
            cur.execute(
                """
                SELECT 1
                  FROM information_schema.table_constraints
                 WHERE table_name = 'handoff_times'
                   AND constraint_type = 'CHECK'
                   AND constraint_name = %s
                """,
                (constraint_name,),
            )
            exists = cur.fetchone() is not None

            if exists:
                print("✅ Constraint already present.")
            else:
                print("➕ Adding CHECK constraint to enforce parent difference…")
                cur.execute(
                    sql.SQL(
                        """
                        ALTER TABLE handoff_times
                        ADD CONSTRAINT {constraint_name}
                        CHECK (
                            -- either one of the IDs is NULL OR they are different
                            (from_parent_id IS NULL)
                            OR (to_parent_id IS NULL)
                            OR (from_parent_id <> to_parent_id)
                        )
                        """
                    ).format(constraint_name=sql.Identifier(constraint_name))
                )
                print("✅ Constraint added.")

            # Commit all changes
            conn.commit()
            print("\n🎉 Cleanup completed successfully!")

    except Exception as exc:
        conn.rollback()
        print(f"❌ Error occurred – rolled back the transaction: {exc}")
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main() 