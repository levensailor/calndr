#!/usr/bin/env python3

import os
import psycopg2
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Database connection details
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")

def create_handoff_times_table():
    """Create the handoff_times table with appropriate indexes and constraints."""
    
    conn = None
    try:
        # Connect to PostgreSQL
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        
        # Create a cursor
        cur = conn.cursor()
        
        print("Creating handoff_times table...")
        
        # Create the handoff_times table
        create_table_sql = """
        CREATE TABLE IF NOT EXISTS handoff_times (
            id SERIAL PRIMARY KEY,
            family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
            date DATE NOT NULL,
            time TIME NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(family_id, date)
        );
        """
        
        cur.execute(create_table_sql)
        
        # Create indexes for better performance
        create_indexes_sql = [
            "CREATE INDEX IF NOT EXISTS idx_handoff_times_family_id ON handoff_times(family_id);",
            "CREATE INDEX IF NOT EXISTS idx_handoff_times_date ON handoff_times(date);",
            "CREATE INDEX IF NOT EXISTS idx_handoff_times_family_date ON handoff_times(family_id, date);"
        ]
        
        for index_sql in create_indexes_sql:
            cur.execute(index_sql)
            print(f"✅ Created index")
        
        # Commit the changes
        conn.commit()
        print("✅ Successfully created handoff_times table with indexes!")
        
        # Verify the table was created
        cur.execute("""
            SELECT column_name, data_type, is_nullable, column_default 
            FROM information_schema.columns 
            WHERE table_name = 'handoff_times' 
            ORDER BY ordinal_position;
        """)
        
        columns = cur.fetchall()
        print("\n📋 Table structure:")
        for column in columns:
            print(f"  - {column[0]}: {column[1]} (nullable: {column[2]}, default: {column[3]})")
        
        # Check foreign key constraints
        cur.execute("""
            SELECT constraint_name, table_name, column_name, foreign_table_name, foreign_column_name
            FROM information_schema.key_column_usage kcu
            JOIN information_schema.referential_constraints rc ON kcu.constraint_name = rc.constraint_name
            JOIN information_schema.key_column_usage fkcu ON rc.unique_constraint_name = fkcu.constraint_name
            WHERE kcu.table_name = 'handoff_times';
        """)
        
        constraints = cur.fetchall()
        print("\n🔗 Foreign key constraints:")
        for constraint in constraints:
            print(f"  - {constraint[0]}: {constraint[2]} -> {constraint[3]}.{constraint[4]}")
        
        cur.close()
        
    except psycopg2.Error as e:
        print(f"❌ Database error: {e}")
        if conn:
            conn.rollback()
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    print("🚀 Starting handoff_times table migration...")
    create_handoff_times_table()
    print("✅ Migration completed!") 