-- enrollment_codes_migration.sql
-- SQL migration for creating the enrollment_codes table

-- Check if the table already exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'enrollment_codes') THEN
        -- Create the enrollment_codes table
        CREATE TABLE enrollment_codes (
            id SERIAL PRIMARY KEY,
            family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
            code VARCHAR(6) UNIQUE NOT NULL,
            created_by_user_id UUID NOT NULL REFERENCES users(id),
            coparent_first_name VARCHAR(100),
            coparent_last_name VARCHAR(100),
            coparent_email VARCHAR(255),
            coparent_phone VARCHAR(20),
            invitation_sent BOOLEAN NOT NULL DEFAULT FALSE,
            invitation_sent_at TIMESTAMP,
            created_at TIMESTAMP NOT NULL DEFAULT NOW()
        );

        -- Create indexes for performance
        CREATE INDEX idx_enrollment_codes_family_id ON enrollment_codes(family_id);
        CREATE INDEX idx_enrollment_codes_code ON enrollment_codes(code);
        CREATE INDEX idx_enrollment_codes_created_by_user_id ON enrollment_codes(created_by_user_id);
        
        RAISE NOTICE 'Successfully created enrollment_codes table and indexes';
    ELSE
        RAISE NOTICE 'Table enrollment_codes already exists, skipping creation';
    END IF;
END
$$;