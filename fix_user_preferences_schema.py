#!/usr/bin/env python3
"""
Migration script to fix user_preferences table schema.
This script will:
1. Add the new selected_theme_id column
2. Migrate existing data from theme names to theme IDs  
3. Remove the old selected_theme column
4. Add proper foreign key constraints
"""

import os
import sys
from sqlalchemy import create_engine, text, Column, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from dotenv import load_dotenv

# Add the backend directory to the Python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), 'backend')))

from core.config import settings

def main():
    """Main migration function."""
    print("=== User Preferences Schema Migration ===")
    print("Fixing selected_theme column to use UUIDs instead of strings\n")
    
    # Load environment variables
    load_dotenv()
    
    # Check database configuration
    if not settings.DATABASE_URL:
        print("❌ DATABASE_URL not configured. Please check your .env file.")
        return
    
    # Use synchronous connection
    sync_database_url = settings.DATABASE_URL.replace("postgresql+asyncpg", "postgresql")
    engine = create_engine(sync_database_url)
    
    try:
        with engine.connect() as connection:
            # Start transaction
            trans = connection.begin()
            
            try:
                print("Step 1: Checking current table structure...")
                
                # Check if selected_theme_id already exists
                result = connection.execute(text("""
                    SELECT column_name 
                    FROM information_schema.columns 
                    WHERE table_name = 'user_preferences' 
                    AND column_name = 'selected_theme_id'
                """))
                
                if result.fetchone():
                    print("✅ selected_theme_id column already exists. Checking for data migration needs...")
                else:
                    print("Step 2: Adding selected_theme_id column...")
                    connection.execute(text("""
                        ALTER TABLE user_preferences 
                        ADD COLUMN selected_theme_id UUID
                    """))
                    print("✅ Added selected_theme_id column")
                
                print("Step 3: Migrating existing data...")
                
                # Get existing preferences with theme names
                result = connection.execute(text("""
                    SELECT id, user_id, selected_theme 
                    FROM user_preferences 
                    WHERE selected_theme IS NOT NULL 
                    AND (selected_theme_id IS NULL OR selected_theme_id::text = '')
                """))
                
                prefs_to_migrate = result.fetchall()
                print(f"Found {len(prefs_to_migrate)} preferences to migrate")
                
                migrated_count = 0
                for pref in prefs_to_migrate:
                    pref_id, user_id, theme_name = pref
                    
                    # Find theme ID by name
                    theme_result = connection.execute(text("""
                        SELECT id FROM themes WHERE name = :theme_name
                    """), {"theme_name": theme_name})
                    
                    theme_row = theme_result.fetchone()
                    if theme_row:
                        theme_id = theme_row[0]
                        
                        # Update the preference with the theme ID
                        connection.execute(text("""
                            UPDATE user_preferences 
                            SET selected_theme_id = :theme_id 
                            WHERE id = :pref_id
                        """), {"theme_id": theme_id, "pref_id": pref_id})
                        
                        migrated_count += 1
                        print(f"  ✅ Migrated user {user_id}: '{theme_name}' -> {theme_id}")
                    else:
                        print(f"  ⚠️  Theme '{theme_name}' not found for user {user_id}")
                
                print(f"✅ Migrated {migrated_count} preferences")
                
                print("Step 4: Adding foreign key constraint...")
                
                # Check if foreign key constraint already exists
                result = connection.execute(text("""
                    SELECT constraint_name 
                    FROM information_schema.table_constraints 
                    WHERE table_name = 'user_preferences' 
                    AND constraint_type = 'FOREIGN KEY'
                    AND constraint_name LIKE '%selected_theme_id%'
                """))
                
                if result.fetchone():
                    print("✅ Foreign key constraint already exists")
                else:
                    connection.execute(text("""
                        ALTER TABLE user_preferences 
                        ADD CONSTRAINT fk_user_preferences_theme 
                        FOREIGN KEY (selected_theme_id) REFERENCES themes(id)
                    """))
                    print("✅ Added foreign key constraint")
                
                print("Step 5: Checking if old column can be removed...")
                
                # Check if selected_theme column still exists
                result = connection.execute(text("""
                    SELECT column_name 
                    FROM information_schema.columns 
                    WHERE table_name = 'user_preferences' 
                    AND column_name = 'selected_theme'
                """))
                
                if result.fetchone():
                    print("Step 6: Removing old selected_theme column...")
                    connection.execute(text("""
                        ALTER TABLE user_preferences 
                        DROP COLUMN selected_theme
                    """))
                    print("✅ Removed old selected_theme column")
                else:
                    print("✅ Old selected_theme column already removed")
                
                # Commit transaction
                trans.commit()
                print("\n🎉 Migration completed successfully!")
                
            except Exception as e:
                trans.rollback()
                print(f"❌ Migration failed: {e}")
                raise
                
    except Exception as e:
        print(f"❌ Database connection error: {e}")
        return
    
    # Verify the migration
    print("\nStep 7: Verifying migration...")
    verify_migration()

def verify_migration():
    """Verify that the migration was successful."""
    sync_database_url = settings.DATABASE_URL.replace("postgresql+asyncpg", "postgresql")
    engine = create_engine(sync_database_url)
    
    try:
        with engine.connect() as connection:
            # Check table structure
            result = connection.execute(text("""
                SELECT column_name, data_type, is_nullable 
                FROM information_schema.columns 
                WHERE table_name = 'user_preferences' 
                ORDER BY ordinal_position
            """))
            
            columns = result.fetchall()
            print("📋 Current user_preferences table structure:")
            for col in columns:
                print(f"  - {col[0]} ({col[1]}) - Nullable: {col[2]}")
            
            # Check data integrity
            result = connection.execute(text("""
                SELECT COUNT(*) as total,
                       COUNT(selected_theme_id) as with_theme 
                FROM user_preferences
            """))
            
            counts = result.fetchone()
            print(f"\n📊 Data summary:")
            print(f"  - Total preferences: {counts[0]}")
            print(f"  - With theme ID: {counts[1]}")
            
            # Check foreign key constraints
            result = connection.execute(text("""
                SELECT constraint_name, table_name, column_name
                FROM information_schema.key_column_usage 
                WHERE table_name = 'user_preferences' 
                AND constraint_name LIKE '%theme%'
            """))
            
            constraints = result.fetchall()
            if constraints:
                print(f"\n🔗 Foreign key constraints:")
                for constraint in constraints:
                    print(f"  - {constraint[0]}")
            else:
                print(f"\n⚠️  No theme-related foreign key constraints found")
                
    except Exception as e:
        print(f"❌ Verification failed: {e}")

if __name__ == "__main__":
    main() 