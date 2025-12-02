# MYLE Employee Performance - Technical Guide

## Architecture Overview

### Technology Stack
- **Frontend**: Vue 3 Composition API + Vite
- **Backend**: Supabase (PostgreSQL + Auth)
- **Routing**: Vue Router 4 (hash mode for compatibility)
- **Deployment**: Cloudflare Pages
- **Design**: Mobile-first, responsive CSS Grid/Flexbox

### Database Schema

#### Core Tables
```sql
-- Pay periods
periods (id, start_date, end_date, status, created_at, updated_at)

-- Employees linked to periods
employees (id, period_id, name, total_hours, total_days, completed_days, is_completed)

-- Individual work days
work_days (id, employee_id, work_date, hours_worked, hours_display, is_completed)

-- Client appointments
appointments (id, period_id, appointment_date, appointment_time, customer_name, service, cost, address, city)

-- Links work days to appointments
client_assignments (id, work_day_id, appointment_id, actual_hours, arrival_delay_minutes, early_departure_minutes, transportation_cost)
```

#### Key Functions
```sql
-- Calculate performance index with net revenue
get_performance_index(p_period_id UUID) RETURNS TABLE (...)

-- Auto-calculate actual hours from delays
calculate_actual_hours() RETURNS TRIGGER

-- Update completion status
update_work_day_completion() RETURNS TRIGGER
```

## Component Architecture

### Main Components
```
src/
├── components/
│   ├── AddTimeEntry.vue          # Manual time entry with autocomplete
│   ├── AppointmentsByDay.vue     # Calendar and list views
│   ├── AssignmentManagement.vue  # Bulk assignment management
│   ├── PerformanceReport.vue     # Desktop performance table
│   ├── PeriodOverviewCalendar.vue # Calendar overview
│   ├── SetupAssignments.vue      # 3-step assignment workflow
│   ├── ShareableReport.vue       # Mobile-optimized shareable reports
│   ├── TeamAssignments.vue       # Team management interface
│   └── NavigationBar.vue         # Bottom navigation
├── composables/
│   └── useDataParser.js         # Excel file parsing utilities
├── config/
│   └── supabase.js              # Database configuration
└── router/
    └── index.js                 # Route definitions
```

### Key Features Implementation

#### 1. Performance Index Calculation
```javascript
// Revenue allocation proportional to hours worked
allocation = (worker_actual_hours / total_hours_on_appointment) * appointment_cost - transportation_cost

// Performance index = net revenue ÷ hours worked
index = total_allocated_revenue / total_hours_worked
```

#### 2. Team Detection Algorithm
```javascript
// Teams = employees with shared appointments on same date
1. Group work days by date
2. Find appointments with multiple workers
3. Identify unique team members  
4. Calculate team metrics from shared appointments only
```

#### 3. Assignment Workflow Rules
- Appointments filtered by date: `appointment_date === work_day.work_date`
- Assigned appointments never appear in main appointments list
- Only unassigned appointments for selected date appear in Step 3
- Summary card shows all current assignments for this work day

## Database Functions

### get_performance_index Function
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
-- Calculates individual performance metrics for each work day
-- Shows net revenue (after transportation cost deduction) in "earned" column
BEGIN
    RETURN QUERY
    WITH appointment_totals AS (
        -- Calculate total hours per appointment
        SELECT a.id as appointment_id, a.cost, SUM(ca.actual_hours) as total_hours_on_appointment
        FROM appointments a
        LEFT JOIN client_assignments ca ON a.id = ca.appointment_id
        WHERE a.period_id = p_period_id
        GROUP BY a.id, a.cost
    ),
    revenue_allocation AS (
        -- Allocate revenue proportionally and deduct transportation costs
        SELECT ca.work_day_id, a.customer_name, ca.actual_hours, ca.transportation_cost,
               at.total_hours_on_appointment,
               ((ca.actual_hours / NULLIF(at.total_hours_on_appointment, 0)) * at.cost) - COALESCE(ca.transportation_cost, 0) as allocated_revenue
        FROM client_assignments ca
        JOIN appointments a ON ca.appointment_id = a.id
        JOIN appointment_totals at ON a.id = at.appointment_id
        WHERE a.period_id = p_period_id
    )
    SELECT 
        ROW_NUMBER() OVER (ORDER BY (SUM(COALESCE(ra.allocated_revenue, 0)) / NULLIF(wd.hours_worked, 0)) DESC) as rank,
        ROUND((SUM(COALESCE(ra.allocated_revenue, 0)) / NULLIF(wd.hours_worked, 0))::numeric, 2) as index,
        e.name::VARCHAR as who,
        (TO_CHAR(wd.work_date, 'Dy, Mon DD YYYY') || ' (' || FLOOR(wd.hours_worked)::text || 'h ' || ROUND((wd.hours_worked - FLOOR(wd.hours_worked)) * 60)::int::text || 'm)')::TEXT as "when",
        COALESCE(STRING_AGG(DISTINCT ra.customer_name, ', '), 'Pending')::TEXT as "where",
        ROUND(SUM(COALESCE(ra.allocated_revenue, 0))::numeric, 2) as earned,
        wd.id as work_day_id,
        wd.work_date,
        wd.hours_worked::numeric
    FROM work_days wd
    JOIN employees e ON wd.employee_id = e.id
    LEFT JOIN revenue_allocation ra ON wd.id = ra.work_day_id
    WHERE wd.hours_worked > 0 AND e.period_id = p_period_id
    GROUP BY wd.id, wd.work_date, wd.employee_id, e.name, wd.hours_worked
    ORDER BY index DESC;
