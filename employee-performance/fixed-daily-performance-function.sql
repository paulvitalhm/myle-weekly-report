-- Fixed Daily Performance Report Function
-- Corrected type mismatch for worker_count

-- Drop the existing function if it exists
DROP FUNCTION IF EXISTS get_daily_performance_index(UUID);

-- Create the corrected function
CREATE OR REPLACE FUNCTION get_daily_performance_index(p_period_id UUID)
RETURNS TABLE (
    rank BIGINT,
    index NUMERIC,
    day_date DATE,
    total_earned NUMERIC,
    total_hours NUMERIC,
    worker_count INTEGER,  -- Changed from BIGINT to INTEGER
    customer_list TEXT,
    performance_tier TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH daily_totals AS (
        -- Calculate total revenue and total hours for each work day
        SELECT 
            wd.work_date,
            SUM(a.cost) as total_revenue,
            SUM(wd.hours_worked) as total_hours,
            COUNT(DISTINCT e.id)::INTEGER as worker_count,  -- Cast to INTEGER
            STRING_AGG(DISTINCT a.customer_name, ', ') as customer_list
        FROM work_days wd
        JOIN employees e ON wd.employee_id = e.id
        JOIN client_assignments ca ON wd.id = ca.work_day_id
        JOIN appointments a ON ca.appointment_id = a.id
        WHERE e.period_id = p_period_id
        GROUP BY wd.work_date
        HAVING SUM(wd.hours_worked) > 0  -- Only include days with work
    ),
    performance_calculation AS (
        -- Calculate performance index and determine tier
        SELECT 
            dt.work_date,
            dt.total_revenue,
            dt.total_hours,
            dt.worker_count,
            dt.customer_list,
            ROUND((dt.total_revenue / dt.total_hours)::numeric, 2) as performance_index,
            CASE 
                WHEN (dt.total_revenue / dt.total_hours) >= 47 THEN 'top'
                WHEN (dt.total_revenue / dt.total_hours) >= 35 THEN 'good'
                ELSE 'needs-improvement'
            END as performance_tier
        FROM daily_totals dt
    )
    SELECT 
        ROW_NUMBER() OVER (ORDER BY pc.performance_index DESC) as rank,
        pc.performance_index as index,
        pc.work_date as day_date,
        ROUND(pc.total_revenue::numeric, 2) as total_earned,
        pc.total_hours::numeric,
        pc.worker_count,
        pc.customer_list,
        pc.performance_tier
    FROM performance_calculation pc
    ORDER BY pc.performance_index DESC;
END;
$$ LANGUAGE plpgsql;

-- Test the fixed daily performance function
SELECT * FROM get_daily_performance_index('91a20127-5cda-4220-a405-791640417f5d')
ORDER BY day_date;

-- Verification queries
-- Check specific days to verify calculations
-- November 15, 2025: Should be $237.50 / 6.17 = 38.49
SELECT 
    wd.work_date,
    SUM(a.cost) as total_revenue,
    SUM(wd.hours_worked) as total_hours,
    COUNT(DISTINCT e.id) as worker_count,
    ROUND((SUM(a.cost) / SUM(wd.hours_worked))::numeric, 2) as performance_index,
    CASE 
        WHEN (SUM(a.cost) / SUM(wd.hours_worked)) >= 47 THEN 'top'
        WHEN (SUM(a.cost) / SUM(wd.hours_worked)) >= 35 THEN 'good'
        ELSE 'needs-improvement'
    END as performance_tier
FROM work_days wd
JOIN employees e ON wd.employee_id = e.id
JOIN client_assignments ca ON wd.id = ca.work_day_id
JOIN appointments a ON ca.appointment_id = a.id
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
  AND wd.work_date = '2025-11-15'
GROUP BY wd.work_date;

-- November 10, 2025: Should be $200 / 8.75 = 22.85
SELECT 
    wd.work_date,
    SUM(a.cost) as total_revenue,
    SUM(wd.hours_worked) as total_hours,
    COUNT(DISTINCT e.id) as worker_count,
    ROUND((SUM(a.cost) / SUM(wd.hours_worked))::numeric, 2) as performance_index,
    CASE 
        WHEN (SUM(a.cost) / SUM(wd.hours_worked)) >= 47 THEN 'top'
        WHEN (SUM(a.cost) / SUM(wd.hours_worked)) >= 35 THEN 'good'
        ELSE 'needs-improvement'
    END as performance_tier
FROM work_days wd
JOIN employees e ON wd.employee_id = e.id
JOIN client_assignments ca ON wd.id = ca.work_day_id
JOIN appointments a ON ca.appointment_id = a.id
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
  AND wd.work_date = '2025-11-10'
GROUP BY wd.work_date;

-- Check all days in the period
SELECT 
    wd.work_date,
    SUM(a.cost) as total_revenue,
    SUM(wd.hours_worked) as total_hours,
    COUNT(DISTINCT e.id) as worker_count,
    ROUND((SUM(a.cost) / SUM(wd.hours_worked))::numeric, 2) as performance_index,
    CASE 
        WHEN (SUM(a.cost) / SUM(wd.hours_worked)) >= 47 THEN 'top'
        WHEN (SUM(a.cost) / SUM(wd.hours_worked)) >= 35 THEN 'good'
        ELSE 'needs-improvement'
    END as performance_tier
FROM work_days wd
JOIN employees e ON wd.employee_id = e.id
JOIN client_assignments ca ON wd.id = ca.work_day_id
JOIN appointments a ON ca.appointment_id = a.id
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
GROUP BY wd.work_date
HAVING SUM(wd.hours_worked) > 0
ORDER BY wd.work_date;