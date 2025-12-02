<template>
  <div class="modal-overlay" @click="handleClose">
    <div class="modal" @click.stop>
      <h2>Add Time Entry</h2>
      
      <form @submit.prevent="submitEntry">
        <div class="form-group">
          <label>Employee Name *</label>
          <div class="autocomplete-container">
            <input 
              v-model="searchQuery" 
              type="text" 
              required
              placeholder="Type to search employees..."
              @input="filterEmployees"
              @focus="showDropdown = true"
              @blur="hideDropdown"
            >
            <div v-if="showDropdown && filteredEmployees.length > 0" class="dropdown">
              <div 
                v-for="employee in filteredEmployees" 
                :key="employee.id"
                class="dropdown-item"
                @mousedown="selectEmployee(employee)"
              >
                {{ employee.name }}
              </div>
            </div>
          </div>
          <input type="hidden" v-model="form.employeeName" required>
        </div>

        <div class="form-group">
          <label>Period *</label>
          <select v-model="form.periodId" required>
            <option value="">Select a period</option>
            <option v-for="period in periods" :key="period.id" :value="period.id">
              {{ period.startDate }} to {{ period.endDate }}
            </option>
          </select>
        </div>

        <div class="form-group">
          <label>Work Date *</label>
          <input 
            v-model="form.workDate" 
            type="date" 
            required
          >
        </div>

        <div class="form-row">
          <div class="form-group">
            <label>Start Time *</label>
            <input 
              v-model="form.startTime" 
              type="time" 
              required
              @change="calculateHours"
            >
          </div>

          <div class="form-group">
            <label>End Time *</label>
            <input 
              v-model="form.endTime" 
              type="time" 
              required
              @change="calculateHours"
            >
          </div>
        </div>

        <div class="form-group">
          <label>Break (minutes)</label>
          <input 
            v-model.number="form.breakMinutes" 
            type="number" 
            min="0"
            step="1"
            @change="calculateHours"
          >
        </div>

        <div class="calculated-hours">
          <strong>Total Hours:</strong> {{ calculatedHours }}
        </div>

        <div v-if="error" class="error">{{ error }}</div>
        <div v-if="success" class="success">{{ success }}</div>

        <div class="button-group">
          <button type="submit" class="btn-primary" :disabled="saving">
            {{ saving ? 'Saving...' : 'Add Entry' }}
          </button>
          <button type="button" class="btn-secondary" @click="$emit('close')">
            Cancel
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../config/supabase'

const emit = defineEmits(['close', 'success'])

const periods = ref([])
const saving = ref(false)
const error = ref(null)
const success = ref(null)
const searchQuery = ref('')
const showDropdown = ref(false)
const allEmployees = ref([])
const filteredEmployees = ref([])

const form = ref({
  employeeName: '',
  periodId: '',
  workDate: '',
  startTime: '',
  endTime: '',
  breakMinutes: 0
})

onMounted(async () => {
  await loadPeriods()
  await loadAllEmployees()
})

const loadPeriods = async () => {
  const { data } = await supabase
    .from('periods')
    .select('id, start_date, end_date')
    .order('start_date', { ascending: false })
  
  if (data) {
    periods.value = data.map(p => ({
      id: p.id,
      startDate: p.start_date,
      endDate: p.end_date
    }))
  }
}

const loadAllEmployees = async () => {
  const { data } = await supabase
    .from('employees')
    .select('id, name')
    .order('name', { ascending: true })
  
  if (data) {
    allEmployees.value = data
  }
}

const filterEmployees = () => {
  if (!searchQuery.value) {
    filteredEmployees.value = allEmployees.value.slice(0, 10) // Show first 10
  } else {
    const query = searchQuery.value.toLowerCase()
    filteredEmployees.value = allEmployees.value
      .filter(emp => emp.name.toLowerCase().includes(query))
      .slice(0, 10) // Limit to 10 results
  }
}

const selectEmployee = (employee) => {
  form.value.employeeName = employee.name
  searchQuery.value = employee.name
  showDropdown.value = false
}