END;
$$ LANGUAGE plpgsql;
```

## API Integration

### Supabase Client Configuration
```javascript
// src/config/supabase.js
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
```

### Data Loading Patterns
```javascript
// Performance data loading
const { data, error } = await supabase.rpc('get_performance_index', {
  p_period_id: props.periodId
})

// Team assignments with joins
const { data } = await supabase
  .from('work_days')
  .select(`
    id,
    work_date,
    hours_worked,
    employee:employees!inner(id, name),
    assignments:client_assignments(
      id,
      actual_hours,
      appointment:appointments!inner(id, customer_name, cost)
    )
  `)
  .eq('employee.period_id', props.periodId)
  .gt('hours_worked', 0)
```

## Mobile Optimization

### Responsive Breakpoints
- **Mobile (<768px)**: Cards stack vertically, full-width buttons, reduced padding
- **Tablet (768px-1024px)**: Two-column layouts where appropriate
- **Desktop (≥1024px)**: Full feature display with optimal spacing

### Touch-Friendly Design
- Minimum touch target: 44px × 44px
- Hover effects replaced with focus states on mobile
- Swipe gestures for navigation where appropriate
- Large, readable fonts (minimum 16px for body text)

## Performance Optimization

### Database Indexes
```sql
CREATE INDEX idx_periods_dates ON periods(start_date, end_date);
CREATE INDEX idx_employees_period ON employees(period_id);
CREATE INDEX idx_work_days_employee ON work_days(employee_id);
CREATE INDEX idx_work_days_date ON work_days(work_date);
CREATE INDEX idx_appointments_period ON appointments(period_id);
CREATE INDEX idx_appointments_date ON appointments(appointment_date);
CREATE INDEX idx_client_assignments_work_day ON client_assignments(work_day_id);
```

### Query Optimization
- Use RPC functions for complex calculations (server-side)
- Implement proper joins to avoid N+1 queries
- Filter data at database level before client processing
- Use `select()` with specific fields to reduce payload

### Frontend Performance
- Component lazy loading for large datasets
- Debounced search inputs (300ms delay)
- Virtual scrolling for long lists (future enhancement)
- Image optimization and lazy loading

## Security Considerations

### Current Setup (Development)
- Row Level Security (RLS) disabled for development
- No authentication required
- Public read access to all data

### Production Recommendations
```sql
-- Enable RLS on all tables
ALTER TABLE periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE work_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_assignments ENABLE ROW LEVEL SECURITY;

-- Create read-only policy for reports
CREATE POLICY "Allow read access for authenticated users" ON periods
    FOR SELECT USING (auth.role() = 'authenticated');
```

### Data Protection
- UUIDs used for IDs (not sequential, harder to guess)
- Period-based data isolation
- Cascade delete prevents orphaned data
- Input validation on all user inputs

## Deployment

### Build Process
```bash
npm run build
# Generates optimized production build in dist/
```

### Environment Variables
```bash
VITE_SUPABASE_URL=your-supabase-url
VITE_SUPABASE_ANON_KEY=your-supabase-anon-key
```

### Hosting Requirements
- Static file hosting (Cloudflare Pages, Netlify, Vercel)
- HTTPS support for secure data transmission
- Custom domain support for branded URLs
- CDN for global performance

## Testing

### Unit Testing Strategy
- Component rendering tests
- Business logic validation
- Database function testing
- API integration testing

### Integration Testing
- End-to-end assignment workflow
- Performance report generation
- Data upload and processing
- Mobile responsiveness testing

### Performance Testing
- Report generation speed (< 2 seconds)
- Large dataset handling
- Mobile performance on slow networks
- Concurrent user load testing

## Monitoring & Analytics

### Application Monitoring
- Error tracking and reporting
- Performance metrics collection
- User interaction analytics
- Database query performance monitoring

### Business Metrics
- Assignment completion rates
- Report sharing frequency
- User engagement patterns
- Performance index trends

## Troubleshooting

### Common Issues

1. **"Loading" stuck forever**
   - Check Supabase connection
   - Verify database functions exist
   - Check browser console for errors

2. **Performance index shows 0**
   - Ensure appointments have cost values
   - Verify client_assignments have actual_hours
   - Check work_days have hours_worked > 0

3. **No teams displayed**
   - Teams require 2+ employees on same appointments
   - Verify shared appointments exist
   - Check date matching between work_days and appointments

4. **Mobile display issues**
   - Check viewport meta tag
   - Verify CSS media queries
   - Test on actual devices

### Debug Mode
Enable debug logging by setting:
```javascript
localStorage.setItem('debug', 'true')
```

## Future Enhancements

### Planned Features
1. **Export Functionality**: PDF/Excel export for reports
2. **Analytics Dashboard**: Charts and trend analysis
3. **Real-time Updates**: WebSocket integration for live data
4. **Advanced Filtering**: Date ranges, employee filters, custom metrics
5. **Multi-language Support**: Full French/English toggle

### Performance Improvements
1. **Pagination**: For large datasets
2. **Caching**: Client-side data caching
3. **Lazy Loading**: Component-level code splitting
4. **Service Worker**: Offline functionality

### Security Enhancements
1. **Authentication**: User login system
2. **Role-based Access**: Different permission levels
3. **Audit Logging**: Track all data changes
4. **Data Encryption**: Sensitive data protection

---
*Last updated: November 2025*
