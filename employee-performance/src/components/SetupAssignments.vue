<template>
  <div class="setup-container">
    <!-- Navigation Bar -->
    <NavigationBar :periodId="periodId" />
    
    <!-- Sticky Header -->
    <div class="sticky-header">
      <h1>Setup Client Assignments</h1>
      <p v-if="periodInfo" class="period-info">
        {{ formatPeriod(periodInfo.startDate, periodInfo.endDate) }}
      </p>
    </div>

    <!-- Loading State -->
    <div v-if="isLoading" class="loading-state">
      <p>Loading data...</p>
    </div>

    <!-- Error State -->
    <div v-if="error" class="error-state">
      <p>{{ error }}</p>
    </div>

    <!-- Main Content -->
    <div v-if="!isLoading && !error" class="content">
      <!-- Step 1: Select Employee -->
      <div class="step-card" :class="{ active: currentStep === 1 }">
        <h2>Step 1: Select Employee</h2>
        <div v-if="employees.length === 0" class="empty-message">
          No employees found for this period. Upload payroll data first.
        </div>
        <div v-else class="employee-grid">
          <button
            v-for="emp in employees"
            :key="emp.id"
            @click="selectEmployee(emp)"
            class="employee-btn"
            :class="{ selected: selectedEmployee?.id === emp.id }"
          >
            {{ emp.name }}
          </button>
        </div>
      </div>

      <!-- Step 2: Select Work Day -->
      <div v-if="selectedEmployee" class="step-card" :class="{ active: currentStep === 2 }">
        <h2>Step 2: Select Work Day for {{ selectedEmployee.name }}</h2>
        <div v-if="workDays.length === 0" class="empty-message">
          No work days found for this employee.
        </div>
        <div v-else class="day-grid">
          <button
            v-for="day in workDays"
            :key="day.id"
            @click="selectWorkDay(day)"
            class="day-btn"
            :class="{ 
              selected: selectedWorkDay?.id === day.id,
              'has-assignments': day.assignmentCount > 0
            }"
          >
            <div class="day-date">{{ formatDate(day.workDate) }}</div>
            <div class="day-hours">{{ formatHours(day.hoursWorked) }}</div>
            <div v-if="day.assignmentCount > 0" class="day-badge">
              {{ day.assignmentCount }} assigned
            </div>
          </button>
        </div>
      </div>

      <!-- Step 3: Assign Clients -->
      <div v-if="selectedWorkDay" class="step-card" :class="{ active: currentStep === 3 }">
        <h2>Step 3: Assign Clients</h2>
        <p class="step-info">
          Assigning for {{ selectedEmployee.name }} on {{ formatDate(selectedWorkDay.workDate) }}
        </p>

        <!-- Search -->
        <input
          v-model="searchQuery"
          type="text"
          placeholder="Search appointments..."
          class="search-input"
        />


        <!-- Appointments List -->
        <div v-if="filteredAppointments.length === 0" class="empty-message">
          No appointments found.
        </div>
        <div v-else class="appointments-list">
          <div
            v-for="apt in filteredAppointments"
            :key="apt.id"
            class="appointment-card"
          >
            <div class="appointment-header">
            <div class="appointment-info">
              <h3>{{ apt.customer_name }}</h3>
              <p class="appointment-details">
                {{ formatDate(apt.appointment_date) }} at {{ apt.appointment_time }}
              </p>
              <p class="appointment-service">{{ apt.service }} · ${{ apt.cost }}</p>
              <p class="appointment-address">{{ apt.address }}, {{ apt.city }}</p>
              
              <!-- Show assigned workers for this appointment -->
              <div v-if="assignedWorkers[apt.id] && assignedWorkers[apt.id].length > 0" class="assigned-workers">
                <p class="workers-title">Assigned Workers:</p>
                <div class="workers-list">
                  <span 
                    v-for="(worker, index) in assignedWorkers[apt.id]" 
                    :key="index"
                    class="worker-tag"
                  >
                    {{ worker }}
                  </span>
                </div>
              </div>
            </div>
              <div class="appointment-actions">
                <button
                  v-if="!isAssigned(apt.id)"
                  @click="showAssignModal(apt)"
                  class="btn-assign"
                >
                  Assign
                </button>
                <button
                  v-else
                  @click="removeAssignment(apt.id)"
                  class="btn-remove"
                >
                  Remove
                </button>
              </div>
            </div>
            <div v-if="isAssigned(apt.id)" class="assignment-info">
              ✓ Assigned ({{ getAssignedHours(apt.id) }}h)
            </div>
          </div>
        </div>
      </div>

      <!-- Current Assignments Summary -->
      <div v-if="currentAssignments.length > 0" class="summary-card">
        <h3>Current Assignments ({{ currentAssignments.length }})</h3>
        <div class="assignments-list">
          <div v-for="assign in currentAssignments" :key="assign.id" class="assignment-card">
            <div class="assignment-header">
              <div class="assignment-main">
                <h4 class="assignment-title">{{ assign.appointmentName }}</h4>
                <div class="assignment-hours">
                  <span class="hours-badge">{{ assign.actualHours }}h</span>
                </div>
              </div>
              <button @click="removeAssignment(assign.appointmentId)" class="btn-remove-small">✕</button>
            </div>
            
            <div class="assignment-details">
              <div v-if="assign.lateArrival > 0" class="detail-item">
                <span class="detail-label">Late Arrival:</span>
                <span class="detail-value negative">{{ formatMinutes(assign.lateArrival) }}</span>
              </div>
              <div v-if="assign.earlyLeave > 0" class="detail-item">
                <span class="detail-label">Early Leave:</span>
                <span class="detail-value negative">{{ formatMinutes(assign.earlyLeave) }}</span>
              </div>
              <div v-if="assign.transportationCost > 0" class="detail-item">
                <span class="detail-label">Transportation Cost:</span>
                <span class="detail-value negative">${{ assign.transportationCost.toFixed(2) }}</span>
              </div>
              <div v-if="assign.lateArrival === 0 && assign.earlyLeave === 0 && assign.transportationCost === 0" class="detail-item">
                <span class="detail-label status-good">No adjustments</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Padding for footer -->
      <div class="footer-spacer"></div>
    </div>

    <!-- Assignment Modal -->
    <div v-if="showModal" class="modal-overlay" @click="showModal = false">
      <div class="modal" @click.stop>
        <div class="modal-header">
          <h2>Assign Client</h2>
          <button class="modal-close" @click="showModal = false">✕</button>
        </div>
        
        <div class="modal-body">
          <div class="appointment-summary">
            <div class="summary-icon">👤</div>
            <div>
              <p class="summary-name">{{ modalAppointment?.customer_name }}</p>
              <p class="summary-service">{{ modalAppointment?.service }}</p>
              <p class="summary-location">{{ modalAppointment?.address }}, {{ modalAppointment?.city }}</p>
            </div>
          </div>

          <div class="work-day-info">
            <div class="info-item">
              <span class="info-label">Work Day Hours:</span>
              <span class="info-value">{{ formatHours(selectedWorkDay?.hoursWorked) }}</span>
            </div>
            <div class="info-item">
              <span class="info-label">Revenue:</span>
              <span class="info-value">${{ modalAppointment?.cost }}</span>
            </div>
          </div>

          <div class="form-section">
            <h3>Time Adjustments</h3>
            <p class="section-hint">These adjustments reduce the employee's contribution to this job</p>
            
            <div class="form-row">
              <div class="form-group">
                <label>Late Arrival (minutes)</label>
                <input
                  v-model.number="modalLateArrival"
                  type="number"
                  min="0"
                  max="480"
                  class="modal-input"
                  placeholder="0"
                />
              </div>

              <div class="form-group">
                <label>Early Leave (minutes)</label>
                <input
                  v-model.number="modalEarlyLeave"
                  type="number"
                  min="0"
                  max="480"
                  class="modal-input"
                  placeholder="0"
                />
              </div>
            </div>

            <div class="form-group">
              <label>Transportation Cost ($)</label>
              <input
                v-model.number="modalTransportationCost"
                type="number"
                step="0.01"
                min="0"
                class="modal-input"
                placeholder="0.00"
              />
              <p class="hint">Cost of transportation incurred by employee</p>
            </div>
          </div>

          <div class="calculation-summary">
            <div class="calc-row">
              <span>Base Hours:</span>
              <span>{{ formatHours(selectedWorkDay?.hoursWorked) }}</span>
            </div>
            <div class="calc-row deduction" v-if="modalLateArrival > 0">
              <span>- Late Arrival:</span>
              <span>{{ formatMinutes(modalLateArrival) }}</span>
            </div>
            <div class="calc-row deduction" v-if="modalEarlyLeave > 0">
              <span>- Early Leave:</span>
              <span>{{ formatMinutes(modalEarlyLeave) }}</span>
            </div>
            <div class="calc-row total">
              <span>Actual Hours:</span>
              <span>{{ formatHours(calculateActualHours()) }}</span>
            </div>
          </div>

          <div v-if="modalError" class="error">{{ modalError }}</div>
        </div>

        <div class="modal-footer">
          <button @click="showModal = false" class="btn-secondary">Cancel</button>
          <button @click="confirmAssignment" class="btn-primary" :disabled="saving">
            {{ saving ? 'Saving...' : 'Assign Client' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Fixed Footer -->
    <div class="fixed-footer">
      <button class="footer-btn" @click="goBack">
        ← Back
      </button>
      <button class="footer-btn" @click="refreshData">
        🔄 Refresh
      </button>
      <button class="footer-btn" @click="clearSelection">
        ✕ Clear
      </button>
      <button class="footer-btn primary" @click="viewReport">
        📊 View Report
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../config/supabase'
import NavigationBar from './NavigationBar.vue'

const router = useRouter()

const props = defineProps({
  periodId: {
    type: String,
    required: true
  }
})

const isLoading = ref(true)
const error = ref(null)
const periodInfo = ref(null)
const employees = ref([])
const selectedEmployee = ref(null)
const workDays = ref([])
const selectedWorkDay = ref(null)
const appointments = ref([])
const currentAssignments = ref([])
const assignedWorkers = ref({}) // Store assigned workers by appointment ID
const searchQuery = ref('')
const showUnassignedOnly = ref(false)
const currentStep = ref(1)

const showModal = ref(false)
const modalAppointment = ref(null)
const modalLateArrival = ref(0)
const modalEarlyLeave = ref(0)
const modalTransportationCost = ref(0)
const modalError = ref(null)
const saving = ref(false)

onMounted(async () => {
  await loadData()
})

watch(() => props.periodId, async () => {
  await loadData()
})

const loadData = async () => {
  isLoading.value = true
  error.value = null

  try {
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

    // Load employees
    const { data: emps } = await supabase
      .from('employees')
      .select('id, name')
      .eq('period_id', props.periodId)
      .order('name')

    employees.value = emps || []

    // Load appointments for this period
    const { data: apts } = await supabase
      .from('appointments')
      .select('*')
      .eq('period_id', props.periodId)
      .order('appointment_date', { ascending: true })

    appointments.value = apts || []

  } catch (err) {
    console.error('Error loading data:', err)
    error.value = err.message
  } finally {
    isLoading.value = false
  }
}

const selectEmployee = async (employee) => {
  selectedEmployee.value = employee
  selectedWorkDay.value = null
  currentAssignments.value = []
  currentStep.value = 2

  // Load work days for this employee
  const { data: days } = await supabase
    .from('work_days')
    .select(`
      id,
      work_date,
      hours_worked,
      client_assignments(count)
    `)
    .eq('employee_id', employee.id)
    .order('work_date')

  workDays.value = (days || []).map(d => ({
    id: d.id,
    workDate: d.work_date,
    hoursWorked: d.hours_worked,
    assignmentCount: d.client_assignments[0]?.count || 0
  }))
}

const selectWorkDay = async (day) => {
  selectedWorkDay.value = day
  currentStep.value = 3

  // Load current assignments for this work day with time adjustments and costs
  const { data: assigns } = await supabase
    .from('client_assignments')
    .select(`
      id,
      actual_hours,
      arrival_delay_minutes,
      early_departure_minutes,
      transportation_cost,
      appointment:appointments(id, customer_name)
    `)
    .eq('work_day_id', day.id)

  currentAssignments.value = (assigns || []).map(a => ({
    id: a.id,
    appointmentId: a.appointment.id,
    appointmentName: a.appointment.customer_name,
    actualHours: a.actual_hours,
    lateArrival: a.arrival_delay_minutes || 0,
    earlyLeave: a.early_departure_minutes || 0,
    transportationCost: a.transportation_cost || 0
  }))

  // Clear and refresh assigned workers cache for this date
  assignedWorkers.value = {}
  const appointmentsForDate = appointments.value.filter(apt => 
    apt.appointment_date === day.workDate
  )
  await loadAssignedWorkersForAppointments(appointmentsForDate)
}

const isAssigned = (appointmentId) => {
  return currentAssignments.value.some(a => a.appointmentId === appointmentId)
}

const getAssignedHours = (appointmentId) => {
  const assignment = currentAssignments.value.find(a => a.appointmentId === appointmentId)
  return assignment ? assignment.actualHours : 0
}

const getAssignedWorkers = async (appointmentId) => {
  try {
    // Query all assignments for this appointment across all work days
    const { data: assignments } = await supabase
      .from('client_assignments')
      .select(`
        id,
        work_day:work_days(
          id,
          employee:employees(id, name)
        )
      `)
      .eq('appointment_id', appointmentId)

    if (!assignments || assignments.length === 0) {
      return []
    }

    // Extract unique worker names
    const workerNames = new Set()
    assignments.forEach(assignment => {
      const workerName = assignment.work_day?.employee?.name
      if (workerName) {
        workerNames.add(workerName)
      }
    })

    return Array.from(workerNames).sort()
  } catch (err) {
    console.error('Error loading assigned workers:', err)
    return []
  }
}

const showAssignModal = (appointment) => {
  modalAppointment.value = appointment
  modalLateArrival.value = 0
  modalEarlyLeave.value = 0
  modalTransportationCost.value = 0
  modalError.value = null
  showModal.value = true
}

const calculateActualHours = () => {
  if (!selectedWorkDay.value) return 0
  
  const baseHours = selectedWorkDay.value.hoursWorked
  const lateMinutes = modalLateArrival.value || 0
  const earlyMinutes = modalEarlyLeave.value || 0
  const deductionHours = (lateMinutes + earlyMinutes) / 60
  
  const actualHours = Math.max(0, baseHours - deductionHours)
  return actualHours
}

const confirmAssignment = async () => {
  const actualHours = calculateActualHours()
  
  if (actualHours < 0.25) {
    modalError.value = 'Actual hours must be at least 0.25 (15 minutes)'
    return
  }

  if (actualHours > 24) {
    modalError.value = 'Actual hours cannot exceed 24 hours'
    return
  }

  saving.value = true
  modalError.value = null

  try {
    const { error: insertError } = await supabase
      .from('client_assignments')
      .insert({
        work_day_id: selectedWorkDay.value.id,
        appointment_id: modalAppointment.value.id,
        arrival_delay_minutes: modalLateArrival.value || 0,
        early_departure_minutes: modalEarlyLeave.value || 0,
        transportation_cost: modalTransportationCost.value || 0,
        actual_hours: actualHours
      })

    if (insertError) throw insertError

    // Reload assignments
    await selectWorkDay(selectedWorkDay.value)

    showModal.value = false
  } catch (err) {
    modalError.value = err.message
  } finally {
    saving.value = false
  }
}

const removeAssignment = async (appointmentId) => {
  if (!confirm('Remove this assignment?')) return

  try {
    const assignment = currentAssignments.value.find(a => a.appointmentId === appointmentId)
    if (!assignment) return

    const { error: deleteError } = await supabase
      .from('client_assignments')
      .delete()
      .eq('id', assignment.id)

    if (deleteError) throw deleteError

    // Reload assignments
    await selectWorkDay(selectedWorkDay.value)
  } catch (err) {
    alert('Error removing assignment: ' + err.message)
  }
}

const filteredAppointments = computed(() => {
  if (!selectedWorkDay.value) return []
  
  // Filter appointments by selected work day date
  let filtered = appointments.value.filter(apt => 
    apt.appointment_date === selectedWorkDay.value.workDate
  )

  // Filter by search query
  if (searchQuery.value) {
    const query = searchQuery.value.toLowerCase()
    filtered = filtered.filter(apt =>
      apt.customer_name.toLowerCase().includes(query) ||
      apt.service.toLowerCase().includes(query) ||
      apt.address.toLowerCase().includes(query)
    )
  }

  // Filter by unassigned only - remove already assigned appointments
  if (showUnassignedOnly.value) {
    filtered = filtered.filter(apt => !isAssigned(apt.id))
  } else {
    // ALWAYS filter out assigned appointments from the main list
    // Assigned appointments only appear in the summary card
    filtered = filtered.filter(apt => !isAssigned(apt.id))
  }

  // Load assigned workers for filtered appointments
  loadAssignedWorkersForAppointments(filtered)

  return filtered
})

// Load assigned workers for visible appointments
const loadAssignedWorkersForAppointments = async (appointments) => {
  for (const apt of appointments) {
    if (!assignedWorkers.value[apt.id]) {
      const workers = await getAssignedWorkers(apt.id)
      assignedWorkers.value[apt.id] = workers
    }
  }
}

const formatPeriod = (start, end) => {
  return `${start} to ${end}`
}

const formatDate = (dateStr) => {
  const date = new Date(dateStr + 'T12:00:00')
  return date.toLocaleDateString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric'
  })
}

