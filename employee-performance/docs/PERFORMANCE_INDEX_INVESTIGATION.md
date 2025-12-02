# Performance Index Investigation: Paul & Mariana Discrepancy

## Problem Statement
- **Expected**: Both Paul and Mariana should have performance index of 45.9 on November 15, 2025
- **Actual**: Paul shows 24.31, Mariana shows 41.67
- **Discrepancy**: Significant deviation from expected values

## Investigation Plan

### Step 1: Current Performance Index Data
Run this SQL query to get current performance index data:

```sql
-- Get current performance index for Paul and Mariana
SELECT 
    who,
    index,
    earned,
    hours_worked,
    work_date,
    -- Manual verification
    CASE 
        WHEN hours_worked > 0 THEN ROUND(earned / hours_worked, 2)
        ELSE 0 
    END as manual_calculation
FROM get_performance_index('91a20127-5cda-4220-a405-791640417f5d')
WHERE who ILIKE '%paul%' OR who ILIKE '%mariana%'
ORDER BY work_date, who;
```

### Step 2: Detailed Assignment Analysis
Examine the specific assignments for November 15, 2025:

```sql
-- Detailed assignment data for November 15, 2025
SELECT 
    ca.id,
    e.name as employee_name,
    wd.work_date,
    wd.hours_worked as total_day_hours,
    ca.actual_hours as assigned_hours,
    ca.transportation_cost,
    a.customer_name,
    a.cost as appointment_cost,
    a.appointment_date,
    ca.arrival_delay_minutes,
    ca.early_departure_minutes
FROM client_assignments ca
JOIN work_days wd ON ca.work_day_id = wd.id
JOIN employees e ON wd.employee_id = e.id
JOIN appointments a ON ca.appointment_id = a.id
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
  AND wd.work_date = '2025-11-15'
  AND (e.name ILIKE '%paul%' OR e.name ILIKE '%mariana%')
ORDER BY e.name, a.appointment_date;
```

### Step 3: Revenue Allocation Breakdown
Analyze how revenue is being allocated:

```sql
-- Revenue allocation breakdown for November 15, 2025
WITH appointment_totals AS (
    SELECT 
        a.id as appointment_id,
        a.cost,
        SUM(ca.actual_hours) as total_hours_on_appointment
    FROM appointments a
    LEFT JOIN client_assignments ca ON a.id = ca.appointment_id
    WHERE a.period_id = '91a20127-5cda-4220-a405-791640417f5d'
      AND a.appointment_date = '2025-11-15'
    GROUP BY a.id, a.cost
),
revenue_allocation AS (
    SELECT 
        ca.work_day_id,
        e.name as employee_name,
        a.customer_name,
        ca.actual_hours,
        ca.transportation_cost,
        at.total_hours_on_appointment,
        at.cost as appointment_cost,
        ((ca.actual_hours / NULLIF(at.total_hours_on_appointment, 0)) * at.cost) as gross_revenue,
        COALESCE(ca.transportation_cost, 0) as transport_deduction,
        ((ca.actual_hours / NULLIF(at.total_hours_on_appointment, 0)) * at.cost) - COALESCE(ca.transportation_cost, 0) as net_revenue
    FROM client_assignments ca
    JOIN appointments a ON ca.appointment_id = a.id
    JOIN work_days wd ON ca.work_day_id = wd.id
    JOIN employees e ON wd.employee_id = e.id
    JOIN appointment_totals at ON a.id = at.appointment_id
    WHERE a.period_id = '91a20127-5cda-4220-a405-791640417f5d'
      AND wd.work_date = '2025-11-15'
      AND (e.name ILIKE '%paul%' OR e.name ILIKE '%mariana%')
)
SELECT 
    employee_name,
    customer_name,
    actual_hours,
    appointment_cost,
    total_hours_on_appointment,
    gross_revenue,
    transport_deduction,
    net_revenue,
    CASE 
        WHEN gross_revenue > 0 THEN ROUND((transport_deduction / gross_revenue) * 100, 2)
        ELSE 0 
    END as deduction_percentage
FROM revenue_allocation
ORDER BY employee_name, net_revenue DESC;
```

### Step 4: Manual Calculation Verification
Verify what the performance index should be according to the formula:

```sql
-- Manual calculation based on the documented formula
WITH day_totals AS (
    SELECT 
        wd.work_date,
        SUM(a.cost) as total_revenue,
        SUM(wd.hours_worked) as total_hours
    FROM work_days wd
    JOIN employees e ON wd.employee_id = e.id
    JOIN client_assignments ca ON wd.id = ca.work_day_id
    JOIN appointments a ON ca.appointment_id = a.id
    WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
      AND wd.work_date = '2025-11-15'
      AND (e.name ILIKE '%paul%' OR e.name ILIKE '%mariana%')
    GROUP BY wd.work_date
),
employee_assignments AS (
    SELECT 
        wd.work_date,
        e.name as employee_name,
        wd.hours_worked,
        SUM(a.cost) as total_appointment_revenue,
        SUM(ca.transportation_cost) as total_transport_cost
    FROM work_days wd
    JOIN employees e ON wd.employee_id = e.id
    LEFT JOIN client_assignments ca ON wd.id = ca.work_day_id
    LEFT JOIN appointments a ON ca.appointment_id = a.id
    WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
      AND wd.work_date = '2025-11-15'
      AND (e.name ILIKE '%paul%' OR e.name ILIKE '%mariana%')
    GROUP BY wd.work_date, e.name, wd.hours_worked
)
SELECT 
    ea.employee_name,
    ea.hours_worked,
    dt.total_revenue,
    dt.total_hours,
    ea.total_appointment_revenue,
    ea.total_transport_cost,
    -- Expected calculation per formula: (hours_worked / total_hours) * total_revenue - transport_cost
    ROUND(
        ((ea.hours_worked / NULLIF(dt.total_hours, 0)) * dt.total_revenue) - 
        COALESCE(ea.total_transport_cost, 0), 
        2
    ) as expected_earned,
    ROUND(
        (((ea.hours_worked / NULLIF(dt.total_hours, 0)) * dt.total_revenue) - 
         COALESCE(ea.total_transport_cost, 0)) / NULLIF(ea.hours_worked, 0), 
        2
    ) as expected_index
FROM employee_assignments ea
CROSS JOIN day_totals dt
ORDER BY ea.employee_name;
```

## Potential Root Causes

1. **Transportation Costs**: High transportation costs reducing net revenue
2. **Hours Allocation**: Incorrect actual_hours allocation between employees
3. **Revenue Distribution**: Revenue not being distributed proportionally to hours worked
4. **Missing Data**: Some appointments not assigned or missing assignments
5. **Function Logic**: Performance index function not following the documented formula

## Next Steps

1. Run the above queries to identify the specific issue
2. Compare the manual calculations with system calculations
3. Check if transportation costs are disproportionately affecting one employee
4. Verify that revenue is being allocated proportionally to hours worked
5. Update the performance index function if needed

## Expected Results Based on Formula

According to the performance index formula documentation:
- **Total Revenue**: $237.50 (House 1: $150 + House 2: $87.50)
- **Mariana's Hours**: 5.17 hours
- **Paul's Hours**: 1 hour
- **Performance Index**: $237.50 ÷ 5.17 = 45.9 for both (since we don't have house-specific hours)

If the actual data differs from this scenario, the calculations will need to be adjusted accordingly.