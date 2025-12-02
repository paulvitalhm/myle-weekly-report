<template>
  <div class="assignment-management-container">
    <NavigationBar :periodId="periodId" />
    
    <div class="sticky-header">
      <h1>Assignment Management</h1>
      <p class="period-info" v-if="periodInfo">
        {{ formatPeriod(periodInfo.startDate, periodInfo.endDate) }}
      </p>
      <p class="subtitle">Manage all appointments and worker assignments in one place</p>
    </div>

    <div v-if="loading" class="loading-state">
      <p>Loading assignments...</p>
    </div>

    <div v-if="error" class="error-state">
      <p>{{ error }}</p>
    </div>

    <div v-if="!loading && !error" class="content">
      <!-- Quick Stats -->
      <div class="quick-stats">
        <div class="stat-card">
          <div class="stat-number">{{ totalAppointments }}</div>
          <div class="stat-label">Total Appointments</div>
        </div>
        <div class="stat-card urgent">
          <div class="stat-number">{{ unassignedCount }}</div>
          <div class="stat-label">Need Assignment</div>
        </div>
        <div class="stat-card">
          <div class="stat-number">{{ assignedCount }}</div>
          <div class="stat-label">Fully Assigned</div>
        </div>
        <div class="stat-card">
          <div class="stat-number">{{ workers.length }}</div>
          <div class="stat-label">Available Workers</div>
        </div>
      </div>

      <!-- Assignment List -->
      <AssignmentList
        :appointments="appointments"
        :assignments="assignments"
        :workers="workers"
        @bulk-assign="handleBulkAssign"
        @refresh="loadData"
        @assign="showAssignModal"
        @edit="showEditModal"
      />
    </div>

    <!-- Assignment Modal -->
    <AssignmentModal
      :show="showModal"
      :appointment="selectedAppointment"
      :workers="availableWorkers"
      :mode="modalMode"
      @close="closeModal"
      @save="handleAssignmentSave"
    />

    <!-- Multi-Worker Selector Modal -->
    <MultiWorkerSelector
      v-if="showWorkerSelector"
      :workers="availableWorkers"
      :current-assignments="currentAssignments"
      @cancel="closeWorkerSelector"
      @confirm="handleWorkerSelection"
    />

    <div class="fixed-footer">
      <button class="footer-btn" @click="goBack">
        ← Back
      </button>
      <button class="footer-btn" @click="refreshData">
        🔄 Refresh
      </button>
      <button class="footer-btn primary" @click="viewAnalytics">
        📊 Analytics
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../config/supabase'
import NavigationBar from './NavigationBar.vue'
import AssignmentList from './assignment-management/AssignmentList.vue'
import AssignmentModal from './assignment-management/AssignmentModal.vue'
import MultiWorkerSelector from './assignment-management/MultiWorkerSelector.vue'

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
const appointments = ref([])
const assignments = ref([])
const workers = ref([])
const selectedAppointment = ref(null)
const modalMode = ref('assign') // 'assign' or 'edit'
const showModal = ref(false)
const showWorkerSelector = ref(false)
const selectedWorkers = ref([])

// Computed
const totalAppointments = computed(() => appointments.value.length)
const unassignedCount = computed(() => {
  return appointments.value.filter(apt => {
    const assignmentCount = assignments.value.filter(a => a.appointment_id === apt.id).length
    return assignmentCount === 0
  }).length
})
const assignedCount = computed(() => {
  return appointments.value.filter(apt => {
    const assignmentCount = assignments.value.filter(a => a.appointment_id === apt.id).length
    return assignmentCount >= 2 // Multiple workers = fully assigned
  }).length
})
const availableWorkers = computed(() => workers.value)

// Lifecycle
onMounted(async () => {
  await loadData()
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

    // Load all data in parallel
    const [appointmentsData, assignmentsData, workersData] = await Promise.all([
      loadAppointments(),
      loadAssignments(),
      loadWorkers()
    ])

    appointments.value = appointmentsData
    assignments.value = assignmentsData
    workers.value = workersData

    loading.value = false
  } catch (err) {
    console.error('Error loading assignment data:', err)
    error.value = err.message
    loading.value = false
  }
}

