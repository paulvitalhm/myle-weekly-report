<template>
  <div class="appointments-container">
    <NavigationBar :periodId="periodId" />
    
    <div class="header">
      <h1>Appointments Calendar</h1>
      <p class="period">{{ periodDates }}</p>
      
      <div class="controls">
        <input v-model="searchQuery" placeholder="Search appointments..." class="search">
        <select v-model="viewMode" class="view-toggle">
          <option value="list">List</option>
          <option value="calendar">Calendar</option>
        </select>
      </div>
    </div>

    <div v-if="loading" class="loading">Loading...</div>
    <div v-else-if="error" class="error">{{ error }}</div>
    
    <div v-else class="content">
      <ListView 
        v-if="viewMode === 'list'" 
        :appointments="filteredAppointments"
        @view="viewAppointment"
        @assign="assignWorker"
      />
      <CalendarView 
        v-else 
        :appointments="filteredAppointments"
        :current-week="currentWeekStart"
        @previous="previousWeek"
        @next="nextWeek"
        @view="viewAppointment"
      />
    </div>

    <div class="footer">
      <button @click="goBack">← Back</button>
      <button @click="refreshData">🔄 Refresh</button>
      <button @click="exportData">📊 Export</button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import NavigationBar from './NavigationBar.vue'
import ListView from './appointments/ListView.vue'
import CalendarView from './appointments/CalendarView.vue'
import { supabase } from '../config/supabase'

const props = defineProps({
  periodId: { type: String, required: true }
})

const router = useRouter()
const loading = ref(true)
const error = ref(null)
const searchQuery = ref('')
const viewMode = ref('list')
const currentWeekStart = ref(new Date())
const appointments = ref([])
const periodDates = ref('Loading...')

// Computed
const filteredAppointments = computed(() => {
  if (!searchQuery.value) return appointments.value
  const query = searchQuery.value.toLowerCase()
  return appointments.value.filter(apt => 
    apt.customer_name.toLowerCase().includes(query) ||
    apt.service.toLowerCase().includes(query) ||
    apt.address.toLowerCase().includes(query) ||
    apt.city.toLowerCase().includes(query)
  )
})

// Methods
const loadData = async () => {
  try {
    loading.value = true
    
    // Load period info
    const { data: period } = await supabase
      .from('periods')
      .select('start_date, end_date')
      .eq('id', props.periodId)
      .single()

    if (!period) throw new Error('Period not found')
    
    periodDates.value = `${formatDate(period.start_date)} - ${formatDate(period.end_date)}`

    // Load appointments with worker assignment info
    const { data: appointmentsData } = await supabase
      .from('appointments')
      .select(`
        *,
        assigned_workers:client_assignments(
          work_day:work_days(
            employee:employees(id, name)
          )
        )
      `)
      .eq('period_id', props.periodId)
      .order('appointment_date', { ascending: true })
      .order('appointment_time', { ascending: true })

    // Process appointments to include assigned worker names
    appointments.value = (appointmentsData || []).map(apt => ({
      ...apt,
      assignedWorkers: apt.assigned_workers?.map(assignment => 
        assignment.work_day?.employee?.name
      ).filter(Boolean) || []
    }))

    loading.value = false
  } catch (err) {
    console.error('Error loading appointments:', err)
    error.value = err.message
    loading.value = false
  }
}

const previousWeek = () => {
  const newDate = new Date(currentWeekStart.value)
  newDate.setDate(newDate.getDate() - 7)
  currentWeekStart.value = newDate
}

const nextWeek = () => {
  const newDate = new Date(currentWeekStart.value)
  newDate.setDate(newDate.getDate() + 7)
  currentWeekStart.value = newDate
}

const viewAppointment = (apt) => {
  console.log('View appointment:', apt)
  // Could open a modal or navigate to detail view
}

const assignWorker = (apt) => {
  console.log('Assign worker to:', apt)
  // Could open assignment modal or navigate to assignment page
}

const exportData = () => {
  const data = {
    appointments: filteredAppointments.value,
    period: periodDates.value,
    exportDate: new Date().toISOString()
  }
  downloadJSON(data, `appointments-${props.periodId}.json`)
}

const refreshData = () => {
  loadData()
}

const goBack = () => {
  router.back()
}

const downloadJSON = (data, filename) => {
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}

const formatDate = (dateStr) => {
  const date = new Date(dateStr + 'T12:00:00')
  return date.toLocaleDateString('en-US', { 
    weekday: 'short',
    month: 'short',
    day: 'numeric'
  })
}

// Lifecycle
onMounted(() => {
  loadData()
})
</script>

<style scoped>
.appointments-container {
  min-height: 100vh;
  background: #f5f5f5;
  padding-bottom: 80px;
}

.header {
  background: white;
  padding: 1rem;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.header h1 {
  margin: 0 0 0.5rem 0;
  font-size: 1.5rem;
}

.period {
  margin: 0 0 1rem 0;
  color: #666;
}

.controls {
  display: flex;
  gap: 1rem;
}

.search {
  flex: 1;
  padding: 0.5rem;
  border: 1px solid #ddd;
  border-radius: 4px;
}

.view-toggle {
  padding: 0.5rem;
  border: 1px solid #ddd;
  border-radius: 4px;
}

.content {
  padding: 1rem;
}

.loading, .error {
  text-align: center;
  padding: 2rem;
}

.error {
  color: #d32f2f;
}

.footer {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background: white;
  border-top: 1px solid #ddd;
  display: flex;
  justify-content: space-around;
  padding: 1rem;
}

.footer button {
  padding: 0.5rem 1rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  background: white;
  cursor: pointer;
}

.footer button:hover {
  background: #f5f5f5;
}
</style>
