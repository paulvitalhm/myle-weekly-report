<template>
  <div class="app">
    <!-- Header with Period Management -->
    <header class="header">
      <h1>MYLE Employee Performance</h1>
      <div class="header-actions">
        <button 
          v-if="selectedPeriod"
          @click="goToAssignmentSetup" 
          class="btn-secondary"
        >
          ✏️ Setup Assignments
        </button>
        <button @click="showPeriodSelector = true" class="btn-secondary">
          📅 {{ selectedPeriod ? `${selectedPeriod.startDate} to ${selectedPeriod.endDate}` : 'Select Period' }}
        </button>
        <button @click="showUploadModal = true" class="btn-primary">
          📁 Upload Files
        </button>
      </div>
    </header>

    <!-- Period Selector Modal -->
    <div v-if="showPeriodSelector" class="modal-overlay" @click="showPeriodSelector = false">
      <div class="modal" @click.stop>
        <h2>Select Pay Period</h2>
        <div v-if="periods.length === 0" class="empty-state">
          No periods found. Upload files to create a new period.
        </div>
        <div v-else class="period-list">
          <div 
            v-for="period in periods" 
            :key="period.id"
            class="period-item-wrapper"
          >
            <button 
              @click="selectPeriod(period)"
              class="period-item"
              :class="{ active: selectedPeriod?.id === period.id }"
            >
              <div class="period-dates">{{ period.startDate }} to {{ period.endDate }}</div>
              <div class="period-stats">
                {{ period.employeeCount }} employees · {{ period.appointmentCount }} appointments
              </div>
            </button>
            <button 
              @click.stop="deletePeriod(period.id)"
              class="btn-delete"
              title="Delete this period and all its data"
            >
              🗑️
            </button>
          </div>
        </div>
        <button @click="showPeriodSelector = false" class="btn-secondary mt-2">Close</button>
      </div>
    </div>

    <!-- Upload Modal -->
    <div v-if="showUploadModal" class="modal-overlay" @click="showUploadModal = false">
      <div class="modal" @click.stop>
        <h2>Upload Files</h2>
        <div class="upload-area">
          <label class="file-input-label">
            <span>📄 Payroll Report (Excel)</span>
            <input type="file" accept=".xlsx,.xls" @change="handlePayrollFile">
            <span v-if="payrollFile" class="file-name">{{ payrollFile.name }}</span>
          </label>
          <label class="file-input-label">
            <span>📅 Appointments (Excel)</span>
            <input type="file" accept=".xlsx,.xls" @change="handleAppointmentsFile">
            <span v-if="appointmentsFile" class="file-name">{{ appointmentsFile.name }}</span>
          </label>
        </div>
        <div v-if="uploadError" class="error">{{ uploadError }}</div>
        <div v-if="uploadSuccess" class="success">{{ uploadSuccess }}</div>
        <button 
          @click="uploadFiles" 
          :disabled="!payrollFile || !appointmentsFile || uploading"
          class="btn-primary mt-2"
        >
          {{ uploading ? 'Uploading...' : 'Upload & Process' }}
        </button>
        <button @click="showUploadModal = false" class="btn-secondary mt-2">Cancel</button>
      </div>
    </div>

    <!-- Router View -->
    <router-view v-if="selectedPeriod" :periodId="selectedPeriod.id" />
    
    <div v-else class="empty-state-main">
      <h2>Welcome to MYLE Employee Performance</h2>
      <p>Please select a period or upload files to get started.</p>
      <button @click="showUploadModal = true" class="btn-primary">📁 Upload Files</button>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from './config/supabase'
import { useDataParser } from './composables/useDataParser'

const router = useRouter()
const { loadFromFiles } = useDataParser()

const periods = ref([])
const selectedPeriod = ref(null)
const showPeriodSelector = ref(false)
const showUploadModal = ref(false)
const payrollFile = ref(null)
const appointmentsFile = ref(null)
const uploading = ref(false)
const uploadError = ref(null)
const uploadSuccess = ref(null)

