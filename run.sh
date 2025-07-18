#!/bin/bash

# Exit on error
set -e

# Navigate to backend directory
cd backend

# Create and activate virtual environment for Python
if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv venv
fi
source venv/bin/activate

# Install backend dependencies
echo "Installing backend dependencies..."
pip install -r requirements.txt

# Run the application
echo "Starting application on http://localhost:3000"
uvicorn main:app --port 3000 --reload 