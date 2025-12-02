-- RESET DATABASE - COMPLETE CLEANUP
-- Run this in Supabase SQL Editor to start fresh
-- WARNING: This deletes ALL data from all tables

-- Disable triggers temporarily for faster deletion
SET session_replication_role = 'replica';

-- Delete all data (cascades will handle foreign keys)
TRUNCATE TABLE client_assignments CASCADE;
TRUNCATE TABLE appointments CASCADE;
TRUNCATE TABLE work_days CASCADE;
TRUNCATE TABLE employees CASCADE;
TRUNCATE TABLE periods CASCADE;

-- Re-enable triggers
SET session_replication_role = 'origin';

-- Verify tables are empty
SELECT 'periods' as table_name, COUNT(*) as row_count FROM periods
UNION ALL
SELECT 'employees', COUNT(*) FROM employees
UNION ALL
SELECT 'work_days', COUNT(*) FROM work_days
UNION ALL
SELECT 'appointments', COUNT(*) FROM appointments
UNION ALL
SELECT 'client_assignments', COUNT(*) FROM client_assignments;