onMounted(async () => {
  await loadPeriods()
  if (periods.value.length > 0) {
    await selectPeriod(periods.value[0])
  }
})

const loadPeriods = async () => {
  try {
    const { data, error: err } = await supabase
      .from('periods')
      .select('*, employees(count), appointments(count)')
      .order('start_date', { ascending: false })
    
    if (!err && data) {
      periods.value = data.map(p => ({
        id: p.id,
        startDate: p.start_date,
        endDate: p.end_date,
        employeeCount: p.employees?.[0]?.count || 0,
        appointmentCount: p.appointments?.[0]?.count || 0
      }))
    }
  } catch (err) {
    console.error('Error loading periods:', err)
  }
}

const selectPeriod = async (period) => {
  selectedPeriod.value = period
  showPeriodSelector.value = false
  
  // Navigate to report page with selected period
  if (router.currentRoute.value.path === '/') {
    router.push(`/report/${period.id}`)
  } else {
    // Stay on current page but update periodId
    const currentName = router.currentRoute.value.name
    router.push({ name: currentName, params: { periodId: period.id } })
  }
}

const deletePeriod = async (periodId) => {
  if (!confirm('Are you sure you want to delete this period? This will permanently delete all employees, work days, appointments, and assignments for this period.')) {
    return
  }
  
  try {
    const { data, error: rpcError } = await supabase.rpc('delete_period', {
      p_period_id: periodId
    })
    
    if (rpcError) throw rpcError
    
    const result = data[0]
    if (!result.success) {
      throw new Error(result.message)
    }
    
    // If we deleted the currently selected period, clear selection
    if (selectedPeriod.value?.id === periodId) {
      selectedPeriod.value = null
    }
    
    // Reload periods list
    await loadPeriods()
    
    // If there are other periods, select the first one
    if (periods.value.length > 0 && !selectedPeriod.value) {
      await selectPeriod(periods.value[0])
    }
    
  } catch (err) {
    alert('Error deleting period: ' + err.message)
  }
}

const handlePayrollFile = (e) => {
  payrollFile.value = e.target.files[0]
}

const handleAppointmentsFile = (e) => {
  appointmentsFile.value = e.target.files[0]
}

const goToAssignmentSetup = () => {
  router.push(`/setup/${selectedPeriod.value.id}`)
}

const uploadFiles = async () => {
  if (!payrollFile.value || !appointmentsFile.value) return
  
  uploading.value = true
  uploadError.value = null
  uploadSuccess.value = null
  
  try {
    const { employees: emps, appointments: apts } = await loadFromFiles(
      payrollFile.value, 
      appointmentsFile.value, 
      false
    )
    
    // Calculate period dates
    const allDates = emps.flatMap(e => e.workDays.map(d => d.date))
    const minDate = allDates.reduce((min, date) => date < min ? date : min, allDates[0])
    const maxDate = allDates.reduce((max, date) => date > max ? date : max, allDates[0])
    
    // Prepare data
    const employeesJson = emps.map(emp => ({
      name: emp.name,
      workDays: emp.workDays.map(day => ({
        date: day.date,
        hours: day.hours
      }))
    }))
    
    const appointmentsJson = apts.map(apt => ({
      bookingId: apt.bookingId,
      date: apt.date,
      time: apt.time,
      customer: apt.customer,
      service: apt.service,
      address: apt.address,
      city: apt.city,
      team: apt.team,
      status: apt.status,
      cost: apt.cost
    }))
    
    // Upload to database
    const { data, error: rpcError } = await supabase.rpc('upload_period_data', {
      p_start_date: minDate,
      p_end_date: maxDate,
      p_employees: employeesJson,
      p_appointments: appointmentsJson
    })
    
    if (rpcError) throw rpcError
    
    const result = data[0]
    if (!result.success) {
      throw new Error(result.message)
    }
    
    uploadSuccess.value = 'Files uploaded successfully!'
    
    // Reload periods and select the new one
    await loadPeriods()
    const newPeriod = periods.value.find(p => p.id === result.period_id)
    if (newPeriod) {
      await selectPeriod(newPeriod)
    }
    
    setTimeout(() => {
      showUploadModal.value = false
      uploadSuccess.value = null
      payrollFile.value = null
      appointmentsFile.value = null
    }, 2000)
    
  } catch (err) {
    uploadError.value = err.message
  } finally {
    uploading.value = false
  }
}
</script>

