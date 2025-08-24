#!/bin/bash

# Deployment script for enrollment codes migration
# This should be run on the server where the backend is deployed

echo "🚀 Starting enrollment codes migration deployment..."

# Check if we're in the right directory
if [ ! -f "migrate_enrollment_codes.py" ]; then
    echo "❌ Migration script not found. Make sure you're in the correct directory."
    exit 1
fi

# Activate virtual environment if it exists
if [ -d "venv" ]; then
    echo "📦 Activating virtual environment..."
    source v/bin/activate
elif [ -d "../v" ]; then
    echo "📦 Activating virtual environment..."
    source ../v/bin/activate
fi

# Install dependencies if needed
echo "📦 Installing/updating dependencies..."
pip install -r backend/backend/requirements.txt

# Run the migration
echo "🗄️ Running enrollment codes migration..."
python3 migrate_enrollment_codes.py

# Check if migration was successful
if [ $? -eq 0 ]; then
    echo "✅ Enrollment codes migration completed successfully!"
    echo "🎉 The enrollment code system is now ready to use!"
else
    echo "❌ Migration failed. Please check the error messages above."
    exit 1
fi

echo "📋 Migration Summary:"
echo "  - Created enrollment_codes table"
echo "  - Added indexes for performance"
echo "  - Created update trigger"
echo "  - Ready for enrollment code generation"
