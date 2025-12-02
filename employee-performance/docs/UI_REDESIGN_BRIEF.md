# Performance Report UI Redesign Brief
**Date:** 2025-11-10
**Status:** Planning Phase - Designer Input Needed

## 🎯 Objective
Transform the Performance Report from a **table-based layout** to a **mobile-first card-based layout** while preserving ALL existing business logic and calculations.

---

## 📋 Current UI (Table Version)

### Layout Structure:
1. **Report Header**
   - Title: "MYLE Employee Performance Report"
   - Period dates (long format)
   - Period stats (calendar days, work records)

2. **Report Description**
   - Yellow-bordered info box explaining the report

3. **Performance Index Table**
   - 6 columns: Rank | Index | Tier | Who | When | Where
   - Sortable rows with hover effects
   - Color-coded tier badges (green/yellow/red)

4. **Best/Worst Team Cards**
   - Green card for best team
   - Red card for worst team
   - Shows: Date, Members, Tier, Index, Clients, Total Hours

5. **Hours Discrepancies** (commented out)
   - Not currently shown

### Current Tier Logic (DO NOT CHANGE):
```javascript
if (index >= 47) return 'Top'    // Green badge
if (index >= 35) return 'Good'   // Yellow badge
return 'Low'                      // Red badge
```

---

## 🎨 Desired UI (Card Version)

### Proposed Layout:

#### 1. Performance Index Cards (Instead of Table)
Each performance entry becomes a **compact card**:

**Card Structure (3-line design):**
```
┌─────────────────────────────────────────────┐
│ [#Rank] | Employee Name | [Tier Badge]      │  ← Line 1
│                                             │
│          [Large Index Number]                │  ← Line 2 (prominent)
│                                             │
│ Date (hours worked) | Client names         │  ← Line 3
└─────────────────────────────────────────────┘
```

**Visual Requirements:**
- **Line 1:** 
  - Purple rank badge with white text (#1, #2, etc.)
  - Employee name (max 20 chars, truncate with "...")
  - Tier badge (same colors as table: green/yellow/red)
  
- **Line 2:**
  - Performance index in LARGE font (3rem)
  - Purple color (#667eea)
  - Centered on card
  
- **Line 3:**
  - Gray text for secondary info
  - Date in format: "Mon, Nov 04 2024"
  - Hours in format: "8h 30m"
  - Client names (max 30 chars, truncate with "...")

**Card Styling:**
- White background
- 2px gray border (changes to purple on hover)
- Rounded corners (8px)
- Vertical stack layout
- 12px gap between cards
- Hover effect: border color change + slight lift

#### 2. Team Cards (Keep Same Design)
✅ Keep existing green/red gradient cards
✅ Keep same content and structure
✅ No changes needed

#### 3. Action Buttons (NEW - for sharing feature)
Add two buttons at top:
- 🔗 Share Report (purple button)
- 📸 Download Image (green button)

---

## 🔒 What MUST Stay the Same (Business Logic)

### Database Queries:
```javascript
// ✅ KEEP EXACTLY AS IS
const { data } = await supabase.rpc('get_performance_index', {
  p_period_id: props.periodId
})
```

### Data Mapping:
```javascript
// ✅ KEEP EXACTLY AS IS
{
  rank: row.rank,
  index: row.index,
  tier: getTier(row.index),  // Use existing function!
  who: row.who,
  when: row.when,
  where: row.where || 'Pending',
  earned: row.earned,
  workDayId: row.work_day_id,
  workDate: row.work_date,
  hoursWorked: row.hours_worked
}
```

### Tier Calculation:
```javascript
// ✅ KEEP EXACTLY AS IS - DO NOT CHANGE THRESHOLDS
const getTier = (index) => {
  if (index >= 47) return 'Top'
  if (index >= 35) return 'Good'
  return 'Low'
}
```

### Team Detection:
```javascript
// ✅ KEEP ALL team detection logic
// - detectTeams() function
// - calculateTeamPerformance() function
// - Shared appointments logic
// DO NOT SIMPLIFY OR CHANGE
```

### Date/Time Formatting:
```javascript
// ✅ KEEP existing formatting functions
// - formatPeriodDates()
// - formatDateLong()
// - formatHours()
```

---

## 📱 Mobile Responsiveness

### Breakpoint: 768px

**Desktop (>768px):**
- Cards: full width within container
- Action buttons: side-by-side
- Font sizes: as specified above

**Mobile (≤768px):**
- Cards: stack vertically with full width
- Action buttons: stack vertically
- Reduced font sizes:
  - Rank badge: 1rem
  - Index: 2.5rem
  - Other text: 0.85-1rem

---

## 🎨 Design System

### Colors:
- **Primary Purple:** #667eea (rank badges, index numbers, share button)
- **Tier Colors:**
  - Top: #48bb78 (green)
  - Good: #4299e1 (blue) 
  - Low: #f56565 (red)
- **Text:**
  - Primary: #2d3748
  - Secondary: #718096
  - Tertiary: #cbd5e0
- **Backgrounds:**
  - White: #ffffff
  - Light gray: #f8f9fa

### Typography:
- **Font Family:** -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif
- **Weights:**
  - Regular: 400
  - Medium: 500
  - Semibold: 600
  - Bold: 700

### Spacing:
- Card padding: 16px
- Card gap: 12px
- Section margin: 40px
- Border radius: 8px

---

## ✅ Acceptance Criteria

1. **Visual:** Cards display all same data as table rows
2. **Logic:** All tier calculations produce identical results
3. **Teams:** Best/worst teams show same values as before
4. **Mobile:** Fully responsive on all screen sizes
5. **Performance:** No degradation in load times
6. **Accessibility:** WCAG AA compliant (keyboard nav, screen readers)

---

## 🚫 Out of Scope (For This Task)

- ❌ Changing tier thresholds
- ❌ Modifying database queries
- ❌ Altering team detection logic
- ❌ Adding new calculations
- ❌ Removing any data fields
- ❌ Changing hours discrepancies logic (already commented out)

---

## 📦 Deliverables

1. New `ShareableReport.vue` component with card-based UI
2. Keep original `PerformanceReport.vue` as backup
3. Updated routing in `App.vue`
4. Documentation of changes
5. Visual comparison screenshots

---

## 💡 Questions for Designer

1. Should rank badge be circular or rectangular?
2. Should we add icons to action buttons?
3. Should cards have drop shadows or just borders?
4. Any animation/transition preferences for hover states?
5. Should there be a "compact view" toggle option?

---

## 📝 Implementation Notes

**Priority:** Preserve all existing business logic EXACTLY as is.
**Approach:** Copy PerformanceReport.vue → rename to ShareableReport.vue → modify ONLY the template and styles.
**Testing:** Compare output values side-by-side with original table version to ensure 100% accuracy.
