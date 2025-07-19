#!/usr/bin/env python3
"""
Script to add VS Code-inspired light themes to the themes table.
Based on:
1. Cute Theme - https://vscodethemes.com/e/webfreak.cute-theme/cute
2. Slack Theme Aubergine - https://vscodethemes.com/e/felipe-mendes.slack-theme/slack-theme-aubergine  
3. Material Theme Lighter High Contrast - https://vscodethemes.com/e/Equinusocio.vsc-material-theme/material-theme-lighter-high-contrast
"""

import asyncio
import asyncpg
import uuid
from datetime import datetime
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Database connection settings
DB_USER = os.getenv("DB_USER", "")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "calndr")

# VS Code-inspired theme definitions
VSCODE_THEMES = [
    {
        "name": "Cute Theme",
        "mainBackgroundColor": "#FAF8FF",  # Very light purple-pink background
        "secondaryBackgroundColor": "#F2EFFF",  # Slightly darker purple background
        "textColor": "#2D1B69",  # Deep purple text
        "headerTextColor": "#2D1B69",  # Deep purple headers
        "iconColor": "#6B46C1",  # Medium purple icons
        "iconActiveColor": "#8B5CF6",  # Bright purple active icons
        "accentColor": "#EC4899",  # Pink accent color
        "parentOneColor": "#FBBF24",  # Warm yellow for parent 1
        "parentTwoColor": "#F472B6",  # Pink for parent 2
        "is_public": True
    },
    {
        "name": "Slack Aubergine",
        "mainBackgroundColor": "#FEFEFE",  # Almost pure white background
        "secondaryBackgroundColor": "#F8F6F6",  # Very light gray
        "textColor": "#4A154B",  # Deep aubergine text
        "headerTextColor": "#4A154B",  # Deep aubergine headers
        "iconColor": "#611F69",  # Purple icons
        "iconActiveColor": "#E01E5A",  # Slack red active
        "accentColor": "#E01E5A",  # Slack red accent
        "parentOneColor": "#36C5F0",  # Slack blue for parent 1
        "parentTwoColor": "#ECB22E",  # Slack yellow for parent 2
        "is_public": True
    },
    {
        "name": "Material Lighter",
        "mainBackgroundColor": "#FAFAFA",  # Material light gray background
        "secondaryBackgroundColor": "#F5F5F5",  # Slightly darker gray
        "textColor": "#212121",  # Material dark gray text
        "headerTextColor": "#212121",  # Material dark gray headers
        "iconColor": "#616161",  # Medium gray icons
        "iconActiveColor": "#2196F3",  # Material blue active
        "accentColor": "#FF9800",  # Material orange accent
        "parentOneColor": "#4CAF50",  # Material green for parent 1
        "parentTwoColor": "#E91E63",  # Material pink for parent 2
        "is_public": True
    }
]

async def create_database_connection():
    """Create a connection to the PostgreSQL database."""
    try:
        connection = await asyncpg.connect(
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
            host=DB_HOST,
            port=DB_PORT
        )
        return connection
    except Exception as e:
        print(f"❌ Failed to connect to database: {e}")
        return None

async def theme_exists(connection, theme_name):
    """Check if a theme with the given name already exists."""
    query = "SELECT COUNT(*) FROM themes WHERE name = $1"
    result = await connection.fetchval(query, theme_name)
    return result > 0

async def insert_theme(connection, theme_data):
    """Insert a theme into the themes table."""
    query = """
    INSERT INTO themes (
        id, name, "mainBackgroundColor", "secondaryBackgroundColor",
        "textColor", "headerTextColor", "iconColor", "iconActiveColor",
        "accentColor", "parentOneColor", "parentTwoColor", 
        is_public, created_at, updated_at
    ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14
    )
    """
    
    theme_id = uuid.uuid4()
    current_time = datetime.utcnow()
    
    await connection.execute(
        query,
        theme_id,
        theme_data["name"],
        theme_data["mainBackgroundColor"],
        theme_data["secondaryBackgroundColor"],
        theme_data["textColor"],
        theme_data["headerTextColor"],
        theme_data["iconColor"],
        theme_data["iconActiveColor"],
        theme_data["accentColor"],
        theme_data["parentOneColor"],
        theme_data["parentTwoColor"],
        theme_data["is_public"],
        current_time,
        current_time
    )
    
    return theme_id

async def main():
    """Main function to add VS Code-inspired themes."""
    print("🎨 Adding VS Code-inspired light themes to the database...")
    
    # Create database connection
    connection = await create_database_connection()
    if not connection:
        return
    
    try:
        added_count = 0
        skipped_count = 0
        
        for theme_data in VSCODE_THEMES:
            theme_name = theme_data["name"]
            
            # Check if theme already exists
            if await theme_exists(connection, theme_name):
                print(f"⚠️  Theme '{theme_name}' already exists. Skipping...")
                skipped_count += 1
                continue
            
            # Insert the theme
            theme_id = await insert_theme(connection, theme_data)
            print(f"✅ Added theme '{theme_name}' with ID: {theme_id}")
            added_count += 1
        
        print(f"\n🎉 Theme addition complete!")
        print(f"   • Added: {added_count} themes")
        print(f"   • Skipped: {skipped_count} themes (already existed)")
        
    except Exception as e:
        print(f"❌ Error adding themes: {e}")
    finally:
        await connection.close()

if __name__ == "__main__":
    # Check if required environment variables are set
    if not all([DB_USER, DB_PASSWORD, DB_HOST, DB_NAME]):
        print("❌ Missing required environment variables:")
        print("   Please ensure DB_USER, DB_PASSWORD, DB_HOST, and DB_NAME are set")
        print("   You can create a .env file with these values")
        exit(1)
    
    asyncio.run(main()) 