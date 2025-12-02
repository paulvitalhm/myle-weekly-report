<template>
  <div class="period-overview-container">
    <NavigationBar :periodId="periodId" />
    
    <div class="sticky-header">
      <h1>Period Overview Calendar</h1>
      <p class="period-info" v-if="periodInfo">
        {{ formatPeriod(periodInfo.startDate, periodInfo.endDate) }}
      </p>
      <p class="subtitle">Visual schedule with performance insights</p>
    </div>

    <!-- Search and Filter Controls -->
    <div class="filter-bar">
      <div class="search-section">
        <input 
          v-model="searchQuery" 
          type="text" 
          placeholder="🔍 Search by worker, client, address, service..."
          class="search-input"
        />
        <button @click="clearSearch" v-if="searchQuery" class="btn-clear-search">
          ✕
        </button>
      </div>
      
      <div class="view-controls">
        <button 
          @click="toggleView" 
          class="btn-view-toggle"
          :class="{ active: isMobileView }"
        >
          {{ isMobileView ? '📱 Mobile' : '🖥️ Desktop' }}
        </button>
      </div>
    </div>

    <!-- Quick Stats -->
    <div class="quick-stats">
      <div class="stat-card">
        <div class="stat-number">{{ totalJobs }}</div>
        <div class="stat-label">Total Jobs</div>
      </div>
      <div class="stat-card">
        <div class="stat-number">{{ activeWorkers }}</div>
        <div class="stat-label">Active Workers</div>
      </div>
      <div class="stat-card">
        <div class="stat-number">{{ formatCurrency(totalRevenue) }}</div>
        <div class="stat-label">Total Revenue</div>
      </div>
      <div class="stat-card">
        <div class="stat-number">{{ formatHours(totalHours) }}</div>
        <div class="stat-label">Total Hours</div>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="loading-state">
      <p>Loading calendar data...</p>
    </div>

    <!-- Error State -->
    <div v-if="error" class="error-state">
      <p>{{ error }}</p>
    </div>

    <!-- Calendar View -->
    <div v-if="!loading && !error" class="calendar-container">
      <!-- Mobile Day Navigation -->
      <div v-if="isMobileView" class="mobile-day-nav">
        <button @click="previousDay" :disabled="currentDayIndex === 0" class="nav-btn">
          ←
        </button>
        <div class="current-day-info">
          <div class="day-name">{{ currentDayName }}</div>
          <div class="day-date">{{ currentDayDate }}</div>
        </div>
        <button @click="nextDay" :disabled="currentDayIndex === days.length - 1" class="nav-btn">
          →
        </button>
      </div>

      <!-- Desktop Calendar Grid -->
      <div v-if="!isMobileView" class="desktop-calendar">
        <div class="calendar-header">
          <div v-for="day in days" :key="day.date" class="day-header">
            <div class="day-name">{{ formatDayName(day.date) }}</div>
            <div class="day-date">{{ formatDayDate(day.date) }}</div>
            <button 
              @click="toggleDaySummary(day.date)" 
              class="summary-toggle"
              :class="{ active: isDaySummaryExpanded(day.date) }"
            >
              {{ isDaySummaryExpanded(day.date) ? '▼' : '▶' }}
            </button>
          </div>
        </div>

        <!-- Day Summary Row (Desktop) -->
        <div v-if="hasAnyExpandedSummary" class="summary-row">
          <div v-for="day in days" :key="day.date" class="day-summary-cell">
            <DaySummary 
              v-if="isDaySummaryExpanded(day.date)"
              :day="day"
              :workers="getDayWorkers(day.date)"
              :jobs="getDayJobs(day.date)"
            />
          </div>
        </div>

        <!-- Time Grid -->
        <div class="time-grid">
          <div class="time-labels">
            <div v-for="hour in timeSlots" :key="hour" class="time-label">
              {{ formatHour(hour) }}
            </div>
          </div>
          
          <div class="day-columns">
            <div v-for="day in days" :key="day.date" class="day-column">
              <div v-for="hour in timeSlots" :key="`${day.date}-${hour}`" class="time-slot">
                <JobCard
                  v-for="job in getJobsForTimeSlot(day.date, hour)"
                  :key="job.id"
                  :job="job"
                  :workers="getJobWorkers(job)"
                  @click="showJobDetails(job)"
                />
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Mobile Calendar View -->
      <div v-else class="mobile-calendar">
        <div class="mobile-day-content">
          <DaySummary 
            :day="currentDay"
            :workers="getDayWorkers(currentDay.date)"
            :jobs="getDayJobs(currentDay.date)"
            :expanded="true"
          />
          
          <div class="mobile-time-grid">
            <div v-for="hour in getMobileTimeSlots()" :key="hour" class="mobile-time-slot">
              <div class="mobile-time-label">{{ formatHour(hour) }}</div>
              <div class="mobile-jobs">
                <JobCard
                  v-for="job in getJobsForTimeSlot(currentDay.date, hour)"
                  :key="job.id"
                  :job="job"
                  :workers="getJobWorkers(job)"
                  :compact="true"
                  @click="showJobDetails(job)"
                />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Job Details Modal -->
    <JobDetailsModal
      v-if="showJobModal"
      :job="selectedJob"
      :workers="getJobWorkers(selectedJob)"
      @close="closeJobModal"
    />

    <div class="fixed-footer">
      <button class="footer-btn" @click="goBack">
        ← Back
      </button>
      <button class="footer-btn" @click="refreshData">
        🔄 Refresh
      </button>
      <button class="footer-btn primary" @click="exportCalendar">
        📊 Export
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../config/supabase'
import NavigationBar from './NavigationBar.vue'
import DaySummary from './calendar/DaySummary.vue'
import JobCard from './calendar/JobCard.vue'
import JobDetailsModal from './calendar/JobDetailsModal.vue'

