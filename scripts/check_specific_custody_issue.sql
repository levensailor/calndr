-- Check the specific custody issue reported
-- Record custodian_id: '15b4bb32-2be0-4292-852e-ad761b4d182d'
-- Custodian one ID: 'f8a1de34-57ca-40ca-88e8-61de81d3907a'
-- Custodian two ID: '82bc693b-0b34-49c0-9fed-48864a3d808e'

-- First, check which family these users belong to
SELECT 
    u.id as user_id,
    u.first_name,
    u.last_name,
    u.email,
    u.family_id,
    f.name as family_name,
    u.created_at,
    u.status
FROM users u
LEFT JOIN families f ON f.id = u.family_id
WHERE u.id IN (
    'f8a1de34-57ca-40ca-88e8-61de81d3907a'::uuid,  -- Custodian one
    '82bc693b-0b34-49c0-9fed-48864a3d808e'::uuid   -- Custodian two
);

-- Check who the mystery custodian is
SELECT 
    u.id as user_id,
    u.first_name,
    u.last_name,
    u.email,
    u.family_id,
    f.name as family_name,
    u.created_at,
    u.status
FROM users u
LEFT JOIN families f ON f.id = u.family_id
WHERE u.id = '15b4bb32-2be0-4292-852e-ad761b4d182d'::uuid;

-- Check the custody record for 2025-12-31
SELECT 
    c.id,
    c.date,
    c.custodian_id,
    c.family_id,
    u.first_name as custodian_name,
    u.family_id as custodian_family_id,
    c.created_at,
    c.updated_at
FROM custody c
LEFT JOIN users u ON u.id = c.custodian_id
WHERE c.date = '2025-12-31'
AND (
    c.custodian_id = '15b4bb32-2be0-4292-852e-ad761b4d182d'::uuid
    OR c.family_id IN (
        SELECT family_id FROM users 
        WHERE id IN (
            'f8a1de34-57ca-40ca-88e8-61de81d3907a'::uuid,
            '82bc693b-0b34-49c0-9fed-48864a3d808e'::uuid
        )
    )
);

-- Get all family members for the affected family
WITH affected_family AS (
    SELECT DISTINCT family_id 
    FROM users 
    WHERE id IN (
        'f8a1de34-57ca-40ca-88e8-61de81d3907a'::uuid,
        '82bc693b-0b34-49c0-9fed-48864a3d808e'::uuid
    )
)
SELECT 
    u.id,
    u.first_name,
    u.last_name,
    u.email,
    u.status,
    u.created_at,
    'Valid Family Member' as member_status
FROM users u
WHERE u.family_id = (SELECT family_id FROM affected_family)
ORDER BY u.created_at;

-- Count how many custody records have this issue for this family
WITH affected_family AS (
    SELECT DISTINCT family_id 
    FROM users 
    WHERE id IN (
        'f8a1de34-57ca-40ca-88e8-61de81d3907a'::uuid,
        '82bc693b-0b34-49c0-9fed-48864a3d808e'::uuid
    )
),
family_members AS (
    SELECT id 
    FROM users 
    WHERE family_id = (SELECT family_id FROM affected_family)
    AND status = 'active'
)
SELECT 
    COUNT(*) as mismatched_custody_records,
    MIN(date) as earliest_mismatch,
    MAX(date) as latest_mismatch
FROM custody c
WHERE c.family_id = (SELECT family_id FROM affected_family)
AND c.custodian_id NOT IN (SELECT id FROM family_members);
