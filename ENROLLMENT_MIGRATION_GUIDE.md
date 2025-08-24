# Enrollment Codes Migration Guide

The enrollment codes system requires a database table to be created. Due to Python dependency compilation issues on some systems, here are multiple ways to run the migration:

## 🎯 Quick Solutions (Choose One)

### Option 1: Direct SQL (Recommended) ⭐
```bash
# If you have psql installed
./run_sql_migration.sh
```

### Option 2: Manual SQL Execution
```bash
# Connect to your database and run the SQL file directly
psql -h your_host -U your_user -d your_database -f enrollment_codes_migration.sql
```

### Option 3: Copy-Paste SQL
Open `enrollment_codes_migration.sql` and copy-paste the SQL commands into your database management tool (pgAdmin, DBeaver, etc.)

## 🔧 Troubleshooting Python Dependencies

If you want to use the Python migration scripts but are getting "databases not found" or compilation errors:

### For Local Development:
```bash
# Try installing with pre-compiled wheels
pip install --only-binary=all databases[postgresql] asyncpg

# Or use conda instead of pip
conda install -c conda-forge databases asyncpg
```

### For Server Deployment:
```bash
# On Ubuntu/Debian
sudo apt-get install python3-dev postgresql-dev

# On CentOS/RHEL
sudo yum install python3-devel postgresql-devel

# Then install Python packages
pip install databases[postgresql] asyncpg
```

## 📋 What the Migration Creates

The migration creates:
- `enrollment_codes` table with proper constraints
- Performance indexes for fast lookups
- Automatic timestamp update triggers
- Foreign key relationships to users and families tables

## ✅ Verification

After running the migration, verify it worked:

```sql
-- Check if table exists
SELECT table_name FROM information_schema.tables 
WHERE table_name = 'enrollment_codes';

-- Check table structure
\d enrollment_codes
```

## 🚀 Next Steps

Once the migration is complete:
1. The enrollment code API endpoints will work
2. iOS app can generate codes immediately
3. Family linking will be functional

## 🆘 Still Having Issues?

If none of these options work:
1. Check your database connection credentials
2. Ensure you have proper database permissions
3. Try running the migration on the server where your backend is deployed
4. Contact your database administrator for help with table creation