const router = useRouter()

const props = defineProps({
  periodId: {
    type: String,
    required: true
  }
})

// State
const loading = ref(true)
const error = ref(null)
const periodInfo = ref(null)
const days = ref([])
const jobs = ref([])
const assignments = ref([])
const workers = ref([])
const searchQuery = ref('')
const isMobileView = ref(false)
const currentDayIndex = ref(0)
const expandedSummaries = ref(new Set())
const selectedJob = ref(null)
const showJobModal = ref(false)

// Computed
const currentDay = computed(() => days.value[currentDayIndex.value] || null)

const currentDayName = computed(() => {
  if (!currentDay.value) return ''
  return formatDayName(currentDay.value.date)
})

const currentDayDate = computed(() => {
  if (!currentDay.value) return ''
  return formatDayDate(currentDay.value.date)
})

const filteredJobs = computed(() => {
  if (!searchQuery.value) return jobs.value
  
  const query = searchQuery.value.toLowerCase()
  return jobs.value.filter(job => {
    // Search in client name
    if (job.customer_name?.toLowerCase().includes(query)) return true
    
    // Search in service type
    if (job.service?.toLowerCase().includes(query)) return true
    
    // Search in address
    if (job.address?.toLowerCase().includes(query)) return true
    
    // Search in city
    if (job.city?.toLowerCase().includes(query)) return true
    
    // Search in assigned workers
    const jobWorkers = getJobWorkers(job)
    if (jobWorkers.some(worker => worker.toLowerCase().includes(query))) return true
    
    return false
  })
})

const timeSlots = computed(() => {
  const slots = []
  for (let hour = 8; hour <= 19; hour++) {
    if (hasJobsAtHour(hour)) {
      slots.push(hour)
    }
  }
  return slots
})

const totalJobs = computed(() => filteredJobs.value.length)
const totalRevenue = computed(() => filteredJobs.value.reduce((sum, job) => sum + (job.cost || 0), 0))
const totalHours = computed(() => {
  // Calculate total hours from assignments
  return assignments.value.reduce((sum, assignment) => sum + (assignment.actual_hours || 0), 0)
})
const activeWorkers = computed(() => {
  const workerIds = new Set()
  assignments.value.forEach(assignment => {
    if (assignment.work_day?.employee?.id) {
      workerIds.add(assignment.work_day.employee.id)
    }
  })
  return workerIds.size
})

const hasAnyExpandedSummary = computed(() => expandedSummaries.value.size > 0)

// Lifecycle
onMounted(async () => {
  await loadData()
  checkMobileView()
  window.addEventListener('resize', checkMobileView)
})

onUnmounted(() => {
  window.removeEventListener('resize', checkMobileView)
})

