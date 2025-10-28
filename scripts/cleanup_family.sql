-- Cleanup script for a specific family and all associated data
-- This script will remove all data for family_id = '1e0b77b7-5a9a-4759-9ace-2bfa8a64e4a5'

-- Start a transaction to ensure all operations succeed or none do
BEGIN;

-- Store the family_id in a variable for readability
DO $$
DECLARE
    target_family_id UUID := '776a73d5-78a6-4e1f-ae92-32466844bebe';
BEGIN

    -- Delete records from dependent tables first (ordered by dependencies)
    
    -- Delete custody records
    DELETE FROM custody 
    WHERE family_id = target_family_id;
    
    -- Delete schedule templates
    DELETE FROM schedule_templates 
    WHERE family_id = target_family_id;
    
    -- Delete children
    DELETE FROM children 
    WHERE family_id = target_family_id;
    
    -- Delete enrollment codes
    DELETE FROM enrollment_codes 
    WHERE family_id = target_family_id;
    
    -- Delete reminders
    DELETE FROM reminders 
    WHERE family_id = target_family_id;
    
    -- Delete journal entries
    DELETE FROM journal_entries 
    WHERE family_id = target_family_id;
    
    -- Delete medical providers
    DELETE FROM medical_providers 
    WHERE family_id = target_family_id;
    
    -- Delete medications
    DELETE FROM medications 
    WHERE family_id = target_family_id;
    
    -- Delete daycare providers and related records
    DELETE FROM daycare_events 
    WHERE daycare_provider_id IN (
        SELECT id FROM daycare_providers WHERE family_id = target_family_id
    );
    
    DELETE FROM daycare_calendar_syncs 
    WHERE daycare_provider_id IN (
        SELECT id FROM daycare_providers WHERE family_id = target_family_id
    );
    
    DELETE FROM daycare_providers 
    WHERE family_id = target_family_id;
    
    -- Delete school providers and related records
    DELETE FROM school_events 
    WHERE school_provider_id IN (
        SELECT id FROM school_providers WHERE family_id = target_family_id
    );
    
    DELETE FROM school_calendar_syncs 
    WHERE school_provider_id IN (
        SELECT id FROM school_providers WHERE family_id = target_family_id
    );
    
    DELETE FROM school_providers 
    WHERE family_id = target_family_id;
    
    -- Delete emergency contacts
    DELETE FROM emergency_contacts 
    WHERE family_id = target_family_id;
    
    -- Delete babysitters and related records
    DELETE FROM babysitter_families 
    WHERE family_id = target_family_id;
    
    DELETE FROM babysitters 
    WHERE id IN (
        SELECT babysitter_id FROM babysitter_families WHERE family_id = target_family_id
    );
    
    -- Delete notification emails
    DELETE FROM notification_emails 
    WHERE family_id = target_family_id;
    
    -- Delete users (must be done before families)
    DELETE FROM users 
    WHERE family_id = target_family_id;
    
    -- Finally delete the family
    DELETE FROM families 
    WHERE id = target_family_id;

    -- Log the number of affected rows (uncomment to check)
    /*
    RAISE NOTICE 'Deleted data for family %:', target_family_id;
    RAISE NOTICE '- Custody records: %', (SELECT COUNT(*) FROM custody WHERE family_id = target_family_id);
    RAISE NOTICE '- Schedule templates: %', (SELECT COUNT(*) FROM schedule_templates WHERE family_id = target_family_id);
    RAISE NOTICE '- Children: %', (SELECT COUNT(*) FROM children WHERE family_id = target_family_id);
    RAISE NOTICE '- Users: %', (SELECT COUNT(*) FROM users WHERE family_id = target_family_id);
    */

END $$;

-- Commit the transaction
COMMIT;

-- Verify deletions (uncomment to check)
/*
SELECT 'custody' as table_name, COUNT(*) as remaining_count 
FROM custody 
WHERE family_id = '1e0b77b7-5a9a-4759-9ace-2bfa8a64e4a5'
UNION ALL
SELECT 'schedule_templates', COUNT(*) 
FROM schedule_templates 
WHERE family_id = '1e0b77b7-5a9a-4759-9ace-2bfa8a64e4a5'
UNION ALL
SELECT 'children', COUNT(*) 
FROM children 
WHERE family_id = '1e0b77b7-5a9a-4759-9ace-2bfa8a64e4a5'
UNION ALL
SELECT 'users', COUNT(*) 
FROM users 
WHERE family_id = '1e0b77b7-5a9a-4759-9ace-2bfa8a64e4a5'
UNION ALL
SELECT 'families', COUNT(*) 
FROM families 
WHERE id = '1e0b77b7-5a9a-4759-9ace-2bfa8a64e4a5';
*/
