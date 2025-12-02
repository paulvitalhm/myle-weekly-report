# Routing & New Pages Implementation

## Status: IN PROGRESS

## Goal
Add Vue Router with unique shareable URLs and create two new pages:
1. Appointments by Day (calendar view)
2. Team Assignments (assignment management with unassigned filter)

## Progress Checklist

### Phase 1: Router Setup ✅
- [x] Install vue-router@4
- [x] Create router configuration (`src/router/index.js`)
- [x] Create NavigationBar component
- [x] Update main.js to use router

### Phase 2: App.vue Refactoring (IN PROGRESS)
- [ ] Extract period management to composable
- [ ] Simplify App.vue to shell with router-view
- [ ] Move upload/period selector to shared components
- [ ] Test basic routing works

### Phase 3: AppointmentsByDay Component
- [ ] Create component file
- [ ] Implement sticky header with search/filter
- [ ] Group appointments by date
- [ ] Create day summary cards
- [ ] Implement expandable appointment cards
- [ ] Add footer action buttons
- [ ] Test with real data

### Phase 4: TeamAssignments Component
- [ ] Create component file
- [ ] Implement sticky header with search/filter
- [ ] List all assignments
- [ ] Add "Unassigned Only" filter toggle
- [ ] Implement expandable detail view
- [ ] Add edit/delete functionality
- [ ] Add footer action buttons
- [ ] Test CRUD operations

### Phase 5: Testing & Polish
- [ ] Test all routes with periodId parameter
- [ ] Verify shareable URLs work
- [ ] Test navigation between pages
- [ ] Mobile responsive testing
- [ ] Build and deploy test

## URL Structure

```
/#/ → redirects to /#/report/default
/#/report/:periodId → Performance Report (ShareableReport.vue)
/#/appointments/:periodId → Appointments by Day (new)
/#/assignments/:periodId → Team Assignments (new)
```

Using hash mode (`createWebHashHistory`) for better compatibility without server configuration.

## Components Structure

```
src/
├── router/
│   └── index.js (router config)
├── components/
│   ├── NavigationBar.vue ✅
│   ├── ShareableReport.vue (existing, now routed)
│   ├── AppointmentsByDay.vue (NEW)
│   └── TeamAssignments.vue (NEW)
├── composables/
│   ├── useDataParser.js (existing)
│   └── usePeriodManager.js (NEW - extract from App.vue)
└── App.vue (simplified to router shell)
```

## Next Steps
1. Create usePeriodManager composable
2. Refactor App.vue to use router-view
3. Create stub components for new pages
4. Test routing works end-to-end
5. Implement full features for each page

## Notes
- Keep all business logic from existing components
- Mobile-first design for all new pages
- Use same color scheme and patterns as ShareableReport
- Ensure all pages work with periodId from URL