// Methods
const loadData = async () => {
  try {
    loading.value = true
    error.value = null

    // Load period info
    const { data: period } = await supabase
      .from('periods')
      .select('start_date, end_date')
      .eq('id', props.periodId)
      .single()

    if (!period) throw new Error('Period not found')
    periodInfo.value = {
      startDate: period.start_date,
      endDate: period.end_date
    }

    // Generate days array
    days.value = generateDays(period.start_date, period.end_date)

    // Load all data in parallel
    const [jobsData, assignmentsData, workersData] = await Promise.all([
      loadJobs(),
      loadAssignments(),
      loadWorkers()
    ])

    jobs.value = jobsData
    assignments.value = assignmentsData
    workers.value = workersData

    loading.value = false
  } catch (err) {
    console.error('Error loading calendar data:', err)
    error.value = err.message
    loading.value = false
  }
}

const loadJobs = async () => {
  const { data } = await supabase
    .from('appointments')
    .select('*')
    .eq('period_id', props.periodId)
    .order('appointment_date', { ascending: true })
    .order('appointment_time', { ascending: true })
  
  return data || []
}

const loadAssignments = async () => {
  const { data } = await supabase
    .from('client_assignments')
    .select(`
      id,
      appointment_id,
      work_day_id,
      actual_hours,
      arrival_delay_minutes,
      early_departure_minutes,
      transportation_cost,
      work_day:work_days(
        id,
        work_date,
        hours_worked,
        employee:employees(id, name)
      )
    `)
    .eq('work_day.employee.period_id', props.periodId)
  
  return data || []
}

const loadWorkers = async () => {
  const { data } = await supabase
    .from('employees')
    .select('id, name, role, experience')
    .eq('period_id', props.periodId)
    .order('name', { ascending: true })
  
  return data || []
}

const generateDays = (startDate, endDate) => {
  const days = []
  const start = new Date(startDate)
  const end = new Date(endDate)
  
  for (let date = new Date(start); date <= end; date.setDate(date.getDate() + 1)) {
    days.push({
      date: date.toISOString().split('T')[0],
      dayOfWeek: date.getDay()
    })
  }
  
  return days
}

const hasJobsAtHour = (hour) => {
  return filteredJobs.value.some(job => {
    const jobHour = parseInt(job.appointment_time.split(':')[0])
    return jobHour === hour
  })
}

const getJobsForTimeSlot = (dayDate, hour) => {
  return filteredJobs.value.filter(job => {
    return job.appointment_date === dayDate && 
           parseInt(job.appointment_time.split(':')[0]) === hour
  })
}

const getJobWorkers = (job) => {
  const jobAssignments = assignments.value.filter(a => a.appointment_id === job.id)
  return jobAssignments.map(assignment => {
    return assignment.work_day?.employee?.name || 'Unknown Worker'
  })
}

const getDayWorkers = (dayDate) => {
  const dayJobs = jobs.value.filter(job => job.appointment_date === dayDate)
  const workerIds = new Set()
  
  dayJobs.forEach(job => {
    const jobAssignments = assignments.value.filter(a => a.appointment_id === job.id)
    jobAssignments.forEach(assignment => {
      if (assignment.work_day?.employee?.id) {
        workerIds.add(assignment.work_day.employee.id)
      }
    })
  })
  
  return Array.from(workerIds).map(id => {
    const worker = workers.value.find(w => w.id === id)
    return worker ? worker.name : 'Unknown Worker'
  })
}

const getDayJobs = (dayDate) => {
  return jobs.value.filter(job => job.appointment_date === dayDate)
}

const getMobileTimeSlots = () => {
  // For mobile, show all time slots that have jobs on current day
  const slots = []
  for (let hour = 8; hour <= 19; hour++) {
    const jobsAtHour = getJobsForTimeSlot(currentDay.value.date, hour)
    if (jobsAtHour.length > 0) {
      slots.push(hour)
    }
  }
  return slots
}

const toggleDaySummary = (dayDate) => {
  if (expandedSummaries.value.has(dayDate)) {
    expandedSummaries.value.delete(dayDate)
  } else {
    expandedSummaries.value.add(dayDate)
  }
}

const isDaySummaryExpanded = (dayDate) => {
  return expandedSummaries.value.has(dayDate)
}

const previousDay = () => {
  if (currentDayIndex.value > 0) {
    currentDayIndex.value--
  }
}

const nextDay = () => {
  if (currentDayIndex.value < days.value.length - 1) {
    currentDayIndex.value++
  }
}

const toggleView = () => {
  isMobileView.value = !isMobileView.value
}

const checkMobileView = () => {
  isMobileView.value = window.innerWidth < 768
}

const showJobDetails = (job) => {
  selectedJob.value = job
  showJobModal.value = true
}