const formatHours = (hours) => {
  if (!hours) return '0h 0m'
  const h = Math.floor(hours)
  const m = Math.round((hours - h) * 60)
  return `${h}h ${m}m`
}

const formatMinutes = (minutes) => {
  if (!minutes || minutes === 0) return '0m'
  if (minutes >= 60) {
    const h = Math.floor(minutes / 60)
    const m = minutes % 60
    return m > 0 ? `${h}h ${m}m` : `${h}h`
  }
  return `${minutes}m`
}

const clearSelection = () => {
  selectedEmployee.value = null
  selectedWorkDay.value = null
  workDays.value = []
  currentAssignments.value = []
  currentStep.value = 1
}

const goBack = () => {
  router.back()
}

const refreshData = async () => {
  const emp = selectedEmployee.value
  const day = selectedWorkDay.value
  
  await loadData()
  
  if (emp) {
    const empStillExists = employees.value.find(e => e.id === emp.id)
    if (empStillExists) {
      await selectEmployee(empStillExists)
      
      if (day) {
        const dayStillExists = workDays.value.find(d => d.id === day.id)
        if (dayStillExists) {
          await selectWorkDay(dayStillExists)
        }
      }
    }
  }
}

const viewReport = () => {
  router.push(`/report/${props.periodId}`)
}
</script>

