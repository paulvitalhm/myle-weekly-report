-- MYLE Employee Performance Index - Migration Schema
-- This file is idempotent - safe to run multiple times
-- Run this script in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Periods Table (represents each upload/reporting period)
CREATE TABLE IF NOT EXISTS periods (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    employee_count INTEGER DEFAULT 0,
    appointment_count INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'completed', 'archived')),
    notes TEXT
);

-- 2. Employees Table (populated from timesheet uploads)
CREATE TABLE IF NOT EXISTS employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    period_id UUID NOT NULL REFERENCES periods(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    total_hours DECIMAL(10, 2) DEFAULT 0,
    total_days INTEGER DEFAULT 0,
    completed_days INTEGER DEFAULT 0,
    is_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(period_id, name)
);

-- 3. Work Days Table (each employee's work days from timesheet)
CREATE TABLE IF NOT EXISTS work_days (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    work_date DATE NOT NULL,
    hours_worked DECIMAL(5, 2) NOT NULL,
    hours_display VARCHAR(20), -- e.g., "6h 5m"
    is_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(employee_id, work_date)
);

-- 4. Appointments Table (from appointments upload)
CREATE TABLE IF NOT EXISTS appointments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    period_id UUID NOT NULL REFERENCES periods(id) ON DELETE CASCADE,
    appointment_date DATE NOT NULL,
    appointment_time VARCHAR(50),
    service VARCHAR(255),
    cost DECIMAL(10, 2),
    team_member VARCHAR(100),
    customer_name VARCHAR(255),
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(50),
    country VARCHAR(100),
    postal_code VARCHAR(20),
    status VARCHAR(50),
    booking_id VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Client Assignments (employee selections)
CREATE TABLE IF NOT EXISTS client_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    work_day_id UUID NOT NULL REFERENCES work_days(id) ON DELETE CASCADE,
    appointment_id UUID NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
    arrival_delay_minutes INTEGER DEFAULT 0, -- Late arrival time in minutes
    early_departure_minutes INTEGER DEFAULT 0, -- Early leave time in minutes
    transportation_cost DECIMAL(8, 2) DEFAULT 0, -- Transportation costs incurred
    actual_hours DECIMAL(5, 2), -- Calculated hours after offsets
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(work_day_id, appointment_id)
);