const closeJobModal = () => {
  showJobModal.value = false
  selectedJob.value = null
}

const clearSearch = () => {
  searchQuery.value = ''
}

const refreshData = async () => {
  await loadData()
}

const goBack = () => {
  router.back()
}

const exportCalendar = () => {
  // Implementation for calendar export
  console.log('Export calendar data')
}

// Formatting functions
const formatPeriod = (start, end) => {
  return `${start} to ${end}`
}

const formatDayName = (dateStr) => {
  const date = new Date(dateStr + 'T12:00:00')
  return date.toLocaleDateString('en-US', { weekday: 'short' }).toUpperCase()
}

const formatDayDate = (dateStr) => {
  const date = new Date(dateStr + 'T12:00:00')
  return date.toLocaleDateString('en-US', { 
    month: 'short', 
    day: 'numeric' 
  })
}

const formatHour = (hour) => {
  const period = hour >= 12 ? 'PM' : 'AM'
  const displayHour = hour > 12 ? hour - 12 : hour
  return `${displayHour}:00 ${period}`
}

const formatCurrency = (amount) => {
  return (amount || 0).toFixed(2)
}

const formatHours = (hours) => {
  if (!hours) return '0h 0m'
  const h = Math.floor(hours)
  const m = Math.round((hours - h) * 60)
  return m > 0 ? `${h}h ${m}m` : `${h}h`
}
</script>

<style scoped>
.period-overview-container {
  min-height: 100vh;
  background: #ffffff;
  padding-bottom: 80px;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

.sticky-header {
  position: sticky;
  top: 0;
  z-index: 100;
  background: #ffffff;
  color: #1e293b;
  padding: 1rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  border-bottom: 1px solid #e2e8f0;
}

.sticky-header h1 {
  margin: 0 0 0.5rem 0;
  font-size: 1.25rem;
  font-weight: 700;
}

.period-info {
  margin: 0 0 0.5rem 0;
  font-size: 0.875rem;
  color: #64748b;
}

.subtitle {
  margin: 0;
  font-size: 0.813rem;
  color: #64748b;
  font-style: italic;
}

.filter-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem;
  gap: 1rem;
  flex-wrap: wrap;
}

.search-section {
  display: flex;
  align-items: center;
  flex: 1;
  min-width: 300px;
  position: relative;
}

.search-input {
  flex: 1;
  padding: 0.75rem 2.5rem 0.75rem 0.75rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.5rem;
  font-size: 0.875rem;
}

.btn-clear-search {
  position: absolute;
  right: 0.5rem;
  background: none;
  border: none;
  font-size: 1rem;
  color: #94a3b8;
  cursor: pointer;
  padding: 0.5rem;
}

.btn-clear-search:hover {
  color: #64748b;
}

.view-controls {
  display: flex;
  gap: 0.5rem;
}

.btn-view-toggle {
  padding: 0.5rem 1rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.375rem;
  background: white;
  color: #64748b;
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-view-toggle:hover {
  border-color: #667eea;
  color: #667eea;
}

.btn-view-toggle.active {
  background: #667eea;
  color: white;
  border-color: #667eea;
}

.quick-stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 1rem;
  padding: 1rem;
}

.stat-card {
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 0.75rem;
  padding: 1rem;
  text-align: center;
  transition: all 0.2s ease;
}