const hideDropdown = () => {
  setTimeout(() => {
    showDropdown.value = false
  }, 200) // Small delay to allow click events
}

const handleClose = () => {
  emit('close')
}

const calculateHours = () => {
  if (!form.value.startTime || !form.value.endTime) return
  
  const start = new Date(`2000-01-01T${form.value.startTime}`)
  const end = new Date(`2000-01-01T${form.value.endTime}`)
  
  let diffMs = end - start
  if (diffMs < 0) diffMs += 24 * 60 * 60 * 1000 // Handle overnight shift
  
  const totalMinutes = Math.floor(diffMs / 60000) - (form.value.breakMinutes || 0)
  return totalMinutes / 60
}

const calculatedHours = computed(() => {
  const hours = calculateHours()
  if (!hours) return '-'
  
  const h = Math.floor(hours)
  const m = Math.round((hours - h) * 60)
  return `${h}h ${m}m (${hours.toFixed(2)} hours)`
})

const submitEntry = async () => {
  error.value = null
  success.value = null
  saving.value = true
  
  try {
    const hours = calculateHours()
    if (!hours || hours <= 0) {
      throw new Error('Invalid time range. End time must be after start time.')
    }
    
    // Check if employee exists in this period
    let { data: employee } = await supabase
      .from('employees')
      .select('id')
      .eq('period_id', form.value.periodId)
      .eq('name', form.value.employeeName)
      .single()
    
    // If employee doesn't exist, create them
    if (!employee) {
      const { data: newEmployee, error: createError } = await supabase
        .from('employees')
        .insert({
          period_id: form.value.periodId,
          name: form.value.employeeName
        })
        .select()
        .single()
      
      if (createError) throw createError
      employee = newEmployee
    }
    
    // Check if work day already exists
    const { data: existingDay } = await supabase
      .from('work_days')
      .select('id, hours_worked')
      .eq('employee_id', employee.id)
      .eq('work_date', form.value.workDate)
      .single()
    
    if (existingDay) {
      throw new Error(`Work day already exists for ${form.value.employeeName} on ${form.value.workDate} (${existingDay.hours_worked} hours). Delete the existing entry first or edit it.`)
    }
    
    // Insert work day
    const { error: insertError } = await supabase
      .from('work_days')
      .insert({
        employee_id: employee.id,
        work_date: form.value.workDate,
        hours_worked: hours
      })
    
    if (insertError) throw insertError
    
    success.value = 'Time entry added successfully!'
    
    setTimeout(() => {
      emit('success')
      emit('close')
    }, 1500)
    
  } catch (err) {
    error.value = err.message
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
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
  max-width: 500px;
  width: 100%;
  max-height: 90vh;
  overflow-y: auto;
}

.modal h2 {
  margin: 0 0 1.5rem 0;
  color: #333;
}

.form-group {
  margin-bottom: 1.5rem;
}

.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
}

.form-group label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 500;
  color: #333;
}

.form-group input,
.form-group select {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 1rem;
}

.form-group input:focus,
.form-group select:focus {
  outline: none;
  border-color: #F4A000;
}

.calculated-hours {
  padding: 1rem;
  background: #f5f5f5;
  border-radius: 4px;
  margin-bottom: 1.5rem;
  text-align: center;
  color: #333;
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

.button-group {
  display: flex;
  gap: 1rem;
}

.btn-primary,
.btn-secondary {
  flex: 1;
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

.autocomplete-container {
  position: relative;
}

.dropdown {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  background: white;
  border: 1px solid #ddd;
  border-top: none;
  border-radius: 0 0 4px 4px;
  max-height: 200px;
  overflow-y: auto;
  z-index: 1001;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.dropdown-item {
  padding: 0.75rem;
  cursor: pointer;
  border-bottom: 1px solid #f0f0f0;
  transition: background-color 0.2s;
}

.dropdown-item:hover {
  background-color: #f5f5f5;
}

.dropdown-item:last-child {
  border-bottom: none;
}

@media (max-width: 768px) {
  .form-row {
    grid-template-columns: 1fr;
  }

  .button-group {
    flex-direction: column;
  }
}
</style>
