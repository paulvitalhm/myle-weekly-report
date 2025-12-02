-- Precise Verification Query for November 15, 2025 ONLY
-- This query ONLY looks at data from November 15, 2025

WITH day_totals AS (
    -- Get total revenue and total hours ONLY for November 15, 2025
    SELECT 
        SUM(a.cost) as total_revenue,
        SUM(wd.hours_worked) as total_hours
    FROM work_days wd
    JOIN employees e ON wd.employee_id = e.id
    JOIN client_assignments ca ON wd.id = ca.work_day_id
    JOIN appointments a ON ca.appointment_id = a.id
    WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
      AND wd.work_date = '2025-11-15'  -- ONLY November 15, 2025
      AND (e.name ILIKE '%paul%' OR e.name ILIKE '%mariana%')
      AND a.appointment_date = '2025-11-15'  -- Ensure appointments are from same day
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
  AND wd.work_date = '2025-11-15'  -- ONLY November 15, 2025
  AND (e.name ILIKE '%paul%' OR e.name ILIKE '%mariana%');

-- Let's also check what appointments are actually assigned to November 15, 2025
SELECT 
    e.name,
    wd.work_date,
    a.customer_name,
    a.cost,
    a.appointment_date,
    ca.actual_hours
FROM work_days wd
JOIN employees e ON wd.employee_id = e.id
JOIN client_assignments ca ON wd.id = ca.work_day_id
JOIN appointments a ON ca.appointment_id = a.id
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
  AND wd.work_date = '2025-11-15'
  AND (e.name ILIKE '%paul%' OR e.name ILIKE '%mariana%')
ORDER BY e.name, a.customer_name;

-- Check if there are any other appointments on November 15, 2025 that might be included
SELECT 
    a.customer_name,
    a.cost,
    a.appointment_date,
    COUNT(ca.id) as assignment_count
FROM appointments a
LEFT JOIN client_assignments ca ON a.id = ca.appointment_id
LEFT JOIN work_days wd ON ca.work_day_id = wd.id
LEFT JOIN employees e ON wd.employee_id = e.id
WHERE a.period_id = '91a20127-5cda-4220-a405-791640417f5d'
  AND a.appointment_date = '2025-11-15'
GROUP BY a.customer_name, a.cost, a.appointment_date
ORDER BY a.customer_name;

-- Check work days for Paul and Mariana on November 15, 2025
SELECT 
    e.name,
    wd.work_date,
    wd.hours_worked
FROM work_days wd
JOIN employees e ON wd.employee_id = e.id
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
  AND wd.work_date = '2025-11-15'
  AND (e.name ILIKE '%paul%' OR e.name ILIKE '%mariana%');