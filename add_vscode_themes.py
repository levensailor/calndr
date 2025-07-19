#!/usr/bin/env python3
"""
Script to add 5 new VS Code inspired themes to the database
"""

import os
import asyncio
import databases
import sqlalchemy
import uuid
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Database configuration
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME")

DATABASE_URL = f"postgresql+asyncpg://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
database = databases.Database(DATABASE_URL)

# VS Code inspired themes
VSCODE_THEMES = [
    {
        "name": "One Dark Pro",
        "mainBackgroundColor": "#282c34",
        "secondaryBackgroundColor": "#21252b",
        "textColor": "#abb2bf",
        "headerTextColor": "#e6ffff",
        "iconColor": "#56b6c2",
        "iconActiveColor": "#61dafb",
        "accentColor": "#c678dd",
        "parentOneColor": "#96CBFC",  # Jeff - blue
        "parentTwoColor": "#FFC2D9",  # Deanna - pink
        "is_public": True
    },
    {
        "name": "Monokai Pro",
        "mainBackgroundColor": "#2d2a2e",
        "secondaryBackgroundColor": "#221f22",
        "textColor": "#fcfcfa",
        "headerTextColor": "#ffffff",
        "iconColor": "#a9dc76",
        "iconActiveColor": "#fc9867",
        "accentColor": "#ab9df2",
        "parentOneColor": "#96CBFC",  # Jeff - blue
        "parentTwoColor": "#FFC2D9",  # Deanna - pink
        "is_public": True
    },
    {
        "name": "GitHub Dark",
        "mainBackgroundColor": "#0d1117",
        "secondaryBackgroundColor": "#161b22",
        "textColor": "#c9d1d9",
        "headerTextColor": "#f0f6fc",
        "iconColor": "#7c3aed",
        "iconActiveColor": "#58a6ff",
        "accentColor": "#f85149",
        "parentOneColor": "#96CBFC",  # Jeff - blue
        "parentTwoColor": "#FFC2D9",  # Deanna - pink
        "is_public": True
    },
    {
        "name": "Atom One Dark",
        "mainBackgroundColor": "#1e2127",
        "secondaryBackgroundColor": "#181a1f",
        "textColor": "#9ca3af",
        "headerTextColor": "#e6e6e6",
        "iconColor": "#56b6c2",
        "iconActiveColor": "#e06c75",
        "accentColor": "#d19a66",
        "parentOneColor": "#96CBFC",  # Jeff - blue
        "parentTwoColor": "#FFC2D9",  # Deanna - pink
        "is_public": True
    },
    {
        "name": "Solarized Dark",
        "mainBackgroundColor": "#002b36",
        "secondaryBackgroundColor": "#073642",
        "textColor": "#839496",
        "headerTextColor": "#fdf6e3",
        "iconColor": "#268bd2",
        "iconActiveColor": "#2aa198",
        "accentColor": "#dc322f",
        "parentOneColor": "#96CBFC",  # Jeff - blue
        "parentTwoColor": "#FFC2D9",  # Deanna - pink
        "is_public": True
    }
]

async def add_vscode_themes():
    """Add VS Code inspired themes to the database"""
    
    print("Starting VS Code themes addition...")
    print(f"Adding {len(VSCODE_THEMES)} themes...")
    
    try:
        await database.connect()
        
        # Check if themes table exists
        table_exists_query = """
        SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'themes'
        );
        """
        table_exists = await database.fetch_val(table_exists_query)
        
        if not table_exists:
            print("❌ Themes table does not exist. Please run database migrations first.")
            return
        
        # Add each theme
        for theme_data in VSCODE_THEMES:
            theme_id = uuid.uuid4()
            
            # Check if theme with same name already exists
            existing_theme_query = """
            SELECT id FROM themes WHERE name = :name
            """
            existing_theme = await database.fetch_one(existing_theme_query, {"name": theme_data["name"]})
            
            if existing_theme:
                print(f"⚠️  Theme '{theme_data['name']}' already exists, skipping...")
                continue
            
            # Insert the new theme
            insert_query = """
            INSERT INTO themes (
                id, name, "mainBackgroundColor", "secondaryBackgroundColor", 
                "textColor", "headerTextColor", "iconColor", "iconActiveColor", 
                "accentColor", "parentOneColor", "parentTwoColor", 
                is_public, created_at, updated_at
            ) VALUES (
                :id, :name, :mainBackgroundColor, :secondaryBackgroundColor,
                :textColor, :headerTextColor, :iconColor, :iconActiveColor,
                :accentColor, :parentOneColor, :parentTwoColor,
                :is_public, :created_at, :updated_at
            )
            """
            
            values = {
                "id": theme_id,
                "name": theme_data["name"],
                "mainBackgroundColor": theme_data["mainBackgroundColor"],
                "secondaryBackgroundColor": theme_data["secondaryBackgroundColor"],
                "textColor": theme_data["textColor"],
                "headerTextColor": theme_data["headerTextColor"],
                "iconColor": theme_data["iconColor"],
                "iconActiveColor": theme_data["iconActiveColor"],
                "accentColor": theme_data["accentColor"],
                "parentOneColor": theme_data["parentOneColor"],
                "parentTwoColor": theme_data["parentTwoColor"],
                "is_public": theme_data["is_public"],
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            }
            
            await database.execute(insert_query, values)
            print(f"✅ Added theme: {theme_data['name']} (ID: {theme_id})")
        
        print(f"\n🎨 Successfully added VS Code inspired themes!")
        
        # Display summary of all themes
        themes_query = "SELECT name, is_public FROM themes ORDER BY created_at DESC"
        all_themes = await database.fetch_all(themes_query)
        
        print(f"\n📊 Total themes in database: {len(all_themes)}")
        print("Public themes:")
        for theme in all_themes:
            if theme["is_public"]:
                print(f"  • {theme['name']}")
        
    except Exception as e:
        print(f"❌ Error adding themes: {e}")
        raise
    finally:
        if database.is_connected:
            await database.disconnect()
            print("Database connection closed.")

async def main():
    """Main function"""
    await add_vscode_themes()

if __name__ == "__main__":
    asyncio.run(main()) 