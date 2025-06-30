#!/bin/bash

# Exit on error
set -e

# Create and activate virtual environment for Python
if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv venv
fi
source venv/bin/activate

# Install backend dependencies
echo "Installing backend dependencies..."
pip install -r requirements.txt

# Install frontend dependencies
echo "Installing frontend dependencies..."
cd frontend
# Clean install to avoid issues with previous dependencies
rm -rf node_modules
npm install

# Build frontend
echo "Building frontend..."
npm run build -- --stats-error-details
cd ..

# Run the application
echo "Starting application on http://localhost:3000"
uvicorn app:app --port 3000 