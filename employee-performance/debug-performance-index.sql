-- Debug Performance Index Calculations
-- Period ID: 91a20127-5cda-4220-a405-791640417f5d

-- 1. Get basic performance index data for Paul and Mariana
SELECT 
    who,
    index,
    earned,
    hours_worked,
    work_date,
    rank
FROM get_performance_index('91a20127-5cda-4220-a405-791640417f5d')
WHERE who ILIKE '%paul%' OR who ILIKE '%mariana%';

-- 2. Get detailed work day data for Paul and Mariana
SELECT 
    wd.work_date,
    e.name as employee_name,
    wd.hours_worked,
    wd.id as work_day_id
FROM work_days wd
JOIN employees e ON wd.employee_id = e.id
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
  AND (e.name ILIKE '%paul%' OR e.name ILIKE '%mariana%')
ORDER BY wd.work_date, e.name;

-- 3. Get detailed assignment data for Paul and Mariana
SELECT 
    ca.id,
    ca.actual_hours,
    ca.transportation_cost,
    wd.work_date,
    e.name as employee_name,
    wd.hours_worked as total_work_day_hours,
    a.customer_name,
    a.cost as appointment_cost,
    a.appointment_date
FROM client_assignments ca
JOIN work_days wd ON ca.work_day_id = wd.id
JOIN employees e ON wd.employee_id = e.id
JOIN appointments a ON ca.appointment_id = a.id
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
  AND (e.name ILIKE '%paul%' OR e.name ILIKE '%mariana%')
ORDER BY wd.work_date, e.name, a.appointment_date;

-- 4. Get revenue allocation breakdown for specific work days
SELECT 
    wd.work_date,
    e.name as employee_name,
    wd.hours_worked as total_hours,
    a.customer_name,
    a.cost as appointment_cost,
    ca.actual_hours as assigned_hours,
    ca.transportation_cost,
    -- Calculate revenue allocation
    CASE 
        WHEN ca.actual_hours IS NULL OR ca.actual_hours = 0 THEN 0
        ELSE ROUND((ca.actual_hours / NULLIF(SUM(ca.actual_hours) OVER (PARTITION BY a.id), 0)) * a.cost - COALESCE(ca.transportation_cost, 0), 2)
    END as calculated_revenue,
    -- Calculate Paul's share if we use total hours method
    CASE 
        WHEN e.name ILIKE '%paul%' THEN ROUND((ca.actual_hours / NULLIF(wd.hours_worked, 0)) * a.cost - COALESCE(ca.transportation_cost, 0), 2)
        ELSE ROUND((ca.actual_hours / NULLIF(SUM(ca.actual_hours) OVER (PARTITION BY a.id), 0)) * a.cost - COALESCE(ca.transportation_cost, 0), 2)
    END as paul_share_method
FROM client_assignments ca
JOIN work_days wd ON ca.work_day_id = wd.id
JOIN employees e ON wd.employee_id = e.id
JOIN appointments a ON ca.appointment_id = a.id
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
  AND (e.name ILIKE '%paul%' OR e.name ILIKE '%mariana%')
ORDER BY wd.work_date, e.name, a.appointment_date;

-- 5. Debug the specific calculation for the day in question
-- Replace '2024-11-15' with the actual date you're seeing
SELECT 
    wd.work_date,
    e.name as employee_name,
    wd.hours_worked,
    SUM(a.cost) as total_appointment_revenue,
    SUM(ca.actual_hours) as total_assigned_hours,
    SUM(ca.transportation_cost) as total_transport_cost,
    -- Calculate what the system should give
    CASE 
        WHEN SUM(ca.actual_hours) > 0 THEN 
            ROUND((SUM(a.cost) - SUM(ca.transportation_cost)) / wd.hours_worked, 2)
        ELSE 0
    END as expected_index,
    -- Calculate what Paul should get
    CASE 
        WHEN e.name ILIKE '%paul%' AND wd.hours_worked > 0 THEN
            ROUND((SUM(a.cost) - SUM(ca.transportation_cost)) / wd.hours_worked, 2)
        ELSE 0
    END as paul_expected_index
FROM client_assignments ca
JOIN work_days wd ON ca.work_day_id = wd.id
JOIN employees e ON wd.employee_id = e.id
JOIN appointments a ON ca.appointment_id = a.id
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
  AND (e.name ILIKE '%paul%' OR e.name ILIKE '%mariana%')
GROUP BY wd.work_date, e.name, wd.hours_worked
ORDER BY wd.work_date, e.name;

-- 6. Check the raw function output vs expected
SELECT 
    who,
    index,
    earned,
    hours_worked,
    work_date,
    -- Manual calculation for verification
    CASE 
        WHEN hours_worked > 0 THEN ROUND(earned / hours_worked, 2)
        ELSE 0
    END as manual_index_calculation
FROM get_performance_index('91a20127-5cda-4220-a405-791640417f5d')
WHERE who ILIKE '%paul%' OR who ILIKE '%mariana%';
