# MYLE Employee Performance - User Guide

## Overview
MYLE Employee Performance is a bilingual (FR/EN) web application that enables managers to track employee performance, manage client assignments, and generate shareable performance reports. The system analyzes value created per hour worked to identify top performers and optimize team compositions.

## Quick Start

### 1. Access the Application
- Open your web browser and navigate to the application URL
- The application works on desktop, tablet, and mobile devices

### 2. Upload Your Data
1. Click **"📁 Upload Files"** in the header
2. Select your **Payroll Report (Excel)** file
3. Select your **Appointments (Excel)** file  
4. Click **"Upload & Process"**
5. The system will automatically create a new period with your data

### 3. Set Up Client Assignments
1. Click **"✏️ Setup Assignments"** in the header
2. **Step 1**: Select an employee from the grid
3. **Step 2**: Choose a work day (green border = has assignments)
4. **Step 3**: Assign clients to that work day
5. Enter actual hours worked, late arrival, early leave, and transportation costs
6. Click **"Assign Client"** to save

### 4. View Performance Reports
1. Click **"📊 Reports"** in the header
2. View individual performance index rankings
3. See best and worst performing teams
4. Search by employee name or filter by performance tier
5. Share reports via link or download as image

## Main Features

### 📊 Performance Reports
- **Individual Rankings**: Employees ranked by performance index (revenue per hour)
- **Tier System**: Top (≥47), Good (35-46), Low (<35) performers
- **Team Performance**: Best and worst performing teams automatically detected
- **Shareable**: Copy link or download image to share with others

### ✏️ Setup Assignments (3-Step Process)
**Step 1: Select Employee**
- Grid of all employees in the period
- Click to select

**Step 2: Select Work Day** 
- Grid of work days for selected employee
- Green border = has existing assignments
- Shows assignment count badge

**Step 3: Assign Clients**
- Shows only unassigned appointments for that specific date
- Search by client name, service, or address
- Click "Assign" to open assignment modal
- Enter time adjustments and transportation costs
- Assigned appointments move to summary section

### 📅 Appointments by Day
- **Calendar View**: Weekly grid showing appointments by day
- **List View**: Chronological list grouped by date
- **Assignment Status**: Visual indicators for assigned vs unassigned
- **Search**: Find appointments by client, address, service, or worker
- **Day Summaries**: Shows total jobs, revenue, and assigned workers per day

### 👥 Team Assignments
- **Team Detection**: Automatically identifies teams working together
- **Performance Metrics**: Team index, revenue, efficiency calculations
- **Assignment Management**: Edit or delete existing assignments
- **Filters**: View all, completed, or pending assignments
- **Export**: Download team data as JSON

### ⏰ Add Time Entry
- **Manual Entry**: Add missing time entries not in payroll upload
- **Auto-Calculation**: Calculates total hours from start/end times
- **Employee Search**: Searchable autocomplete from existing employees
- **Validation**: Prevents duplicate entries and validates time ranges

## Performance Index Explained

The Performance Index measures value created per hour worked:
```
Performance Index = Total Revenue ÷ Total Hours Worked
```

**Tier Thresholds:**
- 🟢 **Top Performing**: Index ≥ 47
- 🟡 **Good**: Index 35-46.9  
- 🔴 **Low Performing**: Index < 35

**Revenue Allocation:**
Revenue is allocated proportionally based on actual hours worked on each appointment, minus any transportation costs.

## Mobile Usage

The application is optimized for mobile devices:
- **Touch-Friendly**: Large buttons and tap targets
- **Responsive Design**: Adapts to screen size
- **Swipe Navigation**: Natural mobile interactions
- **Offline Capability**: Works without internet after initial load

## Sharing Reports

### Via Link
1. Click **"🔗 Share Report"** button
2. Link automatically copies to clipboard
3. Send via text message, email, or any messaging app
4. Recipients can view the report without logging in

### Via Image
1. Click **"📸 Download Image"** button  
2. High-quality PNG image generates automatically
3. Image downloads to your device
4. Share the image file anywhere

## Troubleshooting

### "No employees found"
- Upload payroll data first using the upload feature
- Ensure your Excel file has employee names in the correct format

### "0 work records" showing
- This was a bug that has been fixed
- Make sure you've uploaded both payroll and appointments files
- Check that the period has valid data

### Can't assign clients to employee
- Ensure the employee has work days in the selected period
- Verify the work day date matches appointment dates
- Check that appointments haven't already been assigned

### Report not loading
- Refresh the page (Ctrl+R or Cmd+R)
- Check your internet connection
- Verify the period ID in the URL is valid

### Share link not working
- The link format should be: `your-domain.com/report/{periodId}`
- Ensure the period hasn't been deleted
- Try copying the link again

## Tips for Best Results

1. **Upload Complete Data**: Include both payroll and appointments files for accurate reporting
2. **Assign All Appointments**: Complete assignments for better performance analysis
3. **Use Search Features**: Quickly find specific employees or appointments
4. **Check Multiple Periods**: Compare performance across different time periods
5. **Export Data**: Use JSON export for backup or further analysis

## Support
For technical issues or questions about using the application, refer to the Technical Guide or contact your system administrator.

---
*Last updated: November 2025*