const loadAppointments = async () => {
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
        employee_id,
        employee:employees(id, name)
      )
    `)
    .eq('work_day.employee.period_id', props.periodId)
  
  return data || []
}

const loadWorkers = async () => {
  const { data } = await supabase
    .from('employees')
    .select('id, name, role, experience, max_assignments')
    .eq('period_id', props.periodId)
    .order('name', { ascending: true })
  
  return data || []
}

const showAssignModal = (appointment) => {
  selectedAppointment.value = appointment
  modalMode.value = 'assign'
  showModal.value = true
}

const showEditModal = (appointment) => {
  selectedAppointment.value = appointment
  modalMode.value = 'edit'
  showModal.value = true
}

const closeModal = () => {
  showModal.value = false
  selectedAppointment.value = null
}

const handleAssignmentSave = async (assignmentData) => {
  try {
    if (modalMode.value === 'assign') {
      // Create new assignments for selected workers
      for (const workerId of assignmentData.workerIds) {
        // Create work day if it doesn't exist
        const workDayDate = selectedAppointment.value.appointment_date
        const { data: existingWorkDay } = await supabase
          .from('work_days')
          .select('id')
          .eq('employee_id', workerId)
          .eq('work_date', workDayDate)
          .single()

        let workDayId = existingWorkDay?.id

        if (!workDayId) {
          const { data: newWorkDay } = await supabase
            .from('work_days')
            .insert({
              employee_id: workerId,
              work_date: workDayDate,
              hours_worked: 0
            })
            .select()
            .single()
          workDayId = newWorkDay.id
        }

        // Create assignment
        await supabase
          .from('client_assignments')
          .insert({
            work_day_id: workDayId,
            appointment_id: selectedAppointment.value.id,
            actual_hours: assignmentData.actualHours || 0,
            arrival_delay_minutes: assignmentData.lateArrival || 0,
            early_departure_minutes: assignmentData.earlyLeave || 0,
            transportation_cost: assignmentData.transportationCost || 0
          })
      }
    } else {
      // Edit existing assignment
      const assignment = assignments.value.find(a => 
        a.appointment_id === selectedAppointment.value.id
      )
      
      if (assignment) {
        await supabase
          .from('client_assignments')
          .update({
            arrival_delay_minutes: assignmentData.lateArrival || 0,
            early_departure_minutes: assignmentData.earlyLeave || 0,
            transportation_cost: assignmentData.transportationCost || 0,
            actual_hours: assignmentData.actualHours || 0
          })
          .eq('id', assignment.id)
      }
    }

    await loadData()
    closeModal()
  } catch (err) {
    console.error('Error saving assignment:', err)
    error.value = 'Failed to save assignment. Please try again.'
  }
}

const handleBulkAssign = () => {
  // For bulk assignment, we'll show the worker selector
  showWorkerSelector.value = true
}

const closeWorkerSelector = () => {
  showWorkerSelector.value = false
  selectedWorkers.value = []
}

const handleWorkerSelection = (workerIds) => {
  selectedWorkers.value = workerIds
  // Process bulk assignment
  // This would need to be implemented based on your specific requirements
  closeWorkerSelector()
}

const handleBulkAssignmentSave = async () => {
  // Implement bulk assignment logic
  // This would create assignments for all selected appointments with selected workers
  console.log('Bulk assignment:', selectedWorkers.value)
}

const refreshData = async () => {
  await loadData()
}

const goBack = () => {
  router.back()
}

const viewAnalytics = () => {
  router.push(`/analytics/${props.periodId}`)
}

const formatPeriod = (start, end) => {
  return `${start} to ${end}`
}
</script>

<style scoped>
.assignment-management-container {
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

.content {
  padding: 1rem;
}

.quick-stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 1rem;
  margin-bottom: 2rem;
}

.stat-card {
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 0.75rem;
  padding: 1.5rem;
  text-align: center;
  transition: all 0.2s ease;
}

.stat-card:hover {
  border-color: #cbd5e1;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
}

.stat-card.urgent {
  border-left: 4px solid #dc2626;
}

.stat-number {
  font-size: 2rem;
  font-weight: 700;
  color: #1e293b;
  margin-bottom: 0.25rem;
}

.stat-label {
  font-size: 0.875rem;
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

@media (max-width: 768px) {
  .quick-stats {
    grid-template-columns: repeat(2, 1fr);
  }
  
  .footer-btn {
    font-size: 0.75rem;
    padding: 0.5rem;
  }
}
</style>
