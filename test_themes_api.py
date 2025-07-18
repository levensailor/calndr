#!/usr/bin/env python3
"""
Simple test script to verify themes CRUD operations work correctly.
"""

import requests
import json
import uuid
from datetime import datetime

# Configuration
BASE_URL = "https://calndr.club/api/v1"
# Replace with a valid JWT token for testing
AUTH_TOKEN = "YOUR_JWT_TOKEN_HERE"

headers = {
    "Authorization": f"Bearer {AUTH_TOKEN}",
    "Content-Type": "application/json"
}

def test_get_themes():
    """Test fetching themes."""
    print("Testing GET /themes...")
    response = requests.get(f"{BASE_URL}/themes", headers=headers)
    print(f"Status Code: {response.status_code}")
    if response.status_code == 200:
        themes = response.json()
        print(f"Found {len(themes)} themes")
        for theme in themes:
            print(f"  - {theme['name']} (ID: {theme['id']})")
        return themes
    else:
        print(f"Error: {response.text}")
        return []

def test_create_theme():
    """Test creating a new theme."""
    print("\nTesting POST /themes...")
    
    theme_data = {
        "name": "Test Theme " + str(datetime.now().strftime("%H%M%S")),
        "mainBackgroundColor": "#FFFFFF",
        "secondaryBackgroundColor": "#F2F2F7",
        "textColor": "#000000",
        "headerTextColor": "#000000",
        "iconColor": "#000000",
        "iconActiveColor": "#007AFF",
        "accentColor": "#007AFF",
        "parentOneColor": "#96CBFC",
        "parentTwoColor": "#FFC2D9",
        "is_public": False
    }
    
    response = requests.post(f"{BASE_URL}/themes", headers=headers, json=theme_data)
    print(f"Status Code: {response.status_code}")
    
    if response.status_code == 200:
        theme = response.json()
        print(f"Created theme: {theme['name']} (ID: {theme['id']})")
        return theme
    else:
        print(f"Error: {response.text}")
        return None

def test_update_theme(theme_id):
    """Test updating a theme."""
    print(f"\nTesting PUT /themes/{theme_id}...")
    
    update_data = {
        "name": "Updated Test Theme",
        "accentColor": "#FF0000"  # Change accent color to red
    }
    
    response = requests.put(f"{BASE_URL}/themes/{theme_id}", headers=headers, json=update_data)
    print(f"Status Code: {response.status_code}")
    
    if response.status_code == 200:
        theme = response.json()
        print(f"Updated theme: {theme['name']} - Accent Color: {theme['accentColor']}")
        return theme
    else:
        print(f"Error: {response.text}")
        return None

def test_set_theme_preference(theme_id):
    """Test setting theme preference."""
    print(f"\nTesting PUT /themes/set-preference/{theme_id}...")
    
    response = requests.put(f"{BASE_URL}/themes/set-preference/{theme_id}", headers=headers)
    print(f"Status Code: {response.status_code}")
    
    if response.status_code == 204:
        print("Successfully set theme preference")
        return True
    else:
        print(f"Error: {response.text}")
        return False

def test_delete_theme(theme_id):
    """Test deleting a theme."""
    print(f"\nTesting DELETE /themes/{theme_id}...")
    
    response = requests.delete(f"{BASE_URL}/themes/{theme_id}", headers=headers)
    print(f"Status Code: {response.status_code}")
    
    if response.status_code == 204:
        print("Successfully deleted theme")
        return True
    else:
        print(f"Error: {response.text}")
        return False

def main():
    """Run all theme tests."""
    print("=== Theme API Tests ===")
    
    # Make sure to replace the AUTH_TOKEN above with a valid token
    if AUTH_TOKEN == "YOUR_JWT_TOKEN_HERE":
        print("❌ Please set a valid JWT token in the AUTH_TOKEN variable")
        return
    
    # Test getting themes
    initial_themes = test_get_themes()
    
    # Test creating a theme
    new_theme = test_create_theme()
    if new_theme:
        theme_id = new_theme['id']
        
        # Test updating the theme
        test_update_theme(theme_id)
        
        # Test setting theme preference
        test_set_theme_preference(theme_id)
        
        # Test deleting the theme
        test_delete_theme(theme_id)
    
    print("\n=== Tests Complete ===")

if __name__ == "__main__":
    main() 