#!/usr/bin/env python3
"""
Test script to verify the custody API response format
"""

import requests
import json
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configuration
BASE_URL = "https://calndr.club/api"
USERNAME = os.getenv("TEST_USER_EMAIL", "")  # You'll need to provide this
PASSWORD = os.getenv("TEST_USER_PASSWORD", "")  # You'll need to provide this

def test_custody_api():
    """Test the custody API endpoints"""
    
    if not USERNAME or not PASSWORD:
        print("❌ Please set TEST_USER_EMAIL and TEST_USER_PASSWORD environment variables")
        return
    
    # Login to get token
    print("🔐 Logging in...")
    login_data = {
        "username": USERNAME,
        "password": PASSWORD
    }
    
    login_response = requests.post(
        f"{BASE_URL}/auth/token",
        data=login_data,
        headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    
    if login_response.status_code != 200:
        print(f"❌ Login failed: {login_response.status_code} - {login_response.text}")
        return
    
    token = login_response.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    
    print("✅ Login successful")
    
    # Test custodians endpoint
    print("\n📋 Testing custodians endpoint...")
    custodians_response = requests.get(f"{BASE_URL}/family/custodians", headers=headers)
    
    if custodians_response.status_code == 200:
        print(f"✅ Custodians response: {json.dumps(custodians_response.json(), indent=2)}")
    else:
        print(f"❌ Custodians failed: {custodians_response.status_code} - {custodians_response.text}")
        return
    
    # Test custody records endpoint
    print("\n📅 Testing custody records endpoint for 2025/6...")
    custody_response = requests.get(f"{BASE_URL}/custody/2025/6", headers=headers)
    
    if custody_response.status_code == 200:
        custody_data = custody_response.json()
        print(f"✅ Custody response type: {type(custody_data)}")
        print(f"✅ Number of records: {len(custody_data) if isinstance(custody_data, list) else 'Not a list'}")
        print(f"✅ Sample custody record: {json.dumps(custody_data[0] if custody_data else 'No records', indent=2)}")
        
        # Validate the structure
        if isinstance(custody_data, list) and custody_data:
            sample = custody_data[0]
            required_fields = ['id', 'event_date', 'content', 'position', 'custodian_id', 'handoff_day', 'handoff_time', 'handoff_location']
            missing_fields = [field for field in required_fields if field not in sample]
            
            if missing_fields:
                print(f"❌ Missing fields: {missing_fields}")
            else:
                print("✅ All required fields present")
                
            # Check data types
            print(f"📊 Field types:")
            for field, value in sample.items():
                print(f"  {field}: {type(value).__name__} = {value}")
        else:
            print("❌ Response is not a list or is empty")
            
    else:
        print(f"❌ Custody records failed: {custody_response.status_code} - {custody_response.text}")

if __name__ == "__main__":
    test_custody_api()