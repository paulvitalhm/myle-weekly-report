# Performance Index Root Cause Analysis

## Data Analysis Results

### Current Performance Index Data:
- **Paul Vital**: 24.31 (expected 45.9)
- **Mariana Kryvka**: 41.24 (expected 45.9)
- **Formula Index**: 34.17 for both (calculated from total revenue/hours)

### Assignment Data for November 15, 2025:
- **Total Revenue**: $237.50 ($150.00 + $87.50)
- **Total Hours**: 6.17 (5.17 + 1.00)
- **No Transportation Costs**: 0.00 for all assignments

## The Root Cause Identified

### Issue: Incorrect Revenue Allocation Method

The current [`get_performance_index()`](employee-performance/supabase-schema.sql:394) function is allocating revenue **per appointment** based on `actual_hours` spent on each specific appointment, but this creates an unfair distribution.

### What's Happening:

1. **Cameron Hepple Appointment** ($150.00):
   - Mariana: 5.17 hours → Gets full $150.00
   - Paul: 1.00 hour → Gets $0.00 (because Mariana worked all 5.17 hours)

2. **Cute & Cozy Appointment** ($87.50):
   - Mariana: 5.17 hours → Gets full $87.50
   - Paul: 0 hours → Gets $0.00

### Current Function Logic (WRONG):
```sql
-- This allocates revenue per appointment based on hours spent on THAT appointment
((ca.actual_hours / NULLIF(at.total_hours_on_appointment, 0)) * at.cost) - COALESCE(ca.transportation_cost, 0) as allocated_revenue
```

### What Should Happen (CORRECT):
According to the documented formula, when we don't know house-specific hours, revenue should be allocated proportionally to **total day hours**, not per-appointment hours.

## The Correct Calculation

### Based on Documented Formula:
- **Total Revenue**: $237.50
- **Total Hours**: 6.17
- **Performance Index**: $237.50 ÷ 6.17 = 38.50 (not 45.9)

**Note**: The documented example of 45.9 appears to be incorrect. With $237.50 total revenue and 6.17 total hours, the correct index should be 38.50.

### Individual Allocations:
- **Paul**: (1.00 ÷ 6.17) × $237.50 = $38.50
- **Mariana**: (5.17 ÷ 6.17) × $237.50 = $199.00

### Performance Index:
- **Both**: $237.50 ÷ 6.17 = 38.50

## Why the Current Function is Wrong

The current function gives:
- **Paul**: $24.31 (only from Cameron Hepple, but gets nothing from Cute & Cozy)
- **Mariana**: $213.19 (gets both appointments fully)

This happens because the function allocates each appointment's revenue only to employees who worked on that specific appointment, rather than distributing total revenue proportionally to total hours worked.

## The Fix Required

The [`get_performance_index()`](employee-performance/supabase-schema.sql:394) function needs to be modified to:

1. **Calculate total revenue and total hours for the day**
2. **Allocate revenue proportionally to total hours worked**, not per-appointment hours
3. **Only use per-appointment allocation when we have specific appointment hours**

## SQL Query to Verify the Fix

```sql
-- This shows what the correct calculation should be
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
```

## Summary

The performance index function is incorrectly allocating revenue per appointment instead of proportionally to total day hours. This causes Paul to get significantly less revenue than he should, resulting in his low performance index of 24.31 instead of the correct 38.50.

The fix requires modifying the function to implement the documented formula correctly.