# Daily Performance Report Implementation Guide

## Overview

This guide explains how to implement the new Daily Performance Report that shows team performance metrics per day instead of individual performance.

## What's Included

1. **Database Function**: [`get_daily_performance_index()`](employee-performance/daily-performance-report-function.sql) - Calculates daily performance metrics
2. **Vue Component**: [`DailyPerformanceReport.vue`](employee-performance/src/components/DailyPerformanceReport.vue) - UI component matching existing design
3. **Route Configuration**: Instructions to add the new route

## Implementation Steps

### Step 1: Create the Database Function

Execute the SQL from [`daily-performance-report-function.sql`](employee-performance/daily-performance-report-function.sql) in your Supabase SQL Editor:

```sql
-- Copy and paste the entire content of daily-performance-report-function.sql
-- This creates the get_daily_performance_index function
```

### Step 2: Add the Route

Add the new route to your Vue router configuration. In [`employee-performance/src/router/index.js`](employee-performance/src/router/index.js), add:

```javascript
import DailyPerformanceReport from '../components/DailyPerformanceReport.vue'

const routes = [
  // ... existing routes ...
  {
    path: '/daily-report',
    name: 'DailyReport',
    component: DailyPerformanceReport
  }
]
```

### Step 3: Add Navigation Link

Add a navigation link to the new report in your navigation component. In [`NavigationBar.vue`](employee-performance/src/components/NavigationBar.vue), add:

```html
<router-link to="/daily-report" class="nav-link">
  Daily Performance
</router-link>
```

## How It Works

### Performance Calculation

The daily performance index is calculated as:

```
Performance Index = Total Day Revenue ÷ Total Day Hours
```

### Example Calculations

**November 15, 2025:**
- Total Revenue: $237.50 ($150 + $87.50)
- Total Hours: 6.17 (5.17 + 1.00)
- Performance Index: 38.49

**November 10, 2025:**
- Total Revenue: $200.00
- Total Hours: 8.75 (4.83 + 3.92)
- Performance Index: 22.85

### Performance Tiers

- **🟢 Top Performers**: Index ≥ 47
- **🟡 Good Performers**: Index 35-46
- **🔴 Needs Improvement**: Index < 35

## Expected Results

After implementation, you should see:

| Rank | Index | Date | Earned | Hours | Workers | Tier |
|------|-------|------|--------|-------|---------|------|
| 1 | 38.49 | Nov 15, 2025 | $237.50 | 6.17 | 2 | Good |
| 2 | 22.85 | Nov 10, 2025 | $200.00 | 8.75 | 2 | Needs Improvement |

## Testing

### Test the Database Function

Run this query in Supabase SQL Editor to verify the function works:

```sql
SELECT * FROM get_daily_performance_index('91a20127-5cda-4220-a405-791640417f5d')
ORDER BY day_date;
```

### Test the Vue Component

1. Start your development server: `npm run dev`
2. Navigate to `http://localhost:5180/#/daily-report`
3. Select a period from the dropdown
4. Verify the daily performance cards display correctly

## Benefits

1. **Meaningful Metrics**: Measures actual team productivity per day
2. **No Mathematical Flaws**: Avoids the proportional allocation issue
3. **Clear Insights**: Shows which days were most productive
4. **Same Look & Feel**: Matches existing performance report design
5. **Easy Comparison**: Allows comparing performance across different days

## Data Verification

The function includes verification queries to ensure calculations are correct:

- **November 15, 2025**: Should show $237.50 ÷ 6.17 = 38.49
- **November 10, 2025**: Should show $200.00 ÷ 8.75 = 22.85

## Troubleshooting

### Common Issues

1. **Function Not Found**: Ensure you executed the SQL function creation
2. **No Data Displayed**: Check if the selected period has work days with assignments
3. **Incorrect Calculations**: Verify that appointments are properly assigned to work days

### Debug Queries

Use these queries to debug data issues:

```sql
-- Check work days and assignments
SELECT 
    wd.work_date,
    e.name,
    wd.hours_worked,
    a.customer_name,
    a.cost
FROM work_days wd
JOIN employees e ON wd.employee_id = e.id
JOIN client_assignments ca ON wd.id = ca.work_day_id
JOIN appointments a ON ca.appointment_id = a.id
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
ORDER BY wd.work_date, e.name;

-- Check daily totals manually
SELECT 
    wd.work_date,
    SUM(a.cost) as total_revenue,
    SUM(wd.hours_worked) as total_hours,
    COUNT(DISTINCT e.id) as worker_count
FROM work_days wd
JOIN employees e ON wd.employee_id = e.id
JOIN client_assignments ca ON wd.id = ca.work_day_id
JOIN appointments a ON ca.appointment_id = a.id
WHERE e.period_id = '91a20127-5cda-4220-a405-791640417f5d'
GROUP BY wd.work_date
HAVING SUM(wd.hours_worked) > 0
ORDER BY wd.work_date;
```

## Next Steps

1. Implement the database function
2. Add the Vue component and route
3. Test with your data
4. Deploy to production
5. Gather feedback from users

This solution provides a meaningful way to measure team performance without the mathematical limitations of individual performance measurement with proportional revenue allocation.