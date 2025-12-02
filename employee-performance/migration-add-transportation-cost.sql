-- Migration: Add transportation_cost to client_assignments
-- Date: 2025-11-11
-- Run this in Supabase SQL Editor

-- Add transportation_cost column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'client_assignments' 
        AND column_name = 'transportation_cost'
    ) THEN
        ALTER TABLE client_assignments 
        ADD COLUMN transportation_cost DECIMAL(8, 2) DEFAULT 0;
        
        RAISE NOTICE 'Column transportation_cost added successfully';
    ELSE
        RAISE NOTICE 'Column transportation_cost already exists';
    END IF;
END $$;

-- Verify the column was added
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'client_assignments'
AND column_name = 'transportation_cost';
