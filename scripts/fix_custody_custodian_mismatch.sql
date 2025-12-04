-- Script to diagnose and fix custody records with mismatched custodian IDs
-- This fixes cases where custody records have custodian_ids that don't belong to family members

DO $$ 
DECLARE 
    affected_count INTEGER := 0;
    family_rec RECORD;
    custody_rec RECORD;
    valid_custodian_ids UUID[];
    fixed_count INTEGER := 0;
BEGIN
    -- For each family, check if custody records have valid custodian IDs
    FOR family_rec IN 
        SELECT DISTINCT f.id as family_id, f.name as family_name
        FROM families f
        INNER JOIN custody c ON c.family_id = f.id
    LOOP
        -- Get all valid user IDs for this family
        SELECT ARRAY_AGG(u.id) INTO valid_custodian_ids
        FROM users u
        WHERE u.family_id = family_rec.family_id
        AND u.status = 'active';
        
        -- Find custody records with invalid custodian IDs
        FOR custody_rec IN
            SELECT c.id, c.date, c.custodian_id, c.family_id
            FROM custody c
            WHERE c.family_id = family_rec.family_id
            AND NOT (c.custodian_id = ANY(valid_custodian_ids))
        LOOP
            affected_count := affected_count + 1;
            
            RAISE NOTICE 'Found mismatched custody record:';
            RAISE NOTICE '  Family: % (%)', family_rec.family_name, family_rec.family_id;
            RAISE NOTICE '  Date: %', custody_rec.date;
            RAISE NOTICE '  Invalid custodian_id: %', custody_rec.custodian_id;
            RAISE NOTICE '  Valid family member IDs: %', valid_custodian_ids;
            
            -- If there are exactly 2 family members, we can attempt to fix it
            IF array_length(valid_custodian_ids, 1) = 2 THEN
                -- Check the pattern - if previous day exists, alternate from that
                DECLARE
                    prev_custody RECORD;
                    new_custodian_id UUID;
                BEGIN
                    SELECT custodian_id INTO prev_custody
                    FROM custody
                    WHERE family_id = family_rec.family_id
                    AND date = custody_rec.date - INTERVAL '1 day'
                    AND custodian_id = ANY(valid_custodian_ids);
                    
                    IF FOUND THEN
                        -- Alternate from previous day
                        IF prev_custody.custodian_id = valid_custodian_ids[1] THEN
                            new_custodian_id := valid_custodian_ids[2];
                        ELSE
                            new_custodian_id := valid_custodian_ids[1];
                        END IF;
                    ELSE
                        -- Default to first parent if no pattern found
                        new_custodian_id := valid_custodian_ids[1];
                    END IF;
                    
                    -- Update the custody record
                    UPDATE custody 
                    SET custodian_id = new_custodian_id,
                        updated_at = NOW()
                    WHERE id = custody_rec.id;
                    
                    fixed_count := fixed_count + 1;
                    RAISE NOTICE '  ✓ Fixed: Updated custodian_id to %', new_custodian_id;
                END;
            ELSE
                RAISE NOTICE '  ⚠ Cannot auto-fix: Family has % members (need exactly 2)', array_length(valid_custodian_ids, 1);
            END IF;
        END LOOP;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Summary:';
    RAISE NOTICE '  Total mismatched records found: %', affected_count;
    RAISE NOTICE '  Records fixed: %', fixed_count;
    RAISE NOTICE '  Records requiring manual fix: %', affected_count - fixed_count;
    RAISE NOTICE '========================================';
    
    -- Also show current family members for reference
    RAISE NOTICE '';
    RAISE NOTICE 'Family Members Reference:';
    FOR family_rec IN 
        SELECT DISTINCT f.id as family_id, f.name as family_name
        FROM families f
        WHERE EXISTS (
            SELECT 1 FROM custody c 
            WHERE c.family_id = f.id 
            AND c.date >= CURRENT_DATE - INTERVAL '30 days'
        )
    LOOP
        RAISE NOTICE 'Family: % (%)', family_rec.family_name, family_rec.family_id;
        FOR custody_rec IN
            SELECT u.id, u.first_name, u.last_name, u.email, u.created_at
            FROM users u
            WHERE u.family_id = family_rec.family_id
            ORDER BY u.created_at
        LOOP
            RAISE NOTICE '  - % % (%) - ID: %', 
                custody_rec.first_name, 
                custody_rec.last_name, 
                custody_rec.email,
                custody_rec.id;
        END LOOP;
    END LOOP;
END $$;