<style scoped>
/* Modern Mobile-First Design System */
.setup-container {
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
}

.period-info {
  margin: 0;
  font-size: 0.875rem;
  opacity: 0.9;
}

.content {
  padding: 1rem;
}

.step-card {
  background: white;
  border-radius: 0.75rem;
  padding: 1.5rem;
  margin-bottom: 1rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  opacity: 0.6;
  transition: all 0.3s;
}

.step-card.active {
  opacity: 1;
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.2);
  border: 2px solid #667eea;
}

.step-card h2 {
  margin: 0 0 1rem 0;
  font-size: 1.125rem;
  color: #1e293b;
}

.step-info {
  margin: 0 0 1rem 0;
  padding: 0.75rem;
  background: #f1f5f9;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  color: #475569;
}

.employee-grid,
.day-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
  gap: 0.75rem;
}

.employee-btn,
.day-btn {
  padding: 1rem;
  border: 2px solid #e2e8f0;
  border-radius: 0.5rem;
  background: white;
  cursor: pointer;
  transition: all 0.2s;
  text-align: left;
}

.employee-btn:hover,
.day-btn:hover {
  border-color: #667eea;
  transform: translateY(-2px);
}

.employee-btn.selected,
.day-btn.selected {
  border-color: #667eea;
  background: #eef2ff;
}

