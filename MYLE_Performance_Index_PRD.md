# Product Requirements Document (PRD)
## MYLE Employee Performance Index System

### 1. Project Overview

- **Project Name:** Employee Performance Index Dashboard
- **Main Goal:** Create an automated system to calculate and track revenue-per-hour performance metrics for MYLE Home Services cleaning teams, with employee self-reporting for job mappings.
- **What We Want to Do:** Build a tool that processes uploaded timesheet and appointment Excel data to calculate daily and individual performance indices (revenue/hour), with manual job-to-employee mapping via employee self-reporting through shareable links and a manager dashboard for oversight.
- **Why We Want to Do It:** Currently no visibility into which employees or teams are most profitable per hour worked, making it difficult to optimize scheduling, identify top performers, and improve overall business efficiency. Employee self-reporting will ensure accurate mappings.
- **Success State (What Will Be Different):** Management will have clear, data-driven insights into employee and team performance, enabling better scheduling decisions, fair performance evaluations, and identification of training needs, with accurate data from employee inputs.

### 2. Context and Background

- **Key pain points or metrics motivating this project:**
  - Unable to determine which employees generate the most revenue per hour worked
  - Team assignments in booking system (Team A, Team B, Online Booking) don't directly map to actual employees
  - No way to account for employees joining/leaving jobs mid-day or working partial shifts
  - Daily revenue of $740-$1,150 with 2-6 employees working, but no visibility into individual contribution
  - Need for employee involvement in mapping to improve accuracy and buy-in
  
- **Related initiatives or dependencies:**
  - Time Squared timesheet system (Excel exports)
  - Appointment booking system (Excel exports with formats as in provided samples: Payroll_report_11-03-2025_to_11-08-2025.xlsx and Appointments (22).xlsx)
  - Future integration with Shifts app for team planning
  - Slack for communications and notifications
  
- **Stakeholders or teams impacted:**
  - Paul Vital (CEO) - needs performance data for business decisions
  - Nanette - will prepare shift planning data and upload files
  - Field employees (Angela, Ariane, Mariana, MADE, Nanette, Soraya) - self-report mappings and view their worked days
  - Accounting - payroll verification

### 3. User Stories

- **Employee:**
  - **As an employee,** I want to access a personalized web page via a unique URL sent by my manager, which lists all the days I worked along with the durations from my timesheet, **so that** I can easily review and report my client assignments for accurate performance tracking.
  - **Acceptance Criteria:**
    - [ ] The page loads without requiring login (URL is unique and time-limited for security).
    - [ ] Days are listed in chronological order, showing date, total hours worked (from timesheet), and a button (e.g., "Assign Clients" or "Ajouter Clients") to start the assignment process.
    - [ ] Upon clicking the button for a day, a form displays a checkbox list of all appointments/clients for that day (pulled from the appointment system), presented as cards with context: Appointment date, Appointment time, Service/class/event, Customer name, Address.
    - [ ] For each selected client, a follow-up prompt asks if I was present for the full duration; if not, fields for arrival delay or early departure (in hours and minutes) appear, with full duration as default.
    - [ ] Validation ensures at least one client is selected if hours were recorded, total selected client times (adjusted for offsets) do not exceed timesheet hours (block submission with error message if exceeded), and submission provides confirmation (e.g., "Assignments saved successfully").
    - [ ] The page is mobile-friendly, bilingual (French/English), and supports self-edits within 24 hours (configurable by manager).
    - [ ] After submission, the day is marked as "Completed" to prevent duplicate edits unless reopened by the manager or within edit window.

