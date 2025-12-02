# Router Implementation Guide for Daily Performance Report

## Fixing the Empty Page Issue

The empty page at `http://localhost:5180/#/daily-report` is likely because the route hasn't been added to your Vue Router configuration.

## Step 1: Add Route to Router

In your `employee-performance/src/router/index.js` file, add the Daily Performance Report route:

```javascript
import { createRouter, createWebHashHistory } from 'vue-router'
import DailyPerformanceReport from '../components/DailyPerformanceReport.vue'

// Add to your existing routes array:
const routes = [
  // ... your existing routes ...
  {
    path: '/daily-report',
    name: 'DailyReport',
    component: DailyPerformanceReport
  }
]

const router = createRouter({
  history: createWebHashHistory(),
  routes
})

export default router
```

## Step 2: Add Navigation Link

In your navigation component (likely `NavigationBar.vue`), add a link to the daily report:

```html
<router-link to="/daily-report" class="nav-link">
  Daily Performance
</router-link>
```

## Step 3: Execute the Final Database Function

Run the SQL from [`final-daily-performance-function.sql`](employee-performance/final-daily-performance-function.sql) in your Supabase SQL Editor to fix the double-counting issue.

## Step 4: Test the Application

1. Restart your development server if needed
2. Navigate to `http://localhost:5180/#/daily-report`
3. Select a period from the dropdown
4. Verify daily performance data displays correctly

## Troubleshooting

### If you still see an empty page:

1. **Check browser console** for JavaScript errors
2. **Verify the component path** is correct in the router
3. **Check if the database function exists** by running:
   ```sql
   SELECT * FROM get_daily_performance_index('91a20127-5cda-4220-a405-791640417f5d')
   ```

### If data doesn't load:

1. **Check network requests** in browser dev tools
2. **Verify Supabase connection** is working
3. **Test the database function directly** in Supabase SQL Editor

## Expected Results

After implementing both the database function and router configuration, you should see:

- **Working navigation** to the daily report
- **Period selection dropdown** with available periods
- **Daily performance cards** showing team metrics per day
- **Correct calculations** without double-counting

The final database function uses `SUM(DISTINCT a.cost)` to avoid the Cartesian product issue that was causing double-counting.