.day-btn {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.day-date {
  font-weight: 600;
  color: #1e293b;
}

.day-hours {
  font-size: 0.875rem;
  color: #64748b;
}

.day-badge {
  font-size: 0.75rem;
  color: #667eea;
  font-weight: 600;
  margin-top: 0.25rem;
}

.day-btn.has-assignments {
  border-color: #10b981;
  background: #f0fdf4;
}

.search-input {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.5rem;
  margin-bottom: 1rem;
  font-size: 0.875rem;
}

.filter-controls {
  margin-bottom: 1rem;
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
  font-size: 0.875rem;
}

.appointments-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.appointment-card {
  border: 1px solid #e2e8f0;
  border-radius: 0.5rem;
  padding: 1rem;
  background: white;
}

.appointment-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 1rem;
}

.appointment-info h3 {
  margin: 0 0 0.5rem 0;
  font-size: 1rem;
  color: #1e293b;
}

.appointment-details,
.appointment-service,
.appointment-address {
  margin: 0.25rem 0;
  font-size: 0.875rem;
  color: #64748b;
}

.appointment-service {
  font-weight: 600;
  color: #667eea;
}

.btn-assign,
.btn-remove {
  padding: 0.5rem 1rem;
  border: none;
  border-radius: 0.375rem;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  white-space: nowrap;
}

