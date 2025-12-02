-- Migration to fix performance index calculation
-- This fixes the issue where "earned" column showed gross revenue instead of net revenue

-- Drop the existing function
DROP FUNCTION IF EXISTS get_performance_index(UUID);

-- Create the corrected function
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

-- Test the fix with your data
-- Run this query to verify the fix:
/*
WITH appointment_totals AS (
    SELECT 
        a.id as appointment_id,
        a.cost,
        SUM(ca.actual_hours) as total_hours_on_appointment
    FROM appointments a
    LEFT JOIN client_assignments ca ON a.id = ca.appointment_id
    WHERE a.period_id = 'YOUR_PERIOD_ID' -- Replace with your period ID
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
    WHERE a.period_id = 'YOUR_PERIOD_ID' -- Replace with your period ID
)
SELECT 
    wd.id as work_day_id,
    e.name as employee_name,
    wd.work_date,
    SUM(ra.allocated_revenue) as net_earned,
    SUM(ra.gross_revenue) as gross_earned,
    SUM(ra.transportation_cost) as total_transport_cost,
    wd.hours_worked,
    ROUND((SUM(ra.allocated_revenue) / NULLIF(wd.hours_worked, 0))::numeric, 2) as performance_index
FROM work_days wd
JOIN employees e ON wd.employee_id = e.id
LEFT JOIN revenue_allocation ra ON wd.id = ra.work_day_id
WHERE wd.hours_worked > 0 AND e.period_id = 'YOUR_PERIOD_ID' -- Replace with your period ID
GROUP BY wd.id, e.name, wd.work_date, wd.hours_worked
ORDER BY performance_index DESC;
*/
