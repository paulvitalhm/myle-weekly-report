-- Hybrid Individual Efficiency Function
-- This provides meaningful individual performance measurement without per-appointment time tracking

-- Drop the existing function
DROP FUNCTION IF EXISTS get_performance_index(UUID);

-- Create the hybrid efficiency function
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
    WITH appointment_workers AS (
        -- Count workers per appointment for the period
        SELECT 
            a.id as appointment_id,
            COUNT(ca.id) as worker_count
        FROM appointments a
        JOIN client_assignments ca ON a.id = ca.appointment_id
        JOIN work_days wd ON ca.work_day_id = wd.id
        JOIN employees e ON wd.employee_id = e.id
        WHERE e.period_id = p_period_id
        GROUP BY a.id
    ),
    revenue_allocation AS (
        -- Allocate revenue using hybrid method
        SELECT 
            ca.work_day_id,
            e.name as employee_name,
            wd.hours_worked,
            ca.arrival_delay_minutes,
            ca.early_departure_minutes,
            a.customer_name,
            a.cost as appointment_cost,
            -- Hybrid allocation: solo appointments get full revenue, team appointments get equal split
            CASE 
                -- Solo appointment: full revenue to the worker
                WHEN aw.worker_count = 1 THEN a.cost
                -- Team appointment: equal split among workers
                ELSE a.cost / aw.worker_count
            END as base_revenue,
            -- Punctuality adjustment factor (0.8 to 1.0 range)
            CASE 
                WHEN (COALESCE(ca.arrival_delay_minutes, 0) + COALESCE(ca.early_departure_minutes, 0)) > 0 THEN
                    GREATEST(0.8, 1 - ((COALESCE(ca.arrival_delay_minutes, 0) + COALESCE(ca.early_departure_minutes, 0)) / (wd.hours_worked * 60 * 2)))
                ELSE 1.0
            END as punctuality_factor
        FROM client_assignments ca
        JOIN appointments a ON ca.appointment_id = a.id
        JOIN work_days wd ON ca.work_day_id = wd.id
        JOIN employees e ON wd.employee_id = e.id
        JOIN appointment_workers aw ON a.id = aw.appointment_id
        WHERE e.period_id = p_period_id
    ),
    daily_revenue AS (
        -- Calculate total earned per work day with punctuality adjustment
        SELECT 
            ra.work_day_id,
            ra.employee_name,
            SUM(ra.base_revenue * ra.punctuality_factor) as total_earned,
            MAX(ra.hours_worked) as hours_worked,
            STRING_AGG(DISTINCT ra.customer_name, ', ') as customer_list,
            SUM(ra.base_revenue) as gross_earned,
            SUM(ra.base_revenue * ra.punctuality_factor) - SUM(ra.base_revenue) as punctuality_adjustment
        FROM revenue_allocation ra
        GROUP BY ra.work_day_id, ra.employee_name
    )
    SELECT 
        ROW_NUMBER() OVER (ORDER BY (dr.total_earned / NULLIF(dr.hours_worked, 0)) DESC) as rank,
        ROUND((dr.total_earned / NULLIF(dr.hours_worked, 0))::numeric, 2) as index,
        dr.employee_name::VARCHAR as who,
        (TO_CHAR(wd.work_date, 'Dy, Mon DD YYYY') || ' (' || 
         FLOOR(dr.hours_worked)::text || 'h ' || 
         ROUND((dr.hours_worked - FLOOR(dr.hours_worked)) * 60)::int::text || 'm)')::TEXT as "when",
        COALESCE(dr.customer_list, 'Pending')::TEXT as "where",
        ROUND(dr.total_earned::numeric, 2) as earned,
        wd.id as work_day_id,
        wd.work_date,
        dr.hours_worked::numeric
    FROM daily_revenue dr
    JOIN work_days wd ON dr.work_day_id = wd.id
    WHERE dr.hours_worked > 0
    ORDER BY index DESC;
END;
$$ LANGUAGE plpgsql;

-- Test the hybrid efficiency function
SELECT * FROM get_performance_index('91a20127-5cda-4220-a405-791640417f5d')
WHERE who ILIKE '%paul%' OR who ILIKE '%mariana%' OR who ILIKE '%nanette%' OR who ILIKE '%soraya%'
ORDER BY work_date, who;

-- Compare with current data to see the difference
WITH current_data AS (
    SELECT 
        e.name,
        wd.work_date,
        wd.hours_worked,
        (SELECT index FROM get_performance_index('91a20127-5cda-4220-a405-791640417f5d') 
         WHERE work_day_id = wd.id) as hybrid_index,
        -- Calculate what the old proportional method would give
        (SELECT SUM(a.cost) FROM client_assignments ca 
         JOIN appointments a ON ca.appointment_id = a.id 
         WHERE ca.work_day_id = wd.id) as appointments_revenue
    FROM work_days wd
    JOIN employees e ON wd.employee_id = e.id
    WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
      AND (e.name ILIKE '%paul%' OR e.name ILIKE '%mariana%' OR e.name ILIKE '%nanette%' OR e.name ILIKE '%soraya%')
)
SELECT 
    name,
    work_date,
    hours_worked,
    hybrid_index,
    ROUND(appointments_revenue / hours_worked, 2) as proportional_index,
    hybrid_index - ROUND(appointments_revenue / hours_worked, 2) as difference
FROM current_data
WHERE appointments_revenue IS NOT NULL
ORDER BY work_date, name;

-- Analyze appointment distribution
SELECT 
    e.name,
    wd.work_date,
    COUNT(DISTINCT a.id) as total_appointments,
    COUNT(DISTINCT CASE WHEN aw.worker_count = 1 THEN a.id END) as solo_appointments,
    COUNT(DISTINCT CASE WHEN aw.worker_count > 1 THEN a.id END) as team_appointments,
    ROUND(COUNT(DISTINCT CASE WHEN aw.worker_count = 1 THEN a.id END) * 100.0 / COUNT(DISTINCT a.id), 2) as solo_percentage
FROM work_days wd
JOIN employees e ON wd.employee_id = e.id
JOIN client_assignments ca ON wd.id = ca.work_day_id
JOIN appointments a ON ca.appointment_id = a.id
JOIN (
    SELECT 
        a.id as appointment_id,
        COUNT(ca.id) as worker_count
    FROM appointments a
    JOIN client_assignments ca ON a.id = ca.appointment_id
    JOIN work_days wd ON ca.work_day_id = wd.id
    JOIN employees e ON wd.employee_id = e.id
    WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
    GROUP BY a.id
) aw ON a.id = aw.appointment_id
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
  AND (e.name ILIKE '%paul%' OR e.name ILIKE '%mariana%' OR e.name ILIKE '%nanette%' OR e.name ILIKE '%soraya%')
GROUP BY e.name, wd.work_date
ORDER BY wd.work_date, e.name;