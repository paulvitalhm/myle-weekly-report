-- Enhanced Daily Performance Report Function
-- Includes worker details, appointment revenue breakdown, and chronological ordering

-- Drop the existing function if it exists
DROP FUNCTION IF EXISTS get_daily_performance_index(UUID);

-- Create the enhanced function
CREATE OR REPLACE FUNCTION get_daily_performance_index(p_period_id UUID)
RETURNS TABLE (
    rank BIGINT,
    index NUMERIC,
    day_date DATE,
    total_earned NUMERIC,
    total_hours NUMERIC,
    worker_count INTEGER,
    customer_list TEXT,
    performance_tier TEXT,
    worker_details JSONB,
    appointment_details JSONB
) AS $$
BEGIN
    RETURN QUERY
    WITH daily_appointments AS (
        -- Get DISTINCT appointments per day with individual costs
        SELECT
            wd.work_date,
            SUM(DISTINCT a.cost) as total_revenue,
            STRING_AGG(DISTINCT a.customer_name, ', ') as customer_list,
            JSONB_AGG(DISTINCT JSONB_BUILD_OBJECT(
                'customer_name', a.customer_name,
                'cost', a.cost
            )) as appointment_details
        FROM work_days wd
        JOIN employees e ON wd.employee_id = e.id
        JOIN client_assignments ca ON wd.id = ca.work_day_id
        JOIN appointments a ON ca.appointment_id = a.id
        WHERE e.period_id = p_period_id
        GROUP BY wd.work_date
    ),
    daily_work_days AS (
        -- Get total hours and worker count per day with individual worker details
        SELECT
            wd.work_date,
            SUM(DISTINCT wd.hours_worked) as total_hours,
            COUNT(DISTINCT e.id)::INTEGER as worker_count,
            JSONB_AGG(DISTINCT JSONB_BUILD_OBJECT(
                'employee_name', e.name,
                'hours_worked', wd.hours_worked
            )) as worker_details
        FROM work_days wd
        JOIN employees e ON wd.employee_id = e.id
        WHERE e.period_id = p_period_id
        GROUP BY wd.work_date
        HAVING SUM(wd.hours_worked) > 0  -- Only include days with work
    ),
    daily_totals AS (
        -- Combine appointment and work day data
        SELECT
            COALESCE(da.work_date, dwd.work_date) as work_date,
            COALESCE(da.total_revenue, 0) as total_revenue,
            COALESCE(da.customer_list, 'No appointments') as customer_list,
            COALESCE(da.appointment_details, '[]'::JSONB) as appointment_details,
            COALESCE(dwd.total_hours, 0) as total_hours,
            COALESCE(dwd.worker_count, 0) as worker_count,
            COALESCE(dwd.worker_details, '[]'::JSONB) as worker_details
        FROM daily_appointments da
        FULL OUTER JOIN daily_work_days dwd ON da.work_date = dwd.work_date
        WHERE COALESCE(dwd.total_hours, 0) > 0  -- Only include days with work
    ),
    performance_calculation AS (
        -- Calculate performance index and determine tier
        SELECT
            dt.work_date,
            dt.total_revenue,
            dt.total_hours,
            dt.worker_count,
            dt.customer_list,
            dt.worker_details,
            dt.appointment_details,
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
        pc.performance_tier,
        pc.worker_details,
        pc.appointment_details
    FROM performance_calculation pc
    ORDER BY pc.work_date ASC;  -- Changed to chronological order
END;
$$ LANGUAGE plpgsql;

-- Test the final daily performance function
SELECT * FROM get_daily_performance_index('91a20127-5cda-4220-a405-791640417f5d')
ORDER BY day_date;

-- Simple verification query for November 15, 2025
-- Should be $237.50 / 6.17 = 38.49
SELECT 
    wd.work_date,
    SUM(DISTINCT a.cost) as total_revenue,
    SUM(wd.hours_worked) as total_hours,
    COUNT(DISTINCT e.id) as worker_count,
    ROUND((SUM(DISTINCT a.cost) / SUM(wd.hours_worked))::numeric, 2) as performance_index
FROM work_days wd
JOIN employees e ON wd.employee_id = e.id
JOIN client_assignments ca ON wd.id = ca.work_day_id
JOIN appointments a ON ca.appointment_id = a.id
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
  AND wd.work_date = '2025-11-15'
GROUP BY wd.work_date;

-- Check what appointments exist on November 15, 2025
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

-- Check work days on November 15, 2025
SELECT 
    e.name,
    wd.hours_worked
FROM work_days wd
JOIN employees e ON wd.employee_id = e.id
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
  AND wd.work_date = '2025-11-15'
ORDER BY e.name;