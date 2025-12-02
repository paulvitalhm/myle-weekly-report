-- Fixed Performance Index Function
-- This implements the documented formula: allocate revenue proportionally to total day hours
-- when house-specific hours are unknown

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
    WITH work_day_totals AS (
        -- Calculate total revenue and total hours for each work day
        SELECT 
            wd.id as work_day_id,
            wd.work_date,
            SUM(a.cost) as total_day_revenue,
            SUM(wd.hours_worked) as total_day_hours
        FROM work_days wd
        JOIN employees e ON wd.employee_id = e.id
        JOIN client_assignments ca ON wd.id = ca.work_day_id
        JOIN appointments a ON ca.appointment_id = a.id
        WHERE e.period_id = p_period_id
        GROUP BY wd.id, wd.work_date
    ),
    revenue_allocation AS (
        -- Allocate revenue proportionally to hours worked on the day
        -- This implements the documented formula
        SELECT 
            wd.id as work_day_id,
            wdt.total_day_revenue,
            wdt.total_day_hours,
            wd.hours_worked,
            -- Calculate earned amount: (hours_worked / total_day_hours) * total_day_revenue - transportation_cost
            ROUND(
                ((wd.hours_worked / NULLIF(wdt.total_day_hours, 0)) * wdt.total_day_revenue) - 
                COALESCE(SUM(ca.transportation_cost), 0), 
                2
            ) as allocated_revenue
        FROM work_days wd
        JOIN employees e ON wd.employee_id = e.id
        JOIN work_day_totals wdt ON wd.id = wdt.work_day_id
        LEFT JOIN client_assignments ca ON wd.id = ca.work_day_id
        WHERE e.period_id = p_period_id
        GROUP BY wd.id, wdt.total_day_revenue, wdt.total_day_hours, wd.hours_worked
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
        ROW_NUMBER() OVER (ORDER BY (ra.allocated_revenue / NULLIF(wd.hours_worked, 0)) DESC) as rank,
        ROUND((ra.allocated_revenue / NULLIF(wd.hours_worked, 0))::numeric, 2) as index,
        e.name::VARCHAR as who,
        (TO_CHAR(wd.work_date, 'Dy, Mon DD YYYY') || ' (' || 
         FLOOR(wd.hours_worked)::text || 'h ' || 
         ROUND((wd.hours_worked - FLOOR(wd.hours_worked)) * 60)::int::text || 'm)')::TEXT as "when",
        COALESCE(cn.customer_list, 'Pending')::TEXT as "where",
        ra.allocated_revenue as earned,
        wd.id as work_day_id,
        wd.work_date,
        wd.hours_worked::numeric
    FROM work_days wd
    JOIN employees e ON wd.employee_id = e.id
    JOIN revenue_allocation ra ON wd.id = ra.work_day_id
    LEFT JOIN customer_names cn ON wd.id = cn.work_day_id
    WHERE wd.hours_worked > 0 
        AND e.period_id = p_period_id
    ORDER BY index DESC;
END;
$$ LANGUAGE plpgsql;

-- Test the fixed function
-- This should now show both Paul and Mariana with the same performance index for November 15, 2025
SELECT * FROM get_performance_index('91a20127-5cda-4220-a405-791640417f5d')
WHERE who ILIKE '%paul%' OR who ILIKE '%mariana%'
ORDER BY work_date, who;

-- Verification query to show the correct calculation
WITH day_totals AS (
    SELECT 
        SUM(a.cost) as total_revenue,
        SUM(wd.hours_worked) as total_hours
    FROM work_days wd
    JOIN employees e ON wd.employee_id = e.id
    JOIN client_assignments ca ON wd.id = ca.work_day_id
    JOIN appointments a ON ca.appointment_id = a.id
    WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
      AND wd.work_date = '2025-11-15'
      AND (e.name ILIKE '%paul%' OR e.name ILIKE '%mariana%')
)
SELECT 
    e.name,
    wd.hours_worked,
    dt.total_revenue,
    dt.total_hours,
    -- Correct allocation: proportional to total day hours
    ROUND((wd.hours_worked / dt.total_hours) * dt.total_revenue, 2) as correct_earned,
    ROUND(((wd.hours_worked / dt.total_hours) * dt.total_revenue) / wd.hours_worked, 2) as correct_index
FROM work_days wd
JOIN employees e ON wd.employee_id = e.id
CROSS JOIN day_totals dt
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
  AND wd.work_date = '2025-11-15'
  AND (e.name ILIKE '%paul%' OR e.name ILIKE '%mariana%');