-- Indexes for performance (IF NOT EXISTS requires Postgres 9.5+)
CREATE INDEX IF NOT EXISTS idx_periods_dates ON periods(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_employees_period ON employees(period_id);
CREATE INDEX IF NOT EXISTS idx_employees_completed ON employees(is_completed);
CREATE INDEX IF NOT EXISTS idx_work_days_employee ON work_days(employee_id);
CREATE INDEX IF NOT EXISTS idx_work_days_date ON work_days(work_date);
CREATE INDEX IF NOT EXISTS idx_appointments_period ON appointments(period_id);
CREATE INDEX IF NOT EXISTS idx_appointments_date ON appointments(appointment_date);
CREATE INDEX IF NOT EXISTS idx_client_assignments_work_day ON client_assignments(work_day_id);

-- Function to auto-update work_day completion status based on assignments
CREATE OR REPLACE FUNCTION update_work_day_completion()
RETURNS TRIGGER AS $$
DECLARE
    v_work_day_id UUID;
    v_employee_id UUID;
BEGIN
    -- Get work_day_id from the assignment
    IF TG_OP = 'DELETE' THEN
        v_work_day_id := OLD.work_day_id;
    ELSE
        v_work_day_id := NEW.work_day_id;
    END IF;
    
    -- Update work_day.is_completed based on whether it has any assignments
    UPDATE work_days
    SET 
        is_completed = (
            SELECT COUNT(*) > 0
            FROM client_assignments
            WHERE work_day_id = v_work_day_id
        ),
        updated_at = NOW()
    WHERE id = v_work_day_id;
    
    -- Get employee_id for cascading update
    SELECT employee_id INTO v_employee_id
    FROM work_days
    WHERE id = v_work_day_id;
    
    -- Update employee completion stats
    UPDATE employees
    SET 
        completed_days = (
            SELECT COUNT(*) 
            FROM work_days 
            WHERE employee_id = v_employee_id AND is_completed = TRUE
        ),
        is_completed = (
            SELECT 
                CASE 
                    WHEN COUNT(*) = COUNT(CASE WHEN is_completed THEN 1 END) 
                    THEN TRUE 
                    ELSE FALSE 
                END
            FROM work_days 
            WHERE employee_id = v_employee_id
        ),
        updated_at = NOW()
    WHERE id = v_employee_id;
    
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update work_day and employee completion when assignments change
DROP TRIGGER IF EXISTS trigger_update_work_day_completion ON client_assignments;
CREATE TRIGGER trigger_update_work_day_completion
AFTER INSERT OR DELETE ON client_assignments
FOR EACH ROW
EXECUTE FUNCTION update_work_day_completion();

-- Function to calculate actual_hours for an assignment
CREATE OR REPLACE FUNCTION calculate_actual_hours()
RETURNS TRIGGER AS $$
DECLARE
    v_work_day_hours DECIMAL(5, 2);
BEGIN
    -- Get the hours_worked from the work_day
    SELECT hours_worked INTO v_work_day_hours
    FROM work_days
    WHERE id = NEW.work_day_id;
    
    -- Calculate actual hours: base hours - delays (converted to hours)
    NEW.actual_hours := v_work_day_hours - 
        (COALESCE(NEW.arrival_delay_minutes, 0) / 60.0) - 
        (COALESCE(NEW.early_departure_minutes, 0) / 60.0);
    
    -- Ensure non-negative
    IF NEW.actual_hours < 0 THEN
        NEW.actual_hours := 0;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-calculate actual_hours on insert/update
DROP TRIGGER IF EXISTS trigger_calculate_actual_hours ON client_assignments;
CREATE TRIGGER trigger_calculate_actual_hours
BEFORE INSERT OR UPDATE OF arrival_delay_minutes, early_departure_minutes ON client_assignments
FOR EACH ROW
EXECUTE FUNCTION calculate_actual_hours();

-- Function to update period stats
CREATE OR REPLACE FUNCTION update_period_stats()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE periods
    SET 
        employee_count = (SELECT COUNT(*) FROM employees WHERE period_id = NEW.period_id),
        appointment_count = (SELECT COUNT(*) FROM appointments WHERE period_id = NEW.period_id),
        updated_at = NOW()
    WHERE id = NEW.period_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers to auto-update period stats
DROP TRIGGER IF EXISTS trigger_update_period_stats_employees ON employees;
CREATE TRIGGER trigger_update_period_stats_employees
AFTER INSERT OR DELETE ON employees
FOR EACH ROW
EXECUTE FUNCTION update_period_stats();

DROP TRIGGER IF EXISTS trigger_update_period_stats_appointments ON appointments;
CREATE TRIGGER trigger_update_period_stats_appointments
AFTER INSERT OR DELETE ON appointments
FOR EACH ROW
EXECUTE FUNCTION update_period_stats();

-- Row Level Security (RLS) Policies
-- DISABLED FOR DEVELOPMENT - Enable and configure properly for production

-- Disable RLS on all tables (allows all operations without auth)
ALTER TABLE periods DISABLE ROW LEVEL SECURITY;
ALTER TABLE employees DISABLE ROW LEVEL SECURITY;
ALTER TABLE work_days DISABLE ROW LEVEL SECURITY;
ALTER TABLE appointments DISABLE ROW LEVEL SECURITY;
ALTER TABLE client_assignments DISABLE ROW LEVEL SECURITY;

-- Drop existing policies (cleanup)
DROP POLICY IF EXISTS "Allow all operations for authenticated users" ON periods;
DROP POLICY IF EXISTS "Allow all operations for authenticated users" ON employees;
DROP POLICY IF EXISTS "Allow all operations for authenticated users" ON work_days;
DROP POLICY IF EXISTS "Allow all operations for authenticated users" ON appointments;
DROP POLICY IF EXISTS "Allow all operations for authenticated users" ON client_assignments;

-- PRODUCTION RLS SETUP (commented out for now)
-- Uncomment and modify these when ready to enable authentication:
--
-- ALTER TABLE periods ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE work_days ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE client_assignments ENABLE ROW LEVEL SECURITY;
--
-- CREATE POLICY "Allow all operations for authenticated users" ON periods
--     FOR ALL USING (auth.role() = 'authenticated');
--
-- CREATE POLICY "Allow all operations for authenticated users" ON employees
--     FOR ALL USING (auth.role() = 'authenticated');
--
-- CREATE POLICY "Allow all operations for authenticated users" ON work_days
--     FOR ALL USING (auth.role() = 'authenticated');
--
-- CREATE POLICY "Allow all operations for authenticated users" ON appointments
--     FOR ALL USING (auth.role() = 'authenticated');
--
-- CREATE POLICY "Allow all operations for authenticated users" ON client_assignments
--     FOR ALL USING (auth.role() = 'authenticated');

-- ATOMIC UPLOAD FUNCTION
-- Wraps entire upload in a single transaction for data consistency
CREATE OR REPLACE FUNCTION upload_period_data(
    p_start_date DATE,
    p_end_date DATE,
    p_employees JSONB, -- [{ name: string, workDays: [{ date: string, hours: number }] }]
    p_appointments JSONB -- [{ bookingId: string, date: string, time: string, ... }]
)
RETURNS TABLE (
    period_id UUID,
    success BOOLEAN,
    message TEXT
) AS $$
DECLARE
    v_period_id UUID;
    v_employee_id UUID;
    v_employee JSONB;
    v_work_day JSONB;
    v_appointment JSONB;
    v_existing_period UUID;
    v_employee_name VARCHAR;
    v_work_date DATE;
    v_duplicate_check TEXT;
BEGIN
    -- Check for existing period with same dates
    SELECT id INTO v_existing_period
    FROM periods
    WHERE start_date = p_start_date AND end_date = p_end_date
    LIMIT 1;
    
    IF v_existing_period IS NOT NULL THEN
        RETURN QUERY SELECT 
            v_existing_period,
            FALSE,
            'Period already exists with these dates. Delete the existing period first or use a different date range.'::TEXT;
        RETURN;
    END IF;
    
    -- Create period
    INSERT INTO periods (start_date, end_date)
    VALUES (p_start_date, p_end_date)
    RETURNING id INTO v_period_id;
    
    -- Insert employees and their work days
    FOR v_employee IN SELECT * FROM jsonb_array_elements(p_employees)
    LOOP
        -- Insert employee
        INSERT INTO employees (period_id, name)
        VALUES (v_period_id, (v_employee->>'name')::VARCHAR)
        RETURNING id INTO v_employee_id;
        
        -- Insert work days for this employee
        FOR v_work_day IN SELECT * FROM jsonb_array_elements(v_employee->'workDays')
        LOOP
            INSERT INTO work_days (employee_id, work_date, hours_worked)
            VALUES (
                v_employee_id,
                (v_work_day->>'date')::DATE,
                (v_work_day->>'hours')::DECIMAL
            );
        END LOOP;
    END LOOP;
    
    -- Insert appointments
    FOR v_appointment IN SELECT * FROM jsonb_array_elements(p_appointments)
    LOOP
        INSERT INTO appointments (
            period_id,
            booking_id,
            appointment_date,
            appointment_time,
            customer_name,
            service,
            address,
            city,
            team_member,
            status,
            cost
        ) VALUES (
            v_period_id,
            (v_appointment->>'bookingId')::VARCHAR,
            (v_appointment->>'date')::DATE,
            (v_appointment->>'time')::VARCHAR,
            (v_appointment->>'customer')::VARCHAR,
            (v_appointment->>'service')::VARCHAR,
            (v_appointment->>'address')::TEXT,
            (v_appointment->>'city')::VARCHAR,
            (v_appointment->>'team')::VARCHAR,
            (v_appointment->>'status')::VARCHAR,
            (v_appointment->>'cost')::DECIMAL
        );
    END LOOP;
    
    -- Return success
    RETURN QUERY SELECT 
        v_period_id,
        TRUE,
        'Period uploaded successfully'::TEXT;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Rollback happens automatically
        RETURN QUERY SELECT 
            NULL::UUID,
            FALSE,
            ('Upload failed: ' || SQLERRM)::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Function to delete a period and all related data (atomic)
CREATE OR REPLACE FUNCTION delete_period(p_period_id UUID)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT
) AS $$
BEGIN
    -- Check if period exists
    IF NOT EXISTS (SELECT 1 FROM periods WHERE id = p_period_id) THEN
        RETURN QUERY SELECT FALSE, 'Period not found'::TEXT;
        RETURN;
    END IF;
    
    -- Delete period (cascades to all related tables)
    DELETE FROM periods WHERE id = p_period_id;
    
    RETURN QUERY SELECT TRUE, 'Period deleted successfully'::TEXT;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, ('Delete failed: ' || SQLERRM)::TEXT;
