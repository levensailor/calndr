-- Script to delete all records for family_id: 5006b3f2-7dff-49a6-a168-741f0adce6e1
-- This script deletes from all tables in the correct order to respect foreign key constraints
-- Run with: psql -d your_database -f scripts/delete_family_5006b3f2.sql

DO $$ 
DECLARE 
    target_family_id UUID := '5006b3f2-7dff-49a6-a168-741f0adce6e1'::uuid;
    deleted_count INTEGER;
    total_deleted INTEGER := 0;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Starting deletion for family_id: %', target_family_id;
    RAISE NOTICE '========================================';
    RAISE NOTICE '';

    -- First, let's verify the family exists and show basic info
    PERFORM 1 FROM families WHERE id = target_family_id;
    IF NOT FOUND THEN
        RAISE NOTICE 'Family % not found in database. Exiting.', target_family_id;
        RETURN;
    END IF;

    -- Show family information before deletion
    RAISE NOTICE 'Family information:';
    FOR deleted_count IN
        SELECT 1 FROM families WHERE id = target_family_id
    LOOP
        RAISE NOTICE '  Family name: %', (SELECT name FROM families WHERE id = target_family_id);
        RAISE NOTICE '  Created at: %', (SELECT created_at FROM families WHERE id = target_family_id);
    END LOOP;

    -- Show user count for this family
    SELECT COUNT(*) INTO deleted_count FROM users WHERE family_id = target_family_id;
    RAISE NOTICE '  Users in family: %', deleted_count;
    RAISE NOTICE '';

    -- Start deletions in order of dependencies (most dependent first)
    
    -- Delete from custody table
    DELETE FROM custody WHERE family_id = target_family_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    total_deleted := total_deleted + deleted_count;
    RAISE NOTICE 'Deleted % custody records', deleted_count;

    -- Delete from schedule_templates table
    DELETE FROM schedule_templates WHERE family_id = target_family_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    total_deleted := total_deleted + deleted_count;
    RAISE NOTICE 'Deleted % schedule templates', deleted_count;

    -- Delete from events table
    DELETE FROM events WHERE family_id = target_family_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    total_deleted := total_deleted + deleted_count;
    RAISE NOTICE 'Deleted % events', deleted_count;

    -- Delete from children table
    DELETE FROM children WHERE family_id = target_family_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    total_deleted := total_deleted + deleted_count;
    RAISE NOTICE 'Deleted % children records', deleted_count;

    -- Delete from enrollment_codes table
    DELETE FROM enrollment_codes WHERE family_id = target_family_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    total_deleted := total_deleted + deleted_count;
    RAISE NOTICE 'Deleted % enrollment codes', deleted_count;

    -- Delete from reminders table
    DELETE FROM reminders WHERE family_id = target_family_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    total_deleted := total_deleted + deleted_count;
    RAISE NOTICE 'Deleted % reminders', deleted_count;

    -- Delete from journal_entries table
    DELETE FROM journal_entries WHERE family_id = target_family_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    total_deleted := total_deleted + deleted_count;
    RAISE NOTICE 'Deleted % journal entries', deleted_count;

    -- Delete from medical_providers table
    DELETE FROM medical_providers WHERE family_id = target_family_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    total_deleted := total_deleted + deleted_count;
    RAISE NOTICE 'Deleted % medical providers', deleted_count;

    -- Delete from medications table
    DELETE FROM medications WHERE family_id = target_family_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    total_deleted := total_deleted + deleted_count;
    RAISE NOTICE 'Deleted % medications', deleted_count;

    -- Delete from daycare_providers table
    DELETE FROM daycare_providers WHERE family_id = target_family_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    total_deleted := total_deleted + deleted_count;
    RAISE NOTICE 'Deleted % daycare providers', deleted_count;

    -- Delete from school_providers table
    DELETE FROM school_providers WHERE family_id = target_family_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    total_deleted := total_deleted + deleted_count;
    RAISE NOTICE 'Deleted % school providers', deleted_count;

    -- Delete from emergency_contacts table
    DELETE FROM emergency_contacts WHERE family_id = target_family_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    total_deleted := total_deleted + deleted_count;
    RAISE NOTICE 'Deleted % emergency contacts', deleted_count;

    -- Delete from babysitters table
    DELETE FROM babysitters WHERE family_id = target_family_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    total_deleted := total_deleted + deleted_count;
    RAISE NOTICE 'Deleted % babysitters', deleted_count;

    -- Delete from notification_emails table
    DELETE FROM notification_emails WHERE family_id = target_family_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    total_deleted := total_deleted + deleted_count;
    RAISE NOTICE 'Deleted % notification emails', deleted_count;

    -- Delete from group_chats table (messages sent by users in this family)
    DELETE FROM group_chats WHERE sender_id IN (SELECT id FROM users WHERE family_id = target_family_id);
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    total_deleted := total_deleted + deleted_count;
    RAISE NOTICE 'Deleted % group chat messages', deleted_count;

    -- Delete from user_profiles table (for users in this family)
    DELETE FROM user_profiles WHERE user_id IN (SELECT id FROM users WHERE family_id = target_family_id);
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    total_deleted := total_deleted + deleted_count;
    RAISE NOTICE 'Deleted % user profiles', deleted_count;

    -- Delete from user_preferences table (for users in this family)
    DELETE FROM user_preferences WHERE user_id IN (SELECT id FROM users WHERE family_id = target_family_id);
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    total_deleted := total_deleted + deleted_count;
    RAISE NOTICE 'Deleted % user preferences', deleted_count;

    -- Delete from refresh_tokens table (for users in this family)
    DELETE FROM refresh_tokens WHERE user_id IN (SELECT id FROM users WHERE family_id = target_family_id);
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    total_deleted := total_deleted + deleted_count;
    RAISE NOTICE 'Deleted % refresh tokens', deleted_count;

    -- Delete from password_reset_tokens table (for users in this family)
    DELETE FROM password_reset_tokens WHERE user_id IN (SELECT id FROM users WHERE family_id = target_family_id);
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    total_deleted := total_deleted + deleted_count;
    RAISE NOTICE 'Deleted % password reset tokens', deleted_count;

    -- Delete from users table
    DELETE FROM users WHERE family_id = target_family_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    total_deleted := total_deleted + deleted_count;
    RAISE NOTICE 'Deleted % users', deleted_count;

    -- Finally, delete from families table
    DELETE FROM families WHERE id = target_family_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    total_deleted := total_deleted + deleted_count;
    RAISE NOTICE 'Deleted % family record', deleted_count;

    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Deletion complete!';
    RAISE NOTICE 'Total records deleted: %', total_deleted;
    RAISE NOTICE 'Family ID %s has been completely removed from the database.', target_family_id;
    RAISE NOTICE '========================================';

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE '';
        RAISE NOTICE '❌ ERROR: Foreign key constraint violation';
        RAISE NOTICE 'There may be additional tables referencing this family that need to be cleaned first.';
        RAISE NOTICE 'Error details: %', SQLERRM;
        RAISE;
    WHEN OTHERS THEN
        RAISE NOTICE '';
        RAISE NOTICE '❌ ERROR: An unexpected error occurred';
        RAISE NOTICE 'Error details: %', SQLERRM;
        RAISE;
END $$;

-- Verify deletion was successful
SELECT 
    'Verification: Family still exists?' as check_type,
    CASE 
        WHEN EXISTS (SELECT 1 FROM families WHERE id = '5006b3f2-7dff-49a6-a168-741f0adce6e1'::uuid)
        THEN 'FAILED - Family still exists!'
        ELSE 'SUCCESS - Family deleted'
    END as result;

SELECT 
    'Verification: Any users remaining?' as check_type,
    CASE 
        WHEN EXISTS (SELECT 1 FROM users WHERE family_id = '5006b3f2-7dff-49a6-a168-741f0adce6e1'::uuid)
        THEN 'FAILED - Users still exist!'
        ELSE 'SUCCESS - All users deleted'
    END as result;

SELECT 
    'Verification: Any custody records remaining?' as check_type,
    CASE 
        WHEN EXISTS (SELECT 1 FROM custody WHERE family_id = '5006b3f2-7dff-49a6-a168-741f0adce6e1'::uuid)
        THEN 'FAILED - Custody records still exist!'
        ELSE 'SUCCESS - All custody records deleted'
    END as result;