.stat-card:hover {
  border-color: #cbd5e1;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

.stat-number {
  font-size: 1.5rem;
  font-weight: 700;
  color: #1e293b;
  margin-bottom: 0.25rem;
}

.stat-label {
  font-size: 0.75rem;
  color: #64748b;
  font-weight: 500;
}

.loading-state,
.error-state {
  text-align: center;
  padding: 3rem 1rem;
  color: #64748b;
}

.error-state {
  color: #dc2626;
  background: #fee2e2;
  margin: 1rem;
  border-radius: 0.5rem;
}

.calendar-container {
  padding: 1rem;
}

/* Mobile Day Navigation */
.mobile-day-nav {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem;
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 0.75rem;
  margin-bottom: 1rem;
}

.nav-btn {
  padding: 0.75rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.5rem;
  background: white;
  color: #64748b;
  font-size: 1.25rem;
  cursor: pointer;
  transition: all 0.2s;
}

.nav-btn:hover:not(:disabled) {
  border-color: #667eea;
  color: #667eea;
}

.nav-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.current-day-info {
  text-align: center;
}

.day-name {
  font-size: 1.125rem;
  font-weight: 700;
  color: #1e293b;
  margin-bottom: 0.25rem;
}

.day-date {
  font-size: 0.875rem;
  color: #64748b;
}

/* Desktop Calendar */
.desktop-calendar {
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 0.75rem;
  overflow: hidden;
}

.calendar-header {
  display: grid;
  grid-template-columns: 80px repeat(auto-fit, minmax(200px, 1fr));
  background: #f8fafc;
  border-bottom: 1px solid #e2e8f0;
}

.day-header {
  padding: 1rem;
  text-align: center;
  border-right: 1px solid #e2e8f0;
  position: relative;
}

.day-header:last-child {
  border-right: none;
}

.day-name {
  font-size: 0.875rem;
  font-weight: 600;
  color: #374151;
  margin-bottom: 0.25rem;
}

.day-date {
  font-size: 0.75rem;
  color: #64748b;
}

.summary-toggle {
  position: absolute;
  top: 0.5rem;
  right: 0.5rem;
  background: none;
  border: none;
  font-size: 0.75rem;
  color: #94a3b8;
  cursor: pointer;
  padding: 0.25rem;
  transition: color 0.2s;
}

.summary-toggle:hover {
  color: #667eea;
}

.summary-toggle.active {
  color: #667eea;
}

.summary-row {
  display: grid;
  grid-template-columns: 80px repeat(auto-fit, minmax(200px, 1fr));
  background: #f1f5f9;
  border-bottom: 1px solid #e2e8f0;
}

.day-summary-cell {
  padding: 1rem;
  border-right: 1px solid #e2e8f0;
}

.day-summary-cell:last-child {
  border-right: none;
}

.time-grid {
  display: grid;
  grid-template-columns: 80px repeat(auto-fit, minmax(200px, 1fr));
  min-height: 400px;
}

.time-labels {
  background: #f8fafc;
  border-right: 1px solid #e2e8f0;
}

.time-label {
  padding: 1rem 0.5rem;
  border-bottom: 1px solid #e2e8f0;
  font-size: 0.75rem;
  color: #64748b;
  text-align: center;
  height: 80px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.time-label:last-child {
  border-bottom: none;
}

.day-columns {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
}

.day-column {
  border-right: 1px solid #e2e8f0;
  display: flex;
  flex-direction: column;
}

.day-column:last-child {
  border-right: none;
}

.time-slot {
  border-bottom: 1px solid #e2e8f0;
  min-height: 80px;
  padding: 0.5rem;
  position: relative;
}

.time-slot:last-child {
  border-bottom: none;
}

/* Mobile Calendar */
.mobile-calendar {
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 0.75rem;
  overflow: hidden;
}

.mobile-day-content {
  padding: 1rem;
}

.mobile-time-grid {
  margin-top: 1rem;
}

.mobile-time-slot {
  display: flex;
  gap: 1rem;
  margin-bottom: 1rem;
  padding-bottom: 1rem;
  border-bottom: 1px solid #f1f5f9;
}

.mobile-time-slot:last-child {
  margin-bottom: 0;
  padding-bottom: 0;
  border-bottom: none;
}

.mobile-time-label {
  flex-shrink: 0;
  width: 80px;
  font-size: 0.75rem;
  color: #64748b;
  font-weight: 500;
}

.mobile-jobs {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.fixed-footer {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background: white;
  border-top: 1px solid #e2e8f0;
  display: flex;
  justify-content: space-around;
  padding: 0.75rem;
  box-shadow: 0 -2px 8px rgba(0, 0, 0, 0.05);
  z-index: 100;
}

.footer-btn {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  background: none;
  border: none;
  cursor: pointer;
  color: #64748b;
  font-size: 0.875rem;
  font-weight: 500;
  transition: color 0.2s;
  white-space: nowrap;
}

.footer-btn:hover {
  color: #667eea;
}

.footer-btn.primary {
  background: #667eea;
  color: white;
  border-radius: 0.5rem;
}

.footer-btn.primary:hover {
  background: #5568d3;
}

@media (max-width: 768px) {
  .filter-bar {
    flex-direction: column;
    align-items: stretch;
  }
  
  .search-section {
    min-width: auto;
  }
  
  .quick-stats {
    grid-template-columns: repeat(2, 1fr);
  }
  
  .calendar-header,
  .summary-row,
  .time-grid {
    display: none;
  }
  
  .footer-btn {
    font-size: 0.75rem;
    padding: 0.5rem;
  }
}
</style>