END;
$$ LANGUAGE plpgsql;

-- PERFORMANCE INDEX FUNCTION (FIXED)
-- Calculates individual performance metrics for each work day
-- FIXED: Now correctly shows net revenue (after transportation cost deduction) in the "earned" column
CREATE OR REPLACE FUNCTION get_performance_index(p_period_id UUID)
RETURNS TABLE (
    rank BIGINT,
    index NUMERIC,
    who VARCHAR,
    "when" TEXT,
    "where" TEXT,
    earned NUMERIC,
    work_day_id UUID,
    work_date DATE,
    hours_worked NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH appointment_totals AS (
        SELECT 
            a.id as appointment_id,
            a.cost,
            SUM(ca.actual_hours) as total_hours_on_appointment
        FROM appointments a
        LEFT JOIN client_assignments ca ON a.id = ca.appointment_id
        WHERE a.period_id = p_period_id
        GROUP BY a.id, a.cost
    ),
    revenue_allocation AS (
        SELECT 
            ca.work_day_id,
            a.customer_name,
            ca.actual_hours,
            ca.transportation_cost,
            at.total_hours_on_appointment,
            ((ca.actual_hours / NULLIF(at.total_hours_on_appointment, 0)) * at.cost) - COALESCE(ca.transportation_cost, 0) as allocated_revenue,
            ((ca.actual_hours / NULLIF(at.total_hours_on_appointment, 0)) * at.cost) as gross_revenue
        FROM client_assignments ca
        JOIN appointments a ON ca.appointment_id = a.id
        JOIN appointment_totals at ON a.id = at.appointment_id
        WHERE a.period_id = p_period_id
    )
    SELECT 
        ROW_NUMBER() OVER (ORDER BY (SUM(COALESCE(ra.allocated_revenue, 0)) / NULLIF(wd.hours_worked, 0)) DESC) as rank,
        ROUND((SUM(COALESCE(ra.allocated_revenue, 0)) / NULLIF(wd.hours_worked, 0))::numeric, 2) as index,
        e.name::VARCHAR as who,
        (TO_CHAR(wd.work_date, 'Dy, Mon DD YYYY') || ' (' || 
         FLOOR(wd.hours_worked)::text || 'h ' || 
         ROUND((wd.hours_worked - FLOOR(wd.hours_worked)) * 60)::int::text || 'm)')::TEXT as "when",
        COALESCE(STRING_AGG(DISTINCT ra.customer_name, ', '), 'Pending')::TEXT as "where",
        ROUND(SUM(COALESCE(ra.allocated_revenue, 0))::numeric, 2) as earned,
        wd.id as work_day_id,
        wd.work_date,
        wd.hours_worked::numeric
    FROM work_days wd
    JOIN employees e ON wd.employee_id = e.id
    LEFT JOIN revenue_allocation ra ON wd.id = ra.work_day_id
    WHERE wd.hours_worked > 0 
        AND e.period_id = p_period_id
    GROUP BY wd.id, wd.work_date, wd.employee_id, e.name, wd.hours_worked
    ORDER BY index DESC;
END;
$$ LANGUAGE plpgsql;

-- Sample query to get period with completion stats
-- SELECT 
--     p.id,
--     p.start_date,
--     p.end_date,
--     p.employee_count,
--     p.appointment_count,
--     COUNT(DISTINCT e.id) FILTER (WHERE e.is_completed = TRUE) as completed_employees,
--     ROUND(
--         (COUNT(DISTINCT e.id) FILTER (WHERE e.is_completed = TRUE)::DECIMAL / 
--          NULLIF(COUNT(DISTINCT e.id), 0) * 100), 2
--     ) as completion_percentage
-- FROM periods p
-- LEFT JOIN employees e ON p.id = e.period_id
-- GROUP BY p.id, p.start_date, p.end_date, p.employee_count, p.appointment_count
-- ORDER BY p.start_date DESC;
