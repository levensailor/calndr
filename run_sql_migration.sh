#!/bin/bash

# Simple SQL migration runner for enrollment_codes table
# This avoids Python dependency issues by running SQL directly

echo "🚀 Running enrollment_codes SQL migration..."

# Check if SQL file exists
if [ ! -f "enrollment_codes_migration.sql" ]; then
    echo "❌ SQL migration file not found: enrollment_codes_migration.sql"
    exit 1
fi

# Load environment variables if .env exists
if [ -f ".env" ]; then
    echo "📋 Loading environment variables from .env..."
    set -a  # automatically export all variables
    source .env
    set +a  # stop automatically exporting
fi

# Check if we have database credentials
if [ -z "$DB_HOST" ] || [ -z "$DB_USER" ] || [ -z "$DB_NAME" ]; then
    echo "❌ Missing database credentials. Please set:"
    echo "   DB_HOST, DB_USER, DB_PASSWORD, DB_NAME"
    echo ""
    echo "You can either:"
    echo "1. Set them as environment variables"
    echo "2. Add them to a .env file"
    echo "3. Run the SQL file manually with psql"
    exit 1
fi

# Set default port if not specified
DB_PORT=${DB_PORT:-5432}

echo "🔗 Connecting to database: $DB_HOST:$DB_PORT/$DB_NAME as $DB_USER"

# Run the SQL migration
if command -v psql &> /dev/null; then
    echo "🗄️ Running SQL migration with psql..."
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f enrollment_codes_migration.sql
    
    if [ $? -eq 0 ]; then
        echo "✅ Enrollment codes migration completed successfully!"
        echo "🎉 The enrollment code system is now ready to use!"
    else
        echo "❌ Migration failed. Please check the error messages above."
        exit 1
    fi
else
    echo "❌ psql command not found. Please install PostgreSQL client tools."
    echo ""
    echo "Alternative: Run the SQL manually:"
    echo "psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f enrollment_codes_migration.sql"
    exit 1
fi

echo ""
echo "📋 Migration Summary:"
echo "  - Created enrollment_codes table"
echo "  - Added indexes for performance"
echo "  - Created update trigger"
echo "  - Ready for enrollment code generation"