- **Manager:**
  - **As a manager,** I want to select a time period (e.g., date range) and generate unique, shareable links for each employee, **so that** they can self-report their client assignments per worked day, enabling accurate job mapping for performance calculations.
  - **Acceptance Criteria:**
    - [ ] In the dashboard, a "Generate Employee Links" section allows selecting a start/end date (default: last 7 days) and uploading Excel files for timesheets and appointments (formats matching provided samples).
    - [ ] System lists eligible employees (based on timesheet data in the period) and generates one unique URL per employee upon request (copy-paste sharing to start, future Slack integration).
    - [ ] URLs are copyable/sendable and expire after a set time (e.g., 7 days) or after submission.
    - [ ] Manager can view a status overview (e.g., "Pending/Completed" per employee/day) and resend links if needed.
    - [ ] Once employees submit, data auto-updates in the system for index calculations, with Slack notifications to the manager on submissions.
    - [ ] Option to revoke/reopen links for edits if data needs correction.
    - [ ] Integrates with uploaded data sources (timesheets and appointments) to pre-populate lists without further manual uploads.
    - [ ] Audit log tracks who submitted what and when for accountability.
    - [ ] Manager reviews submissions in dashboard (view mappings, flag issues), approves/rejects (best option: simple approve button per employee/period, with auto-flagging for inconsistencies like time overages), before data is used for indices.

- **Original Manager/Owner (retained and updated):**
    - *As a manager, I want to see daily team performance indices so that I can identify which days are most profitable.*
    - *As a manager, I want to track individual employee performance over time so that I can make fair performance evaluations.*
    - *As a manager, I want to manually map jobs to employees so that the system accurately reflects who worked where.* (Updated: supplemented by employee self-reporting, with manager override/review).
    - Acceptance Criteria:
        - [ ] Can view daily index sorted by profitability
        - [ ] Can see breakdown of revenue, hours, and employees per day
        - [ ] Can export data for further analysis
        - [ ] Can manually assign jobs to employees via drag-and-drop interface (mobile-compatible if possible; fallback to simple forms)

- **Operations Coordinator (retained):**
    - *As an operations coordinator, I want to upload timesheet and appointment data so that indices are calculated automatically.*
    - *As an operations coordinator, I want to validate team assignments before index calculation so that data is accurate.*
    - Acceptance Criteria:
        - [ ] Can upload Excel/CSV files for both timesheets and appointments (specific formats as in samples)
        - [ ] Can review and correct employee-job mappings
        - [ ] Can flag incomplete data (like missing hours)

### 4. Constraints and Requirements

- **Constraints:**
  - Must work with existing Time Squared export format (Excel with individual employee sheets, as in Payroll_report_11-03-2025_to_11-08-2025.xlsx)
  - Must handle appointments export format with "Team member" field that doesn't directly identify employees (as in Appointments (22).xlsx, including details like date, time, service, customer name, address, cost/revenue)
  - Must account for employees working partial days, joining mid-shift, or leaving early (via hours + minutes offsets in self-reporting)
  - Maximum team size is typically 3 people (rarely up to 6)
  - Must run on Windows machines for manager uploads; mobile-first for employee interface
  - Must use Vue.js (not React) for web interfaces; bilingual (French/English); simplest UI for mobile (drag-and-drop if mobile-compatible, else forms/checklists)
  - Data access via manual Excel uploads by manager; system parses uploads to extract timesheets (hours per day per employee) and appointments (list per day with context)
  - Historical data support for backfilling past periods
  - Security: Unique token-based links for employees (simplest implementation)
  - Notifications primarily via Slack (e.g., on submissions); copy-paste links to start
  - No automatic revenue splitting; collect mappings only for later manual/calculated use

- **Requirements:**
  - Calculate daily team index (total revenue / total hours for all employees)
  - Support employee self-reporting for job-to-employee mapping with visual interface (cards for client context)
  - Handle time overlaps and partial shifts correctly (validate against timesheet totals, block over-reporting)
  - Export results to CSV/Excel for further analysis
  - Flag incomplete or suspicious data (e.g., missing hours, unusual patterns, days with no appointments skipped or flagged)
  - Support date range selection (typically weekly periods), including historical
  - Employee self-edit window: 24 hours post-submission, configurable by manager
  - Manager approval workflow: Dashboard review with approve/reject per submission

### 5. Expected Outcomes

