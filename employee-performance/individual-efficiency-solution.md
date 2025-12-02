# Individual Efficiency Solution Without Appointment Time Tracking

## The Challenge

You want to measure **Individual Efficiency** (revenue per hour per employee) but only have:
- Revenue per appointment
- Who worked on each appointment
- Total hours per employee per day
- Late arrival and early leave data

## The Mathematical Reality

With proportional revenue allocation, individual efficiency becomes mathematically identical to team efficiency:

```
Individual Efficiency = (Individual Revenue ÷ Individual Hours)
                     = ((Hours ÷ Total Hours) × Total Revenue) ÷ Hours
                     = Total Revenue ÷ Total Hours
```

**This is unavoidable with proportional allocation** - the hours cancel out.

## Alternative Approaches

### Approach 1: Weighted Contribution Method

Instead of proportional allocation, use a **weighted system** based on:
- Number of appointments worked
- Complexity of appointments
- Seniority or role factors

### Approach 2: Appointment Count Method

Measure efficiency based on **appointments completed per hour** rather than revenue:

```
Efficiency = (Number of Appointments ÷ Individual Hours) × Average Appointment Value
```

### Approach 3: Modified Revenue Allocation

Use a **non-proportional allocation** method that considers:
- Equal split for appointments with multiple workers
- Full credit for solo appointments
- Penalties for late arrivals/early leaves

## Recommended Solution: Hybrid Allocation Method

Since you can't track time per appointment, let's use a **hybrid approach** that combines:

1. **Solo Appointments**: Full revenue to the worker
2. **Team Appointments**: Equal split among workers
3. **Adjusted for Punctuality**: Penalize late arrivals/early leaves

### Implementation Logic

```sql
-- For each appointment:
IF (number_of_workers = 1) THEN
    revenue_allocation = appointment_cost
ELSE
    revenue_allocation = appointment_cost / number_of_workers
END IF

-- Adjust for punctuality
adjusted_revenue = revenue_allocation × punctuality_factor
```

### Punctuality Factor Calculation

```
punctuality_factor = 1 - (late_minutes + early_minutes) / (total_minutes_worked × 2)
```

## SQL Implementation

```sql
CREATE OR REPLACE FUNCTION get_individual_efficiency(p_period_id UUID)
RETURNS TABLE (...) AS $$
BEGIN
    RETURN QUERY
    WITH appointment_workers AS (
        -- Count workers per appointment
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
            e.name,
            CASE 
                -- Solo appointment: full revenue
                WHEN aw.worker_count = 1 THEN a.cost
                -- Team appointment: equal split
                ELSE a.cost / aw.worker_count
            END as base_revenue,
            -- Punctuality adjustment
            CASE 
                WHEN (ca.arrival_delay_minutes + ca.early_departure_minutes) > 0 THEN
                    base_revenue * (1 - (ca.arrival_delay_minutes + ca.early_departure_minutes) / (wd.hours_worked * 120))
                ELSE base_revenue
            END as adjusted_revenue
        FROM client_assignments ca
        JOIN appointments a ON ca.appointment_id = a.id
        JOIN work_days wd ON ca.work_day_id = wd.id
        JOIN employees e ON wd.employee_id = e.id
        JOIN appointment_workers aw ON a.id = aw.appointment_id
        WHERE e.period_id = p_period_id
    ),
    daily_totals AS (
        -- Calculate total earned per work day
        SELECT 
            wd.id as work_day_id,
            e.name,
            SUM(ra.adjusted_revenue) as total_earned,
            wd.hours_worked
        FROM work_days wd
        JOIN employees e ON wd.employee_id = e.id
        JOIN revenue_allocation ra ON wd.id = ra.work_day_id AND e.name = ra.name
        GROUP BY wd.id, e.name, wd.hours_worked
    )
    SELECT 
        ROW_NUMBER() OVER (ORDER BY (dt.total_earned / NULLIF(dt.hours_worked, 0)) DESC) as rank,
        ROUND((dt.total_earned / NULLIF(dt.hours_worked, 0))::numeric, 2) as efficiency_index,
        dt.name::VARCHAR as who,
        -- ... other columns
        dt.total_earned as earned,
        dt.hours_worked
    FROM daily_totals dt
    ORDER BY efficiency_index DESC;
END;
$$ LANGUAGE plpgsql;
```

## Expected Results

### Current System (Proportional Allocation):
| Employee | Hours | Index |
|----------|-------|-------|
| Nanette  | 4.83  | 22.85 |
| Soraya   | 3.92  | 22.85 |

### Hybrid Allocation (Example):
| Employee | Solo Apps | Team Apps | Adjusted Revenue | Hours | Index |
|----------|-----------|-----------|------------------|-------|-------|
| Nanette  | 2 ($150)  | 1 ($25)   | $175             | 4.83  | 36.23 |
| Soraya   | 0 ($0)    | 3 ($75)   | $75              | 3.92  | 19.13 |

## Benefits of This Approach

1. **Differentiates Performance**: Workers who handle solo appointments get higher scores
2. **Encourages Responsibility**: Rewards taking ownership of appointments
3. **Penalizes Tardiness**: Late arrivals reduce efficiency score
4. **Uses Available Data**: Works with the data you currently collect
5. **Mathematically Sound**: Avoids the proportional allocation flaw

## Implementation Steps

1. Create the hybrid allocation function
2. Test with your current data
3. Compare results with current system
4. Adjust weighting factors as needed
5. Update documentation to reflect the new calculation method

This approach provides meaningful individual efficiency measurement without requiring per-appointment time tracking.