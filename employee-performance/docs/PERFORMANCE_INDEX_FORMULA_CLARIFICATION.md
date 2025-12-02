# Performance Index Formula Clarification

## The Correct Formula

Based on your analysis, the performance index formula should be:

### For November 15, 2025:
- **Total Revenue**: $237.50 ($150.00 + $87.50)
- **Total Hours**: 6.17 (5.17 + 1.00)
- **Performance Index**: $237.50 ÷ 6.17 = 38.49

### Individual Calculations:
- **Mariana**: (5.17 ÷ 6.17) × $237.50 = $199.00 → $199.00 ÷ 5.17 = 38.49
- **Paul**: (1.00 ÷ 6.17) × $237.50 = $38.50 → $38.50 ÷ 1.00 = 38.49

## The Issue with Previous Implementation

The problem was that my previous queries were **summing across multiple days** instead of calculating per day. The performance index should be calculated **per work day**, not across the entire period.

## Corrected SQL Function

Here is the corrected SQL function that implements the formula correctly:

```sql
-- Corrected Performance Index Function
-- This calculates performance index PER DAY, not across multiple days

DROP FUNCTION IF EXISTS get_performance_index(UUID);

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
        -- Calculate total revenue and total hours for EACH work day
        SELECT 
            wd.work_date,
            SUM(a.cost) as total_day_revenue,
            SUM(wd.hours_worked) as total_day_hours
        FROM work_days wd
        JOIN employees e ON wd.employee_id = e.id
        JOIN client_assignments ca ON wd.id = ca.work_day_id
        JOIN appointments a ON ca.appointment_id = a.id
        WHERE e.period_id = p_period_id
        GROUP BY wd.work_date
    ),
    revenue_allocation AS (
        -- Allocate revenue proportionally to hours worked on the specific day
        SELECT 
            wd.id as work_day_id,
            wd.work_date,
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
        JOIN work_day_totals wdt ON wd.work_date = wdt.work_date
        LEFT JOIN client_assignments ca ON wd.id = ca.work_day_id
        WHERE e.period_id = p_period_id
        GROUP BY wd.id, wd.work_date, wdt.total_day_revenue, wdt.total_day_hours, wd.hours_worked
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
```

## Verification Query

Run this query to verify the correct calculation for November 15, 2025:

```sql
-- Manual verification for November 15, 2025 ONLY
WITH day_totals AS (
    SELECT 
        SUM(a.cost) as total_revenue,
        SUM(wd.hours_worked) as total_hours
    FROM work_days wd
    JOIN employees e ON wd.employee_id = e.id
    JOIN client_assignments ca ON wd.id = ca.work_day_id
    JOIN appointments a ON ca.appointment_id = a.id
    WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
      AND wd.work_date = '2025-11-15'  -- Only November 15, 2025
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
  AND wd.work_date = '2025-11-15'  -- Only November 15, 2025
  AND (e.name ILIKE '%paul%' OR e.name ILIKE '%mariana%');
```

## Expected Results After Fix

After implementing the corrected function, you should see:

| who            | work_date  | index  | earned | hours_worked |
| -------------- | ---------- | ------ | ------ | ------------ |
| Paul Vital     | 2025-11-15 | 38.49  | 38.50  | 1.00         |
| Mariana Kryvka | 2025-11-15 | 38.49  | 199.00 | 5.17         |

## Key Points

1. **Per-Day Calculation**: Performance index is calculated separately for each work day
2. **Proportional Allocation**: Revenue is allocated based on total hours worked that day
3. **Same Index**: All employees working the same day get the same performance index
4. **Different Earnings**: Employees earn different amounts based on hours worked, but same index

## Implementation Steps

1. Copy the corrected SQL function above into your Supabase SQL Editor
2. Execute the function creation
3. Run the verification query to confirm both Paul and Mariana show 38.49 for November 15, 2025
4. Test with other dates to ensure the per-day calculation works correctly

This implementation correctly follows the documented formula and ensures fair compensation based on total hours worked per day.