-- This script adds timestamp columns (created_at and updated_at) to the families table.

-- 1. Add the created_at column
-- This column will store the timestamp when a record is first created.
-- It defaults to the current time and cannot be null.
ALTER TABLE families
ADD COLUMN created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- 2. Add the updated_at column
-- This column will store the timestamp of the last update to a record.
-- It also defaults to the current time and cannot be null.
ALTER TABLE families
ADD COLUMN updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- 3. Backfill timestamps for existing records
-- For all records that existed before this change, this sets their
-- created_at and updated_at times to when this script is run.
UPDATE families
SET
    created_at = CURRENT_TIMESTAMP,
    updated_at = CURRENT_TIMESTAMP
WHERE created_at IS NULL;

-- Note on automatic updates for the 'updated_at' column:
-- To make the 'updated_at' column automatically update whenever a row is changed,
-- you need to add a trigger or use a special column definition. The method
-- varies depending on your database system.

-- For PostgreSQL, you would create a trigger function like this:
/*
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = now();
   RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_families_updated_at
BEFORE UPDATE ON families
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
*/

-- For MySQL, you can alter the column directly to add the auto-update behavior:
/*
ALTER TABLE families
MODIFY COLUMN updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;
*/
