-- Enrollment Codes Migration SQL
-- Run this directly on your PostgreSQL database to create the enrollment_codes table

-- Create the enrollment_codes table
CREATE TABLE IF NOT EXISTS enrollment_codes (
    id SERIAL PRIMARY KEY,
    code VARCHAR(6) UNIQUE NOT NULL,
    family_id UUID REFERENCES families(id) ON DELETE CASCADE,
    created_by_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    is_used BOOLEAN DEFAULT FALSE,
    used_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '7 days'),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_enrollment_codes_code ON enrollment_codes(code);
CREATE INDEX IF NOT EXISTS idx_enrollment_codes_family_id ON enrollment_codes(family_id);
CREATE INDEX IF NOT EXISTS idx_enrollment_codes_created_by ON enrollment_codes(created_by_user_id);
CREATE INDEX IF NOT EXISTS idx_enrollment_codes_expires_at ON enrollment_codes(expires_at);
CREATE INDEX IF NOT EXISTS idx_enrollment_codes_is_used ON enrollment_codes(is_used);

-- Create trigger function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_enrollment_codes_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger
DROP TRIGGER IF EXISTS update_enrollment_codes_updated_at ON enrollment_codes;
CREATE TRIGGER update_enrollment_codes_updated_at
    BEFORE UPDATE ON enrollment_codes
    FOR EACH ROW
    EXECUTE FUNCTION update_enrollment_codes_updated_at();

-- Verify the table was created
SELECT 'enrollment_codes table created successfully' as status;
