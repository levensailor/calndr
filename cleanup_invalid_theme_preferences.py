#!/usr/bin/env python3
"""
Cleanup script for invalid theme preferences in user_preferences table.

This script identifies and fixes user preferences that reference themes
that no longer exist in the themes table, which would cause foreign key
constraint violations.
"""

import asyncio
import asyncpg
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "calndr")

DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

async def cleanup_invalid_theme_preferences():
    """
    Clean up user preferences that reference non-existent themes.
    """
    print("🔧 Starting cleanup of invalid theme preferences...")
    
    conn = await asyncpg.connect(DATABASE_URL)
    
    try:
        # Find user preferences with invalid theme references
        invalid_prefs_query = """
        SELECT up.id, up.user_id, up.selected_theme_id, u.email
        FROM user_preferences up
        JOIN users u ON up.user_id = u.id
        LEFT JOIN themes t ON up.selected_theme_id = t.id
        WHERE up.selected_theme_id IS NOT NULL 
        AND t.id IS NULL
        """
        
        invalid_prefs = await conn.fetch(invalid_prefs_query)
        
        if not invalid_prefs:
            print("✅ No invalid theme preferences found!")
            return
        
        print(f"🔍 Found {len(invalid_prefs)} user preferences with invalid theme references:")
        
        for pref in invalid_prefs:
            print(f"  • User {pref['email']} (ID: {pref['user_id']}) references non-existent theme {pref['selected_theme_id']}")
        
        # Get the default theme ID (if any public themes exist)
        default_theme_query = """
        SELECT id FROM themes 
        WHERE is_public = true 
        ORDER BY created_at ASC 
        LIMIT 1
        """
        
        default_theme = await conn.fetchrow(default_theme_query)
        
        if default_theme:
            print(f"🎨 Using default theme ID: {default_theme['id']}")
            
            # Update invalid preferences to use default theme
            update_query = """
            UPDATE user_preferences 
            SET selected_theme_id = $1, updated_at = NOW()
            WHERE selected_theme_id IS NOT NULL 
            AND selected_theme_id NOT IN (SELECT id FROM themes)
            """
            
            result = await conn.execute(update_query, default_theme['id'])
            affected_rows = int(result.split()[-1])  # Extract number from "UPDATE N"
            print(f"✅ Updated {affected_rows} user preferences to use default theme")
            
        else:
            print("⚠️ No public themes found, clearing invalid theme preferences...")
            
            # Clear invalid theme preferences
            clear_query = """
            UPDATE user_preferences 
            SET selected_theme_id = NULL, updated_at = NOW()
            WHERE selected_theme_id IS NOT NULL 
            AND selected_theme_id NOT IN (SELECT id FROM themes)
            """
            
            result = await conn.execute(clear_query)
            affected_rows = int(result.split()[-1])  # Extract number from "UPDATE N"
            print(f"✅ Cleared {affected_rows} invalid theme preferences")
        
        print("🎉 Cleanup completed successfully!")
        
    except Exception as e:
        print(f"❌ Error during cleanup: {e}")
        raise
    
    finally:
        await conn.close()

async def verify_cleanup():
    """
    Verify that no invalid theme preferences remain.
    """
    print("\n🔍 Verifying cleanup...")
    
    conn = await asyncpg.connect(DATABASE_URL)
    
    try:
        # Check for remaining invalid references
        check_query = """
        SELECT COUNT(*) as invalid_count
        FROM user_preferences up
        LEFT JOIN themes t ON up.selected_theme_id = t.id
        WHERE up.selected_theme_id IS NOT NULL 
        AND t.id IS NULL
        """
        
        result = await conn.fetchrow(check_query)
        invalid_count = result['invalid_count']
        
        if invalid_count == 0:
            print("✅ Verification passed: No invalid theme preferences remain")
        else:
            print(f"❌ Verification failed: {invalid_count} invalid preferences still exist")
            
        # Show summary of current preferences
        summary_query = """
        SELECT 
            CASE 
                WHEN up.selected_theme_id IS NULL THEN 'No theme selected'
                ELSE COALESCE(t.name, 'Invalid theme reference')
            END as theme_status,
            COUNT(*) as user_count
        FROM user_preferences up
        LEFT JOIN themes t ON up.selected_theme_id = t.id
        GROUP BY 
            CASE 
                WHEN up.selected_theme_id IS NULL THEN 'No theme selected'
                ELSE COALESCE(t.name, 'Invalid theme reference')
            END
        ORDER BY user_count DESC
        """
        
        summary = await conn.fetch(summary_query)
        
        print("\n📊 Current theme preference summary:")
        for row in summary:
            print(f"  • {row['theme_status']}: {row['user_count']} users")
            
    finally:
        await conn.close()

async def main():
    """
    Main function to run the cleanup and verification.
    """
    print("🚀 Starting theme preference cleanup script...")
    print(f"🔗 Connecting to database: {DB_HOST}:{DB_PORT}/{DB_NAME}")
    
    try:
        await cleanup_invalid_theme_preferences()
        await verify_cleanup()
        print("\n🎉 All done! Theme preferences have been cleaned up.")
        
    except Exception as e:
        print(f"💥 Script failed with error: {e}")
        exit(1)

if __name__ == "__main__":
    asyncio.run(main()) 