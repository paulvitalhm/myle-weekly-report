# Performance Index Investigation - Action Plan

## Summary of Findings

### Current Issue
- **Paul Vital**: Expected 45.9, Actual 24.31 (Difference: -21.59)
- **Mariana**: Expected 45.9, Actual 41.67 (Difference: -4.23)
- **Period ID**: `91a20127-5cda-4220-a405-791640417f5d`
- **Date**: November 15, 2025

### Key Insights from Analysis

1. **Function Logic Mismatch**: The current [`get_performance_index()`](employee-performance/supabase-schema.sql:394) function uses appointment-specific hours for revenue allocation, but the documented formula requires total day hours when house-specific hours are unknown.

2. **Transportation Cost Impact**: High transportation costs could disproportionately affect one employee's net revenue.

3. **Revenue Distribution**: The current method distributes revenue per appointment, while the formula suggests proportional distribution based on total hours worked.

## Immediate Investigation Steps

### Step 1: Run Diagnostic Queries

Execute these queries in your Supabase SQL Editor to gather current data:

```sql
-- 1. Current Performance Index Values
SELECT * FROM get_performance_index('91a20127-5cda-4220-a405-791640417f5d')
WHERE who ILIKE '%paul%' OR who ILIKE '%mariana%'
AND work_date = '2025-11-15';

-- 2. Assignment Details with Transportation Costs
SELECT 
    e.name,
    wd.work_date,
    wd.hours_worked,
    ca.actual_hours,
    ca.transportation_cost,
    a.customer_name,
    a.cost as appointment_cost
FROM employees e
JOIN work_days wd ON e.id = wd.employee_id
LEFT JOIN client_assignments ca ON wd.id = ca.work_day_id
LEFT JOIN appointments a ON ca.appointment_id = a.id
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
  AND (e.name ILIKE '%paul%' OR e.name ILIKE '%mariana%')
  AND wd.work_date = '2025-11-15';
```

### Step 2: Compare Calculation Methods

```sql
-- Compare current vs formula-based calculations
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
    -- Current system calculation
    (SELECT index FROM get_performance_index('91a20127-5cda-4220-a405-791640417f5d') 
     WHERE work_day_id = wd.id) as current_index,
    -- Formula-based calculation (proportional to total hours)
    ROUND(
        ((wd.hours_worked / dt.total_hours) * dt.total_revenue) / 
        NULLIF(wd.hours_worked, 0), 
        2
    ) as formula_index,
    -- Difference
    ROUND(
        ((wd.hours_worked / dt.total_hours) * dt.total_revenue) / 
        NULLIF(wd.hours_worked, 0) - 
        (SELECT index FROM get_performance_index('91a20127-5cda-4220-a405-791640417f5d') 
         WHERE work_day_id = wd.id), 
        2
    ) as difference
FROM work_days wd
JOIN employees e ON wd.employee_id = e.id
CROSS JOIN day_totals dt
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
  AND wd.work_date = '2025-11-15'
  AND (e.name ILIKE '%paul%' OR e.name ILIKE '%mariana%');
```

## Potential Solutions

### Option A: Fix Current Function Logic
If the current function logic is incorrect, modify the [`get_performance_index()`](employee-performance/supabase-schema.sql:394) function to use total day hours for revenue allocation when appointment-specific hours are not available.

### Option B: Update Data Assignments
If the issue is with data (transportation costs, actual_hours), update the client_assignments table with correct values.

### Option C: Clarify Formula Interpretation
If the current function logic is correct but the documented formula is being misinterpreted, update the documentation to clarify the calculation method.

## Recommended Approach

1. **First**: Run the diagnostic queries to identify the exact cause
2. **Second**: Based on results, determine if it's a data issue or function logic issue
3. **Third**: Implement the appropriate fix
4. **Fourth**: Test thoroughly to ensure calculations match expectations

## Expected Root Causes (Ranked by Likelihood)

1. **High Transportation Costs**: Paul may have significant transportation costs reducing his net revenue
2. **Incorrect Hours Allocation**: actual_hours may not reflect the intended distribution
3. **Missing Assignments**: Some appointments may not be assigned to the correct employees
4. **Function Logic Error**: The performance index function may not implement the formula correctly

## Next Actions

1. Execute the diagnostic queries in the Supabase SQL Editor
2. Compare the results with the expected values (45.9 for both)
3. Identify which of the potential root causes is affecting the calculations
4. Implement the appropriate fix based on the findings

## Success Criteria

- Both Paul and Mariana show performance index of 45.9 (or the correct calculated value based on actual data)
- The calculation method aligns with the documented formula
- Transportation costs and other deductions are properly accounted for
- The fix maintains data integrity and doesn't affect other periods or employees