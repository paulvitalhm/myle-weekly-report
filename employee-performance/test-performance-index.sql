-- Test Performance Index Calculation with Transportation Costs
-- This query helps verify that transportation costs are properly deducted

-- Step 1: Check current assignments with transportation costs
SELECT 
    ca.id,
    e.name as employee_name,
    a.customer_name,
    ca.actual_hours,
    ca.arrival_delay_minutes,
    ca.early_departure_minutes,
    ca.transportation_cost,
    a.cost as appointment_cost,
    wd.hours_worked as work_day_hours
FROM client_assignments ca
JOIN work_days wd ON ca.work_day_id = wd.id
JOIN employees e ON wd.employee_id = e.id
JOIN appointments a ON ca.appointment_id = a.id
WHERE e.period_id = 'YOUR_PERIOD_ID_HERE' -- Replace with actual period ID
ORDER BY e.name, wd.work_date;

-- Step 2: Check the revenue allocation calculation manually
WITH appointment_totals AS (
    SELECT 
        a.id as appointment_id,
        a.cost,
        SUM(ca.actual_hours) as total_hours_on_appointment
    FROM appointments a
    LEFT JOIN client_assignments ca ON a.id = ca.appointment_id
    WHERE a.period_id = 'YOUR_PERIOD_ID_HERE' -- Replace with actual period ID
    GROUP BY a.id, a.cost
),
revenue_allocation AS (
    SELECT 
        ca.work_day_id,
        a.customer_name,
        ca.actual_hours,
        ca.transportation_cost,
        at.total_hours_on_appointment,
        ((ca.actual_hours / NULLIF(at.total_hours_on_appointment, 0)) * at.cost) as gross_revenue,
        COALESCE(ca.transportation_cost, 0) as transport_deduction,
        ((ca.actual_hours / NULLIF(at.total_hours_on_appointment, 0)) * at.cost) - COALESCE(ca.transportation_cost, 0) as net_revenue
    FROM client_assignments ca
    JOIN appointments a ON ca.appointment_id = a.id
    JOIN appointment_totals at ON a.id = at.appointment_id
    WHERE a.period_id = 'YOUR_PERIOD_ID_HERE' -- Replace with actual period ID
)
SELECT 
    work_day_id,
    customer_name,
    actual_hours,
    transportation_cost,
    gross_revenue,
    transport_deduction,
    net_revenue,
    CASE 
        WHEN gross_revenue > 0 THEN ROUND((transport_deduction / gross_revenue) * 100, 2)
        ELSE 0 
    END as deduction_percentage
FROM revenue_allocation
WHERE transportation_cost > 0
ORDER BY work_day_id, net_revenue DESC;

-- Step 3: Check final performance index calculation
SELECT * FROM get_performance_index('YOUR_PERIOD_ID_HERE'); -- Replace with actual period ID
