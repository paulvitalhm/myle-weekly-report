# Performance Report Implementation

## Overview
Added a comprehensive Performance Report page that analyzes individual and team performance metrics based on value generated per hour worked.

## Features Implemented

### 1. Performance Index Table
- **Columns**: Rank, Index, Tier, Who, When, Where
- **Tier System**:
  - 🟢 **Top Performing** (Index ≥ 47) - Green badge
  - 🟡 **Good** (Index 35-46.9) - Amber badge
  - 🔴 **Low Performing** (Index < 35) - Red badge
- **Sorting**: Descending by Performance Index (highest first)
- **Calculation**: Revenue Allocation / Actual Hours Worked

### 2. Best Performing Team Card
- Green background with border
- Shows team with highest Team Index
- Displays:
  - Date of team work
  - Team members (comma-separated)
  - Performance tier badge with index value
  - Clients served
  - Total hours worked

### 3. Lowest Performing Team Card
- Red background with border
- Shows team with lowest Team Index
- Same structure as Best Team card

### 4. Hours Discrepancies Section
- Filters discrepancies > 5 minutes from team average
- Sorted by largest difference first
- Shows:
  - Date and team members
  - Member name with hours worked
  - Difference from team average (positive/negative)
- Color-coded differences (orange for positive, red for negative)

### 5. Report Header
- Title: "MYLE Employee Performance Report"
- Period dates in full format: "Monday, November 3, 2025 - Saturday, November 8, 2025"
- Calendar days and work records count

### 6. Report Description
Complete explanation of Performance Index methodology and team detection logic.

## Technical Implementation

### New Files Created

#### 1. `src/components/PerformanceReport.vue`
**Component Structure:**
- Props: `periodId` (required)
- Composition API with reactive data management
- Sections:
  - Report Header
  - Report Description
  - Performance Index Table
  - Best Performing Team
  - Lowest Performing Team
  - Hours Discrepancies

**Key Functions:**
- `loadReportData()` - Main data loading orchestrator
- `loadPerformanceIndex()` - Calls Supabase RPC function
- `detectTeams()` - Identifies employees working together on same appointments
- `calculateTeamPerformance()` - Computes team indexes and ranks teams
- `calculateDiscrepancies()` - Finds hour discrepancies > 5 minutes
- `getTier()` - Determines performance tier based on index value

**Team Detection Logic:**
```javascript
// Teams = employees with shared appointments on same date
1. Group work days by date
2. Find appointments with multiple workers
3. Identify unique team members
4. Calculate team metrics from shared appointments only
```

**Revenue Allocation:**
```javascript
// Proportional allocation based on actual hours
allocation = (worker_actual_hours / total_hours_on_appointment) * appointment_cost
```

#### 2. `supabase-schema.sql` - Added `get_performance_index()` Function
**SQL Function:**
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
)
```

**Logic:**
1. Calculate total hours per appointment (from all assignments)
2. Allocate revenue proportionally to each worker
3. Calculate performance index per work day
4. Format date/time display strings
5. Aggregate client names
6. Rank by index descending

### Modified Files

#### `src/App.vue`
**Changes:**
1. Added `currentView` state ('assignments' | 'report')
2. Added routing button in header (toggles between views)
3. Imported `PerformanceReport` component
4. Conditional rendering based on `currentView`
5. Reset to assignments view when changing period

**Button Logic:**
```vue
<button @click="currentView = currentView === 'assignments' ? 'report' : 'assignments'">
  {{ currentView === 'assignments' ? '📊 Reports' : '✏️ Assignments' }}
</button>
```

## Database Schema Requirements

### Required Tables (Already Exist)
- `periods` - Pay periods
- `employees` - Employee records
- `work_days` - Individual work days
- `appointments` - Client appointments
- `client_assignments` - Links work days to appointments

### Required Fields
- `appointments.cost` - Revenue from appointment
- `client_assignments.actual_hours` - Hours after delays (auto-calculated by trigger)

### New Function
- `get_performance_index(p_period_id)` - Returns performance data

## Responsive Design

### Mobile (<768px)
- Tables scroll horizontally
- Cards stack vertically
- Team cards full width
- Badges resize appropriately
- Padding reduced
- Font sizes adjusted

### Desktop (≥768px)
- Full table display
- Side-by-side team cards
- Optimal spacing
- Hover effects on table rows

## Color Scheme

### Tier Badges
- **Top**: `#c8e6c9` background, `#2e7d32` text
- **Good**: `#fff3cd` background, `#f57f17` text
- **Low**: `#ffcdd2` background, `#c62828` text

### Team Cards
- **Best**: `#c8e6c9` background, `#4caf50` border
- **Worst**: `#ffcdd2` background, `#f44336` border

### Discrepancies
- Border: `#ff9800` (orange)
- Positive difference: `#f57f17` (amber)
- Negative difference: `#d32f2f` (red)

## Usage Instructions

### For Users
1. Upload payroll and appointment files
2. Complete client assignments for employees
3. Click "📊 Reports" button in header
4. View performance metrics and team analytics
5. Click "✏️ Assignments" to return to assignment workflow

### For Developers
1. Ensure database schema is up to date:
   ```bash
   # Run in Supabase SQL Editor
   # Execute: employee-performance/supabase-schema.sql
   ```

2. Start development server:
   ```bash
   cd employee-performance
   npm run dev
   ```

3. Access at http://localhost:5177/

## Performance Considerations

### Optimization Strategies
- Performance index calculated via single SQL function (efficient)
- Team detection runs on client side (flexible for complex logic)
- Discrepancies filtered to only show > 5 minutes
- Responsive table with horizontal scroll for mobile

### Data Volume
- Handles multiple employees, work days, and appointments
- Scales well with proper Supabase indexes
- No pagination needed for typical period sizes (1-2 weeks)

## Testing Checklist

- [ ] Upload files with multiple employees
- [ ] Complete assignments for at least 2 employees on same day
- [ ] Verify performance index calculation
- [ ] Check tier badges display correctly
- [ ] Confirm team detection works (shared appointments)
- [ ] Test hours discrepancies > 5 minutes display
- [ ] Verify responsive design on mobile
- [ ] Test navigation between Reports and Assignments
- [ ] Confirm period change resets to assignments view

## Known Limitations

1. **No Export Feature**: Report cannot be exported to PDF/Excel (future enhancement)
2. **No Filters**: Cannot filter by employee or tier (future enhancement)
3. **Solo Workers**: Don't appear in team cards (by design - need 2+ workers)
4. **Small Discrepancies**: < 5 minute differences not shown (by design)

## Future Enhancements

1. Export report to PDF/Excel
2. Add filters (by employee, tier, date range)
3. Charts/graphs for visual performance trends
4. Historical performance comparison
5. Alert system for low-performing days
6. Detailed drill-down into specific work days

## Troubleshooting

### Report Shows "Loading" Forever
- Check Supabase connection in browser console
- Verify `get_performance_index` function exists in database
- Ensure period has completed assignments

### No Teams Displayed
- Teams require 2+ employees working same appointments on same day
- Verify client assignments are saved correctly
- Check that employees share at least one appointment

### Performance Index Shows 0 or Null
- Ensure appointments have cost values
- Verify client_assignments have actual_hours calculated
- Check that work_days have hours_worked > 0

### Discrepancies Section Empty
- All team members' hours within 5 minutes of average
- No teams exist (need shared appointments)
- Only solo workers (no team comparison)

## Related Documentation

- [README.md](../README.md) - Project setup
- [PRD.md](./PRD.md) - Product requirements
- [supabase-schema.sql](../supabase-schema.sql) - Database schema
