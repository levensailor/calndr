-- Delete all records for a specific family_id across all tables in the public schema
-- Database: PostgreSQL
-- USAGE: Review, then run in psql or your DB tool against the target database.
-- NOTE: This script deletes child rows in any table with a family_id column first,
--       and deletes the family row in the families table last to avoid FK violations.

-- =============================================
-- Configuration
-- =============================================
-- Set the family UUID to purge (requested value)
-- Replace if needed before executing
\set family_uuid '5006b3f2-7dff-49a6-a168-741f0adce6e1'

BEGIN;

-- Safety: show what will be deleted per table (pre-check)
DO $$
DECLARE
    v_family_uuid uuid := :'family_uuid';
    r record;
    v_count bigint;
BEGIN
    RAISE NOTICE 'Preparing to delete data for family_id=%', v_family_uuid;

    FOR r IN (
        SELECT c.table_schema, c.table_name
        FROM information_schema.columns c
        WHERE c.column_name = 'family_id'
          AND c.table_schema = 'public'
          AND c.table_name <> 'families'
        ORDER BY c.table_name
    ) LOOP
        EXECUTE format('SELECT count(*) FROM %I.%I WHERE family_id = $1', r.table_schema, r.table_name)
        INTO v_count
        USING v_family_uuid;
        IF v_count > 0 THEN
            RAISE NOTICE 'Will delete % row(s) from %.% where family_id=%', v_count, r.table_schema, r.table_name, v_family_uuid;
        END IF;
    END LOOP;

    -- Families table count (deleted last)
    EXECUTE format('SELECT count(*) FROM %I.%I WHERE id = $1', 'public', 'families')
    INTO v_count USING v_family_uuid;
    IF v_count > 0 THEN
        RAISE NOTICE 'Will delete % row(s) from public.families where id=%', v_count, v_family_uuid;
    END IF;
END $$;

-- Actual deletions: delete from all tables with a family_id column except families
DO $$
DECLARE
    v_family_uuid uuid := :'family_uuid';
    r record;
    v_deleted bigint;
BEGIN
    -- Delete from child tables first
    FOR r IN (
        SELECT c.table_schema, c.table_name
        FROM information_schema.columns c
        WHERE c.column_name = 'family_id'
          AND c.table_schema = 'public'
          AND c.table_name <> 'families'
        ORDER BY c.table_name
    ) LOOP
        EXECUTE format('DELETE FROM %I.%I WHERE family_id = $1', r.table_schema, r.table_name)
        USING v_family_uuid;
        GET DIAGNOSTICS v_deleted = ROW_COUNT;
        IF v_deleted > 0 THEN
            RAISE NOTICE 'Deleted % row(s) from %.%', v_deleted, r.table_schema, r.table_name;
        END IF;
    END LOOP;

    -- Finally, delete the family record itself
    EXECUTE 'DELETE FROM public.families WHERE id = $1' USING v_family_uuid;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    IF v_deleted > 0 THEN
        RAISE NOTICE 'Deleted % row(s) from public.families', v_deleted;
    END IF;
END $$;

COMMIT;

-- Optional: verification
-- SELECT table_name, (xpath('/row/cnt/text()', xml_count))[1]::text::bigint AS remaining
-- FROM (
--   SELECT c.table_name,
--          query_to_xml(format('SELECT count(*) AS cnt FROM %I.%I WHERE family_id = %L', c.table_schema, c.table_name, :'family_uuid'),
--                        false, true, '') AS xml_count
--   FROM information_schema.columns c
--   WHERE c.column_name = 'family_id' AND c.table_schema = 'public') s;