.btn-assign {
  background: #667eea;
  color: white;
}

.btn-assign:hover {
  background: #5568d3;
}

.btn-remove {
  background: #fee2e2;
  color: #dc2626;
}

.btn-remove:hover {
  background: #dc2626;
  color: white;
}

.assignment-info {
  margin-top: 0.75rem;
  padding: 0.5rem;
  background: #f0fdf4;
  border-radius: 0.375rem;
  font-size: 0.875rem;
  color: #166534;
  font-weight: 600;
}

/* Assigned Workers Display */
.assigned-workers {
  margin-top: 0.5rem;
}

.workers-title {
  margin: 0 0 0.25rem 0;
  font-size: 0.75rem;
  color: #64748b;
  font-weight: 500;
}

.workers-list {
  display: flex;
  flex-wrap: wrap;
  gap: 0.25rem;
}

.worker-tag {
  display: inline-block;
  padding: 0.25rem 0.5rem;
  background: #e0e7ff;
  color: #4338ca;
  border-radius: 0.25rem;
  font-size: 0.688rem;
  font-weight: 500;
}

.summary-card {
  background: white;
  border-radius: 0.75rem;
  padding: 1.5rem;
  margin-bottom: 1rem;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.summary-card h3 {
  margin: 0 0 1rem 0;
  font-size: 1rem;
  color: #1e293b;
}

.summary-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

/* Enhanced Current Assignments Styles */
.assignments-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.assignment-card {
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 0.5rem;
  padding: 1rem;
  transition: all 0.2s ease;
}

.assignment-card:hover {
  border-color: #cbd5e1;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

.assignment-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 0.75rem;
}

.assignment-main {
  flex: 1;
  min-width: 0;
}

.assignment-title {
  margin: 0 0 0.25rem 0;
  font-size: 0.938rem;
  font-weight: 600;
  color: #1e293b;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.assignment-hours {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.hours-badge {
  background: #667eea;
  color: white;
  padding: 0.25rem 0.5rem;
  border-radius: 0.375rem;
  font-size: 0.75rem;
  font-weight: 600;
}

.assignment-details {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
  padding-top: 0.75rem;
  border-top: 1px solid #f1f5f9;
}

.detail-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.813rem;
}