- **List of deliverables/changes expected upon successful completion:**
  - Daily team index report showing revenue per hour by day
  - Individual employee performance indices when job mapping is complete
  - Vue.js interface for employee self-reporting (mobile-first forms/cards) and manager dashboard (upload, link generation, review/approve)
  - CSV export functionality for all reports
  - Documentation for using the system, including file upload formats and bilingual UI
  - Slack notification integration for submissions
  
- **Success metrics (qualitative or quantitative):**
  - 100% of days have calculated team indices (post-mapping)
  - Ability to identify top 20% performing days/employees
  - Reduce time to calculate performance metrics from hours to minutes
  - Accurate attribution of at least 90% of revenue to specific employees
  - Employee submission completion rate >80% within 48 hours
  
- **How will we measure success?**
  - Time saved in performance analysis (target: <5 minutes per week)
  - Accuracy of job assignments validated against actual work logs and sample data (Nov 3-8, 2025)
  - User satisfaction with the interface and reports (e.g., feedback from employees on mobile ease)

### 6. Risks & Open Questions

- **What are the major risks or open questions?**
  - Risk: Inaccurate job-to-employee mapping if employees misreport or don't submit
  - Risk: Employees may not record hours accurately or timely (e.g., Soraya on Nov 8)
  - Risk: Mobile UI challenges with drag-and-drop; fallback to forms may reduce usability
  - Question: How to handle jobs that span multiple employees joining/leaving at different times? (Handled via offsets, but complex overlaps flagged)
  - Question: Should we integrate with Shifts app API if available? (Future)
  - Question: How to handle employees working at multiple locations on the same day? (Supported via multiple selections with time validation)
  
- **What assumptions are being made?**
  - Uploaded Excel data matches sample formats and is accurate
  - Appointment costs in the system reflect actual revenue
  - Employees working at the same time can be grouped into teams via mappings
  - Manual mapping via self-reporting is acceptable and improves accuracy
  
- **What clarification is still needed?**
  - Exact handling of tips or additional revenue not in appointment system
  - Frequency of updates needed (daily, weekly, monthly?)
  - Full Slack integration details (e.g., bot for link sharing/notifications)

### 7. Acceptance Criteria / Definition of Done

- **The project is considered complete when:**
    - [ ] Daily team index calculation works for any selected date range, including historical
    - [ ] Individual employee indices can be calculated after job mapping and manager approval
    - [ ] Vue.js interface allows employee self-reporting (forms/cards with context) and manager link generation/upload/review
    - [ ] System handles all edge cases (partial shifts, multiple shifts, missing data flagged/skipped, over-reporting blocked)
    - [ ] Export functionality produces clean CSV files
    - [ ] Results match manual calculations for test period (Nov 3-8, 2025) using provided Excel files
    - [ ] Documentation covers upload process, mapping interface, approval workflow, and report interpretation
    - [ ] System flags incomplete data (like Soraya's missing hours on Nov 8)
    - [ ] Bilingual support and mobile-first design validated on devices
    - [ ] Self-edit and configurable timers implemented
    - [ ] Slack notifications for submissions functional (or stubbed for MVP)

### 8. Future Considerations

- **Features or enhancements deferred for future phases:**
  - Automatic team inference using machine learning
  - Full Slack bot integration for link sharing and notifications
  - Integration with Shifts app for automatic team assignments
  - Real-time dashboard with live updates
  - Mobile app for employees to view their own performance
  - Predictive analytics for optimal team composition
  - Integration with payroll system for performance bonuses
  - Historical trend analysis and seasonality detection
  - Customer satisfaction correlation with team performance
  - Drag-and-drop enhancements if mobile compatibility improves
  
- **Notes to revisit in later cycles:**
  - Consider GPS/location tracking for automatic job assignment
  - Evaluate integration with Slack for team assignments
  - Explore automated parsing of communication logs for team formation
  - Add quality metrics beyond revenue per hour
  - Advanced validation for revenue splitting (currently manual post-mapping)

---

*Document Version: 2.0*  
*Date: November 9, 2025*  
*Author: System Design Team*  
*Status: In Development*