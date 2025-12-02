-- Correct Performance Index Solution
-- This addresses the fundamental flaw in the formula

-- Drop the existing function
DROP FUNCTION IF EXISTS get_performance_index(UUID);

-- Create the corrected function that uses actual appointment hours
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
    WITH appointment_revenue AS (
        -- Calculate revenue allocation based on ACTUAL hours worked per appointment
        -- This is the key fix: use actual_hours instead of proportional allocation
        SELECT 
            ca.work_day_id,
            ca.actual_hours,
            ca.transportation_cost,
            a.cost as appointment_cost,
            -- Allocate revenue based on actual hours worked on this appointment
            -- If we have actual hours, use them; otherwise fall back to proportional
            CASE 
                WHEN ca.actual_hours IS NOT NULL AND ca.actual_hours > 0 THEN
                    ((ca.actual_hours / NULLIF(SUM(ca.actual_hours) OVER (PARTITION BY a.id), 0)) * a.cost) - COALESCE(ca.transportation_cost, 0)
                ELSE
                    -- Fallback: proportional to work day hours (current method)
                    ((wd.hours_worked / NULLIF(SUM(wd.hours_worked) OVER (PARTITION BY a.id), 0)) * a.cost) - COALESCE(ca.transportation_cost, 0)
            END as allocated_revenue
        FROM client_assignments ca
        JOIN appointments a ON ca.appointment_id = a.id
        JOIN work_days wd ON ca.work_day_id = wd.id
        JOIN employees e ON wd.employee_id = e.id
        WHERE e.period_id = p_period_id
    ),
    daily_totals AS (
        -- Calculate total earned per work day
        SELECT 
            wd.id as work_day_id,
            SUM(ar.allocated_revenue) as total_earned
        FROM work_days wd
        JOIN appointment_revenue ar ON wd.id = ar.work_day_id
        GROUP BY wd.id
    ),
    customer_names AS (
        -- Get customer names for display
        SELECT 
            wd.id as work_day_id,
            STRING_AGG(DISTINCT a.customer_name, ', ') as customer_list
        FROM work_days wd
        JOIN client_assignments ca ON wd.id = ca.work_day_id
        JOIN appointments a ON ca.appointment_id = a.id
        WHERE EXISTS (
            SELECT 1 FROM employees e 
            WHERE e.id = wd.employee_id AND e.period_id = p_period_id
        )
        GROUP BY wd.id
    )
    SELECT 
        ROW_NUMBER() OVER (ORDER BY (dt.total_earned / NULLIF(wd.hours_worked, 0)) DESC) as rank,
        ROUND((dt.total_earned / NULLIF(wd.hours_worked, 0))::numeric, 2) as index,
        e.name::VARCHAR as who,
        (TO_CHAR(wd.work_date, 'Dy, Mon DD YYYY') || ' (' || 
         FLOOR(wd.hours_worked)::text || 'h ' || 
         ROUND((wd.hours_worked - FLOOR(wd.hours_worked)) * 60)::int::text || 'm)')::TEXT as "when",
        COALESCE(cn.customer_list, 'Pending')::TEXT as "where",
        dt.total_earned as earned,
        wd.id as work_day_id,
        wd.work_date,
        wd.hours_worked::numeric
    FROM work_days wd
    JOIN employees e ON wd.employee_id = e.id
    JOIN daily_totals dt ON wd.id = dt.work_day_id
    LEFT JOIN customer_names cn ON wd.id = cn.work_day_id
    WHERE wd.hours_worked > 0 
        AND e.period_id = p_period_id
    ORDER BY index DESC;
END;
$$ LANGUAGE plpgsql;

-- Test the corrected function
SELECT * FROM get_performance_index('91a20127-5cda-4220-a405-791640417f5d')
WHERE who ILIKE '%paul%' OR who ILIKE '%mariana%' OR who ILIKE '%nanette%' OR who ILIKE '%soraya%'
ORDER BY work_date, who;

-- Analyze the actual hours data to understand the current state
SELECT 
    e.name,
    wd.work_date,
    wd.hours_worked as total_day_hours,
    ca.actual_hours as assignment_hours,
    a.customer_name,
    a.cost,
    ca.transportation_cost
FROM work_days wd
JOIN employees e ON wd.employee_id = e.id
JOIN client_assignments ca ON wd.id = ca.work_day_id
JOIN appointments a ON ca.appointment_id = a.id
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
  AND (e.name ILIKE '%nanette%' OR e.name ILIKE '%soraya%' OR e.name ILIKE '%paul%' OR e.name ILIKE '%mariana%')
ORDER BY wd.work_date, e.name, a.customer_name;

-- Check if we have meaningful actual_hours data
SELECT 
    COUNT(*) as total_assignments,
    COUNT(ca.actual_hours) as assignments_with_actual_hours,
    COUNT(CASE WHEN ca.actual_hours IS NOT NULL AND ca.actual_hours > 0 THEN 1 END) as assignments_with_positive_actual_hours,
    ROUND(COUNT(ca.actual_hours) * 100.0 / COUNT(*), 2) as percentage_with_actual_hours
FROM client_assignments ca
JOIN work_days wd ON ca.work_day_id = wd.id
JOIN employees e ON wd.employee_id = e.id
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d';