.detail-label {
  color: #64748b;
  font-weight: 500;
}

.detail-value {
  font-weight: 600;
  color: #374151;
}

.detail-value.negative {
  color: #dc2626;
}

.detail-label.status-good {
  color: #059669;
  font-weight: 600;
}

.btn-remove-small {
  padding: 0.375rem 0.625rem;
  background: #fee2e2;
  color: #dc2626;
  border: none;
  border-radius: 0.375rem;
  cursor: pointer;
  font-weight: 600;
  font-size: 0.75rem;
  transition: all 0.2s ease;
}

.btn-remove-small:hover {
  background: #dc2626;
  color: white;
}

.summary-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.75rem;
  background: #f8fafc;
  border-radius: 0.375rem;
  font-size: 0.875rem;
}

.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 1rem;
}

.modal {
  background: white;
  border-radius: 1rem;
  max-width: 500px;
  width: 100%;
  max-height: 90vh;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem;
  border-bottom: 1px solid #e2e8f0;
}

.modal-header h2 {
  margin: 0;
  font-size: 1.25rem;
  font-weight: 700;
  color: #1e293b;
}

.modal-close {
  background: none;
  border: none;
  font-size: 1.5rem;
  color: #94a3b8;
  cursor: pointer;
  padding: 0.25rem;
  line-height: 1;
  transition: color 0.2s;
}

