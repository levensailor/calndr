-- Cleanup script for test users and related data
-- This script will remove test users and all their associated data

-- Start a transaction to ensure all operations succeed or none do
BEGIN;

-- Get family_ids for the test users first
WITH test_families AS (
    SELECT DISTINCT family_id 
    FROM users 
    WHERE email IN ('jondaly315@gmail.com', 'dalypam19@gmail.com')
)

-- Delete records from dependent tables first
DELETE FROM schedule_templates 
WHERE family_id IN (SELECT family_id FROM test_families);

DELETE FROM custody 
WHERE family_id IN (SELECT family_id FROM test_families);

DELETE FROM children 
WHERE family_id IN (SELECT family_id FROM test_families);

DELETE FROM enrollment_codes 
WHERE family_id IN (SELECT family_id FROM test_families);

-- Delete users (must be done before families due to foreign key constraint)
DELETE FROM users 
WHERE email IN ('jondaly315@gmail.com', 'dalypam19@gmail.com');

-- Finally delete the families
DELETE FROM families 
WHERE id IN (SELECT family_id FROM test_families);

-- Commit the transaction
COMMIT;

-- Verify deletions (uncomment to check counts)
/*
SELECT 'schedule_templates' as table_name, COUNT(*) as remaining_count 
FROM schedule_templates 
WHERE family_id IN (SELECT family_id FROM users WHERE email IN ('jondaly315@gmail.com', 'dalypam19@gmail.com'))
UNION ALL
SELECT 'custody' as table_name, COUNT(*) as remaining_count 
FROM custody 
WHERE family_id IN (SELECT family_id FROM users WHERE email IN ('jondaly315@gmail.com', 'dalypam19@gmail.com'))
UNION ALL
SELECT 'children' as table_name, COUNT(*) as remaining_count 
FROM children 
WHERE family_id IN (SELECT family_id FROM users WHERE email IN ('jondaly315@gmail.com', 'dalypam19@gmail.com'))
UNION ALL
SELECT 'enrollment_codes' as table_name, COUNT(*) as remaining_count 
FROM enrollment_codes 
WHERE family_id IN (SELECT family_id FROM users WHERE email IN ('jondaly315@gmail.com', 'dalypam19@gmail.com'))
UNION ALL
SELECT 'users' as table_name, COUNT(*) as remaining_count 
FROM users 
WHERE email IN ('jondaly315@gmail.com', 'dalypam19@gmail.com')
UNION ALL
SELECT 'families' as table_name, COUNT(*) as remaining_count 
FROM families 
WHERE id IN (SELECT family_id FROM users WHERE email IN ('jondaly315@gmail.com', 'dalypam19@gmail.com'));
*/
