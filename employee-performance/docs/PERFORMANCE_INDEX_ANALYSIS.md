# Performance Index Function Analysis

## Current Function Logic Review

Based on the [`get_performance_index()`](employee-performance/supabase-schema.sql:394) function in the schema, here's how the calculation works:

### Function Structure
```sql
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
```

### Key Calculation Steps

1. **Appointment Totals** (lines 408-417):
   ```sql
   WITH appointment_totals AS (
       SELECT 
           a.id as appointment_id,
           a.cost,
           SUM(ca.actual_hours) as total_hours_on_appointment
       FROM appointments a
       LEFT JOIN client_assignments ca ON a.id = ca.appointment_id
       WHERE a.period_id = p_period_id
       GROUP BY a.id, a.cost
   )
   ```

2. **Revenue Allocation** (lines 418-431):
   ```sql
   revenue_allocation AS (
       SELECT 
           ca.work_day_id,
           a.customer_name,
           ca.actual_hours,
           ca.transportation_cost,
           at.total_hours_on_appointment,
           ((ca.actual_hours / NULLIF(at.total_hours_on_appointment, 0)) * at.cost) - COALESCE(ca.transportation_cost, 0) as allocated_revenue,
           ((ca.actual_hours / NULLIF(at.total_hours_on_appointment, 0)) * at.cost) as gross_revenue
       FROM client_assignments ca
       JOIN appointments a ON ca.appointment_id = a.id
       JOIN appointment_totals at ON a.id = at.appointment_id
       WHERE a.period_id = p_period_id
   )
   ```

3. **Final Performance Index** (lines 432-450):
   ```sql
   SELECT 
       ROW_NUMBER() OVER (ORDER BY (SUM(COALESCE(ra.allocated_revenue, 0)) / NULLIF(wd.hours_worked, 0)) DESC) as rank,
       ROUND((SUM(COALESCE(ra.allocated_revenue, 0)) / NULLIF(wd.hours_worked, 0))::numeric, 2) as index,
       e.name::VARCHAR as who,
       -- ... other columns
       ROUND(SUM(COALESCE(ra.allocated_revenue, 0))::numeric, 2) as earned,
       wd.hours_worked::numeric
   FROM work_days wd
   JOIN employees e ON wd.employee_id = e.id
   LEFT JOIN revenue_allocation ra ON wd.id = ra.work_day_id
   WHERE wd.hours_worked > 0 
       AND e.period_id = p_period_id
   GROUP BY wd.id, wd.work_date, wd.employee_id, e.name, wd.hours_worked
   ORDER BY index DESC;
   ```

## Potential Issues Identified

### Issue 1: Revenue Allocation Method
The current function allocates revenue **per appointment** based on `actual_hours` spent on that specific appointment. However, the documented formula states:

> "Since we don't know hours per house, we use the ONLY data we have: Revenue: (1h ÷ 5.17h total) × $237.50 = $45.93"

**Problem**: The function uses appointment-specific hours, but the formula requires total day hours for allocation when house-specific hours are unknown.

### Issue 2: Transportation Cost Deduction
Transportation costs are deducted from the allocated revenue for each assignment. If Paul has high transportation costs, this could significantly reduce his net revenue.

### Issue 3: Missing Data Handling
The function uses `LEFT JOIN` to revenue_allocation, which means work days without assignments will show zero earned. This might not align with the formula's intent.

## Expected vs Actual Calculation

### According to Formula (Documented Example)
- **Total Revenue**: $237.50
- **Total Hours**: 6.17 (5.17 + 1)
- **Paul's Share**: (1 ÷ 6.17) × $237.50 = $38.50
- **Mariana's Share**: (5.17 ÷ 6.17) × $237.50 = $199.00
- **Performance Index**: Both should be $237.50 ÷ 6.17 = 38.50 (not 45.9 as mentioned)

**Note**: There's a discrepancy in the documented example. If total revenue is $237.50 and total hours are 6.17, the index should be 38.50, not 45.9.

### Current Function Behavior
The function calculates:
- Revenue per appointment based on actual_hours spent on that appointment
- Deducts transportation costs
- Divides net revenue by total work_day hours

## Investigation Queries

### Query 1: Check Current Data State
```sql
-- Run this first to see current performance index values
SELECT * FROM get_performance_index('91a20127-5cda-4220-a405-791640417f5d')
WHERE who ILIKE '%paul%' OR who ILIKE '%mariana%'
ORDER BY work_date;
```

### Query 2: Verify Assignment Data
```sql
-- Check if Paul and Mariana have the expected assignments
SELECT 
    e.name,
    wd.work_date,
    wd.hours_worked,
    COUNT(ca.id) as assignment_count,
    SUM(ca.actual_hours) as total_assigned_hours,
    SUM(ca.transportation_cost) as total_transport_cost
FROM employees e
JOIN work_days wd ON e.id = wd.employee_id
LEFT JOIN client_assignments ca ON wd.id = ca.work_day_id
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
  AND (e.name ILIKE '%paul%' OR e.name ILIKE '%mariana%')
  AND wd.work_date = '2025-11-15'
GROUP BY e.name, wd.work_date, wd.hours_worked;
```

### Query 3: Compare Calculation Methods
```sql
-- Compare current method vs formula method
WITH day_data AS (
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
)
SELECT 
    e.name,
    wd.work_date,
    wd.hours_worked,
    -- Current method (from function)
    (SELECT index FROM get_performance_index('91a20127-5cda-4220-a405-791640417f5d') 
     WHERE work_day_id = wd.id) as current_index,
    -- Formula method (proportional to total hours)
    ROUND(
        ((wd.hours_worked / dd.total_hours) * dd.total_revenue) / 
        NULLIF(wd.hours_worked, 0), 
        2
    ) as formula_index
FROM work_days wd
JOIN employees e ON wd.employee_id = e.id
CROSS JOIN day_data dd
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
  AND wd.work_date = '2025-11-15'
  AND (e.name ILIKE '%paul%' OR e.name ILIKE '%mariana%');
```

## Next Steps

1. **Run Investigation Queries**: Execute the queries above to identify the specific calculation differences
2. **Check Transportation Costs**: Verify if transportation costs are causing the discrepancy
3. **Verify Hours Allocation**: Ensure actual_hours are correctly assigned
4. **Compare Methods**: Determine if the current function logic matches the documented formula intent
5. **Propose Fix**: If the function logic is incorrect, create a corrected version

## Expected Resolution

Based on the analysis, the issue is likely one of:
- **Transportation cost allocation** disproportionately affecting one employee
- **Incorrect revenue distribution** method (per-appointment vs total-day)
- **Missing or incorrect actual_hours** values in assignments
- **Function logic mismatch** with documented formula