.modal-close:hover {
  color: #64748b;
}

.modal-body {
  flex: 1;
  overflow-y: auto;
  padding: 1.5rem;
}

.appointment-summary {
  display: flex;
  gap: 1rem;
  padding: 1rem;
  background: linear-gradient(135deg, #f1f5f9 0%, #e2e8f0 100%);
  border-radius: 0.75rem;
  margin-bottom: 1.5rem;
}

.summary-icon {
  font-size: 2.5rem;
  line-height: 1;
}

.summary-name {
  margin: 0 0 0.25rem 0;
  font-weight: 700;
  font-size: 1.125rem;
  color: #1e293b;
}

.summary-service {
  margin: 0 0 0.25rem 0;
  font-size: 0.875rem;
  color: #667eea;
  font-weight: 600;
}

.summary-location {
  margin: 0;
  font-size: 0.813rem;
  color: #64748b;
}

.work-day-info {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
  margin-bottom: 1.5rem;
}

.info-item {
  padding: 0.75rem;
  background: #f8fafc;
  border-radius: 0.5rem;
  border: 1px solid #e2e8f0;
}

.info-label {
  display: block;
  font-size: 0.75rem;
  color: #64748b;
  margin-bottom: 0.25rem;
  font-weight: 500;
}

.info-value {
  display: block;
  font-size: 1.125rem;
  color: #1e293b;
  font-weight: 700;
}

.form-section {
  margin-bottom: 1.5rem;
}

.form-section h3 {
  margin: 0 0 0.5rem 0;
  font-size: 1rem;
  font-weight: 700;
  color: #1e293b;
}

.section-hint {
  margin: 0 0 1rem 0;
  font-size: 0.813rem;
  color: #64748b;
  font-style: italic;
}

.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
  margin-bottom: 1rem;
}

.calculation-summary {
  background: linear-gradient(135deg, #eef2ff 0%, #e0e7ff 100%);
  border: 2px solid #667eea;
  border-radius: 0.75rem;
  padding: 1rem;
  margin-bottom: 1rem;
}

.calc-row {
  display: flex;
  justify-content: space-between;
  padding: 0.5rem 0;
  font-size: 0.938rem;
}

.calc-row.deduction {
  color: #dc2626;
  font-size: 0.875rem;
  padding-left: 1rem;
}

.calc-row.total {
  border-top: 2px solid #667eea;
  margin-top: 0.5rem;
  padding-top: 0.75rem;
  font-weight: 700;
  font-size: 1.063rem;
  color: #667eea;
}

.modal-footer {
  display: flex;
  gap: 0.75rem;
  padding: 1.5rem;
  border-top: 1px solid #e2e8f0;
  background: #f8fafc;
}

.form-group {
  margin-bottom: 1.5rem;
}

.form-group label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 600;
  color: #334155;
}

.modal-input {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.5rem;
  font-size: 1rem;
}

.hint {
  margin: 0.5rem 0 0 0;
  font-size: 0.75rem;
  color: #64748b;
}

.modal-actions {
  display: flex;
  gap: 0.75rem;
}

.btn-primary,
.btn-secondary {
  flex: 1;
  padding: 0.75rem;
  border: none;
  border-radius: 0.5rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-primary {
  background: #667eea;
  color: white;
}

.btn-primary:hover:not(:disabled) {
  background: #5568d3;
}

.btn-primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-secondary {
  background: #f1f5f9;
  color: #475569;
}

.btn-secondary:hover {
  background: #e2e8f0;
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

.footer-spacer {
  height: 20px;
}

.loading-state,
.error-state,
.empty-message {
  text-align: center;
  padding: 2rem;
  color: #64748b;
}

.error-state {
  color: #dc2626;
  background: #fee2e2;
  margin: 1rem;
  border-radius: 0.5rem;
}

.error {
  color: #dc2626;
  padding: 0.75rem;
  background: #fee2e2;
  border-radius: 0.5rem;
  margin-bottom: 1rem;
  font-size: 0.875rem;
}

@media (max-width: 768px) {
  .employee-grid,
  .day-grid {
    grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
  }

  .footer-btn {
    font-size: 0.75rem;
    padding: 0.5rem;
  }
}
</style>
