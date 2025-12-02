# Product Requirements Document (PRD)
## MYLE Employee Performance Application

## Vision
Create a bilingual (FR/EN) employee performance tracking system that enables managers to:
1. Upload payroll and appointment data
2. Set up client-to-employee assignments
3. View performance metrics and reports
4. Manage appointments and team assignments
5. Generate shareable performance reports

## User Stories

### US-1: Period Management
**En tant que** manager,  
**Je veux** créer et gérer des périodes de paie,  
**Pour** organiser les données par semaine de travail.

**Acceptance Criteria:**
- Upload Excel files (payroll + appointments)
- System calculates period start/end dates from data
- View list of all periods with employee/appointment counts
- Delete periods with cascade (removes all related data)
- Select active period for viewing/editing

### US-2: Setup Client Assignments
**En tant que** manager,  
**Je veux** assigner des rendez-vous clients aux employés,  
**Pour** suivre qui a travaillé sur quels jobs.

**Workflow (3 Steps):**

**Step 1: Select Employee**
- Display grid of all employees in the period
- Show employee names
- Highlight selected employee

**Step 2: Select Work Day**
- Display grid of work days for selected employee
- Show date, hours worked, and assignment count
- Highlight days with existing assignments (green border)
- Show "X assigned" badge on days with assignments

**Step 3: Assign Clients**
- **CRITICAL:** Only show appointments that match the selected work day's date
- Display unassigned appointments for that specific date
- Search/filter by client name, service, or address
- "Show unassigned only" filter toggle (cosmetic - assigned appointments are always hidden from main list)
- Assigned appointments appear ONLY in "Current Assignments" summary card
- Click "Assign" to open modal and enter actual hours worked
- Assigned appointments immediately move to summary section and disappear from available list
- Click "Remove" in summary card to unassign and return to available list

**Key Rules:**
- Appointments filtered by date: `appointment_date === work_day.work_date`
- Assigned appointments never appear in the main appointments list
- Only unassigned appointments for the selected date appear in Step 3
- Summary card shows all current assignments for this work day

### US-3: Performance Report (Shareable)
**En tant que** manager,  
**Je veux** voir et partager un rapport de performance,  
**Pour** évaluer les employés individuellement et en équipe.

**Features:**
- Shareable URL format: `/#/report/:periodId`
- Auto-refresh when period changes (watch on periodId prop)
- Performance cards with rank, index, tier (Top/Good/Low)
- Expandable cards showing client details and service types
- Search by employee name
- Filter by tier (Top/Good/Low)
- Best/worst performing team cards
- Sticky header with period info and stats
- Mobile-first responsive design

### US-4: Appointments by Day
**En tant que** manager,  
**Je veux** voir tous les rendez-vous groupés par date,  
**Pour** avoir une vue calendrier du travail.

**Features:**
- Shareable URL format: `/#/appointments/:periodId`
- Group appointments by date (Mon Nov 3, Tue Nov 4, etc.)
- Day summary card at top of each day:
  - Number of jobs
  - Total revenue ($)
  - Worker names (from client_assignments)
- Expandable appointment cards:
  - Client name (customer_name)
  - Time range (appointment_time + calculated duration)
  - Team members assigned (from client_assignments join)
  - Address + service type
  - Revenue (cost)
- Sticky header with search & filter
- Footer with 4 action buttons (Add, Export, Refresh, Settings)

### US-5: Team Assignments Management
**En tant que** manager,  
**Je veux** gérer toutes les assignations d'équipe,  
**Pour** modifier ou supprimer des assignations.

**Features:**
- Shareable URL format: `/#/assignments/:periodId`
- List all assignments from client_assignments table
- Assignment cards showing:
  - Client name
  - Date & time
  - Team members
  - Expandable details (address, service, revenue)
- "Unassigned Only" filter toggle:
  - Show appointments with NO entries in client_assignments
  - Helps identify jobs that need assignment
- Edit/Delete buttons modify client_assignments table ONLY (not appointments)
- Search by client name, worker name, or date
- Sticky header with search & filter
- Footer with 4 action buttons (Add New, Export, Refresh, Settings)

## Key Performance Indicators (KPIs)

### Performance Index Calculation
```
Performance Index = Total Revenue / Total Hours Worked
```

**Tier Thresholds:**
- Top Tier: Index ≥ 47
- Good Tier: 35 ≤ Index < 47
- Low Tier: Index < 35

### Team Performance
- Detect teams: employees who worked together on same appointments (same date, shared client)
- Calculate team index: sum(allocated revenue) / sum(hours worked)
- Display best and worst performing teams per period

### Completion Time
- Assignment workflow should take < 5 minutes for a full week
- Report loading should be < 2 seconds
- Navigation between pages should be instant (SPA routing)

## Technical Requirements

### Stack
- Frontend: Vue 3 (Composition API) + Vite
- Backend: Supabase (PostgreSQL + Auth)
- Routing: Vue Router 4 (hash mode for compatibility)
- Deployment: Cloudflare Pages
- Mobile-first responsive design

### Database Schema
- `periods` - Pay periods (start_date, end_date)
- `employees` - Workers linked to periods
- `work_days` - Employee work days (date, hours)
- `appointments` - Client bookings (date, time, service, cost)
- `client_assignments` - Links work_days to appointments (actual_hours)

### URL Structure
```
/#/                          → redirects to /#/report/default
/#/report/:periodId          → Performance Report
/#/appointments/:periodId    → Appointments by Day
/#/assignments/:periodId     → Team Assignments Management
/#/setup/:periodId           → Setup Client Assignments (3-step workflow)
```

### Security & Compliance
- No authentication required (internal tool)
- GDPR: No personal data stored beyond work records
- Data isolation: Each period is independent
- Cascade delete: Removing period removes all related data

## Success Metrics
- Assignment completion time < 5 minutes
- Report generation time < 2 seconds
- Mobile usability score > 90%
- Zero data loss on period operations
- 100% URL shareability (copy/paste works)

## Future Enhancements (Not in MVP)
- Export to Excel functionality
- Analytics dashboard with charts
- Bilingual UI switching (FR/EN toggle)
- Email report sharing
- Automated performance alerts
- Historical trend analysis