<style scoped>
.app {
  min-height: 100vh;
  background: #f5f5f5;
}

.header {
  background: white;
  padding: 1rem 2rem;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 1rem;
}

.header h1 {
  margin: 0;
  font-size: 1.5rem;
  color: #333;
}

.header-actions {
  display: flex;
  gap: 1rem;
}

.btn-primary, .btn-secondary {
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 1rem;
  transition: all 0.2s;
}

.btn-primary {
  background: #F4A000;
  color: white;
}

.btn-primary:hover:not(:disabled) {
  background: #d89000;
}

.btn-primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-secondary {
  background: white;
  color: #333;
  border: 1px solid #ddd;
}

.btn-secondary:hover {
  background: #f5f5f5;
}

.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0,0,0,0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 1rem;
}

.modal {
  background: white;
  border-radius: 8px;
  padding: 2rem;
  max-width: 600px;
  width: 100%;
  max-height: 80vh;
  overflow-y: auto;
}

.modal h2 {
  margin: 0 0 1.5rem 0;
  color: #333;
}

.period-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  margin-bottom: 1rem;
}

.period-item-wrapper {
  display: flex;
  gap: 0.5rem;
}

.period-item {
  flex: 1;
  padding: 1rem;
  border: 2px solid #e0e0e0;
  border-radius: 4px;
  background: white;
  cursor: pointer;
  text-align: left;
  transition: all 0.2s;
}

.period-item:hover {
  border-color: #F4A000;
  background: #fff8e1;
}

.period-item.active {
  border-color: #F4A000;
  background: #fff3cd;
}

.period-dates {
  font-weight: bold;
  color: #333;
  margin-bottom: 0.25rem;
}

.period-stats {
  font-size: 0.875rem;
  color: #666;
}

.btn-delete {
  padding: 0.5rem 1rem;
  background: #ffebee;
  color: #d32f2f;
  border: 2px solid #ffcdd2;
  border-radius: 4px;
  cursor: pointer;
  font-size: 1.2rem;
  transition: all 0.2s;
}

.btn-delete:hover {
  background: #d32f2f;
  color: white;
}

.upload-area {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  margin-bottom: 1rem;
}

.file-input-label {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  padding: 1rem;
  border: 2px dashed #ddd;
  border-radius: 4px;
  cursor: pointer;
  transition: all 0.2s;
}

.file-input-label:hover {
  border-color: #F4A000;
  background: #fff8e1;
}

.file-input-label input[type="file"] {
  display: none;
}

.file-name {
  font-size: 0.875rem;
  color: #666;
  font-style: italic;
}

.mt-2 {
  margin-top: 1rem;
}

.error {
  color: #d32f2f;
  padding: 1rem;
  background: #ffebee;
  border-radius: 4px;
  margin-bottom: 1rem;
}

.success {
  color: #388e3c;
  padding: 1rem;
  background: #e8f5e9;
  border-radius: 4px;
  margin-bottom: 1rem;
}

.empty-state, .empty-state-main {
  text-align: center;
  padding: 3rem;
  color: #666;
}

.empty-state-main {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 60vh;
  gap: 1rem;
}

.empty-state-main h2 {
  color: #333;
}

@media (max-width: 768px) {
  .header {
    padding: 1rem;
  }

  .header h1 {
    font-size: 1.25rem;
  }
}
</style>
