-- Corrected Daily Performance Report Function
-- Fixed double-counting issue by using DISTINCT on appointments and work days

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
    worker_count INTEGER,
    customer_list TEXT,
    performance_tier TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH daily_appointments AS (
        -- Get DISTINCT appointments per day to avoid double-counting
        SELECT DISTINCT
            wd.work_date,
            a.id as appointment_id,
            a.cost,
            a.customer_name
        FROM work_days wd
        JOIN employees e ON wd.employee_id = e.id
        JOIN client_assignments ca ON wd.id = ca.work_day_id
        JOIN appointments a ON ca.appointment_id = a.id
        WHERE e.period_id = p_period_id
    ),
    daily_work_days AS (
        -- Get DISTINCT work days to avoid double-counting hours
        SELECT DISTINCT
            wd.work_date,
            wd.id as work_day_id,
            wd.hours_worked,
            e.id as employee_id
        FROM work_days wd
        JOIN employees e ON wd.employee_id = e.id
        WHERE e.period_id = p_period_id
    ),
    daily_totals AS (
        -- Calculate total revenue and total hours for each work day without double-counting
        SELECT 
            da.work_date,
            SUM(da.cost) as total_revenue,
            SUM(dwd.hours_worked) as total_hours,
            COUNT(DISTINCT dwd.employee_id)::INTEGER as worker_count,
            STRING_AGG(DISTINCT da.customer_name, ', ') as customer_list
        FROM daily_appointments da
        JOIN daily_work_days dwd ON da.work_date = dwd.work_date
        GROUP BY da.work_date
        HAVING SUM(dwd.hours_worked) > 0  -- Only include days with work
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

-- Test the corrected daily performance function
SELECT * FROM get_daily_performance_index('91a20127-5cda-4220-a405-791640417f5d')
ORDER BY day_date;

-- Verification queries to ensure no double-counting
-- Check November 15, 2025: Should be $237.50 / 6.17 = 38.49
WITH daily_appointments AS (
    SELECT DISTINCT
        wd.work_date,
        a.id as appointment_id,
        a.cost,
        a.customer_name
    FROM work_days wd
    JOIN employees e ON wd.employee_id = e.id
    JOIN client_assignments ca ON wd.id = ca.work_day_id
    JOIN appointments a ON ca.appointment_id = a.id
    WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
      AND wd.work_date = '2025-11-15'
),
daily_work_days AS (
    SELECT DISTINCT
        wd.work_date,
        wd.id as work_day_id,
        wd.hours_worked,
        e.id as employee_id
    FROM work_days wd
    JOIN employees e ON wd.employee_id = e.id
    WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
      AND wd.work_date = '2025-11-15'
)
SELECT 
    da.work_date,
    SUM(da.cost) as total_revenue,
    SUM(dwd.hours_worked) as total_hours,
    COUNT(DISTINCT dwd.employee_id) as worker_count,
    ROUND((SUM(da.cost) / SUM(dwd.hours_worked))::numeric, 2) as performance_index
FROM daily_appointments da
JOIN daily_work_days dwd ON da.work_date = dwd.work_date
GROUP BY da.work_date;

-- Check what appointments are actually on November 15, 2025
SELECT DISTINCT
    a.customer_name,
    a.cost
FROM appointments a
JOIN client_assignments ca ON a.id = ca.appointment_id
JOIN work_days wd ON ca.work_day_id = wd.id
JOIN employees e ON wd.employee_id = e.id
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
  AND wd.work_date = '2025-11-15'
ORDER BY a.customer_name;

-- Check what work days are on November 15, 2025
SELECT 
    e.name,
    wd.hours_worked
FROM work_days wd
JOIN employees e ON wd.employee_id = e.id
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
  AND wd.work_date = '2025-11-15'
ORDER BY e.name;