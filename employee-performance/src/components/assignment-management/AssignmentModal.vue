<template>
  <div v-if="show" class="modal-overlay" @click="$emit('close')">
    <div class="modal-content" @click.stop>
      <div class="modal-header">
        <h3>{{ modalTitle }}</h3>
        <button @click="$emit('close')" class="modal-close">×</button>
      </div>
      
      <div class="modal-body">
        <!-- Appointment Summary -->
        <div class="appointment-summary">
          <div class="summary-icon">📅</div>
          <div class="summary-details">
            <h4 class="client-name">{{ appointment?.customer_name }}</h4>
            <p class="appointment-time">
              {{ formatDate(appointment?.appointment_date) }} at {{ appointment?.appointment_time }}
            </p>
            <p class="service-info">{{ appointment?.service }} · ${{ appointment?.cost }}</p>
            <p class="address-info">{{ appointment?.address }}, {{ appointment?.city }}</p>
          </div>
        </div>

        <!-- Worker Selection (for assign mode) -->
        <div v-if="mode === 'assign'" class="section">
          <h4>Select Workers</h4>
          <MultiWorkerSelector
            :workers="workers"
            :current-assignments="currentAssignments"
            @update:selected="updateSelectedWorkers"
          />
        </div>

        <!-- Assignment Details -->
        <div class="section">
          <h4>Assignment Details</h4>
          
          <div class="form-grid">
            <div class="form-group">
              <label>Actual Hours</label>
              <input
                v-model.number="formData.actualHours"
                type="number"
                min="0"
                step="0.5"
                class="form-input"
                placeholder="0.0"
              />
            </div>

            <div class="form-group">
              <label>Late Arrival (minutes)</label>
              <input
                v-model.number="formData.lateArrival"
                type="number"
                min="0"
                max="480"
                class="form-input"
                placeholder="0"
              />
            </div>

            <div class="form-group">
              <label>Early Leave (minutes)</label>
              <input
                v-model.number="formData.earlyLeave"
                type="number"
                min="0"
                max="480"
                class="form-input"
                placeholder="0"
              />
            </div>

            <div class="form-group">
              <label>Transportation Cost ($)</label>
              <input
                v-model.number="formData.transportationCost"
                type="number"
                min="0"
                step="0.01"
                class="form-input"
                placeholder="0.00"
              />
            </div>
          </div>

          <div class="calculation-summary">
            <div class="calc-row">
              <span>Base Revenue:</span>
              <span>${{ formatCurrency(appointment?.cost || 0) }}</span>
            </div>
            <div v-if="formData.transportationCost > 0" class="calc-row deduction">
              <span>- Transportation Cost:</span>
              <span>${{ formatCurrency(formData.transportationCost) }}</span>
            </div>
            <div class="calc-row total">
              <span>Net Revenue:</span>
              <span>${{ formatCurrency(calculateNetRevenue()) }}</span>
            </div>
          </div>
        </div>

        <div v-if="error" class="error-message">{{ error }}</div>
      </div>

      <div class="modal-footer">
        <button @click="$emit('close')" class="btn-cancel">Cancel</button>
        <button 
          @click="handleSave" 
          class="btn-confirm"
          :disabled="!isValid || saving"
        >
          {{ saving ? 'Saving...' : 'Save Assignment' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import MultiWorkerSelector from './MultiWorkerSelector.vue'

const props = defineProps({
  show: {
    type: Boolean,
    required: true
  },
  appointment: {
    type: Object,
    default: null
  },
  workers: {
    type: Array,
    default: () => []
  },
  mode: {
    type: String,
    default: 'assign',
    validator: (value) => ['assign', 'edit'].includes(value)
  }
})

const emit = defineEmits(['close', 'save'])

// State
const formData = ref({
  workerIds: [],
  actualHours: 0,
  lateArrival: 0,
  earlyLeave: 0,
  transportationCost: 0
})

const selectedWorkers = ref([])
const saving = ref(false)
const error = ref('')

// Computed
const modalTitle = computed(() => {
  return props.mode === 'assign' ? 'Assign Workers' : 'Edit Assignment'
})

const isValid = computed(() => {
  if (props.mode === 'assign' && selectedWorkers.value.length === 0) return false
  if (formData.value.actualHours < 0) return false
  return true
})

const currentAssignments = computed(() => {
  if (!props.appointment) return []
  return props.workers.filter(w => 
    // This would need to be implemented based on your data structure
    // For now, return empty array
    false
  )
})

// Methods
const updateSelectedWorkers = (workerIds) => {
  selectedWorkers.value = workerIds
  formData.value.workerIds = workerIds
}

const calculateNetRevenue = () => {
  const baseRevenue = props.appointment?.cost || 0
  const transportationCost = formData.value.transportationCost || 0
  return Math.max(0, baseRevenue - transportationCost)
}

const handleSave = async () => {
  if (!isValid.value) return
  
  saving.value = true
  error.value = ''

  try {
    const assignmentData = {
      workerIds: selectedWorkers.value,
      actualHours: formData.value.actualHours,
      lateArrival: formData.value.lateArrival,
      earlyLeave: formData.value.earlyLeave,
      transportationCost: formData.value.transportationCost,
      netRevenue: calculateNetRevenue()
    }

    emit('save', assignmentData)
  } catch (err) {
    error.value = err.message || 'Failed to save assignment'
  } finally {
    saving.value = false
  }
}

const formatDate = (dateStr) => {
  if (!dateStr) return ''
  const date = new Date(dateStr + 'T12:00:00')
  return date.toLocaleDateString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric'
  })
}

const formatCurrency = (amount) => {
  return (amount || 0).toFixed(2)
}

// Initialize form data when modal opens
watch(() => props.show, (newVal) => {
  if (newVal && props.appointment) {
    // Reset form data
    formData.value = {
      workerIds: [],
      actualHours: 0,
      lateArrival: 0,
      earlyLeave: 0,
      transportationCost: 0
    }
    selectedWorkers.value = []
    error.value = ''
    saving.value = false
    
    // If editing, load existing assignment data
    if (props.mode === 'edit') {
      // Load existing assignment data
      // This would need to be implemented based on your data structure
      // For now, start with empty form
    }
  }
})
</script>

<style scoped>
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

.modal-content {
  background: white;
  border-radius: 1rem;
  max-width: 600px;
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

.modal-header h3 {
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

.summary-details {
  flex: 1;
}

.client-name {
  margin: 0 0 0.25rem 0;
  font-weight: 700;
  font-size: 1.125rem;
  color: #1e293b;
}

.appointment-time {
  margin: 0 0 0.25rem 0;
  font-size: 0.875rem;
  color: #667eea;
  font-weight: 600;
}

.service-info {
  margin: 0 0 0.25rem 0;
  font-size: 0.875rem;
  color: #667eea;
  font-weight: 600;
}

.address-info {
  margin: 0;
  font-size: 0.813rem;
  color: #64748b;
}

.section {
  margin-bottom: 1.5rem;
}

.section h4 {
  margin: 0 0 1rem 0;
  font-size: 1rem;
  font-weight: 700;
  color: #1e293b;
}

.form-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 1rem;
  margin-bottom: 1rem;
}

.form-group {
  display: flex;
  flex-direction: column;
}

.form-group label {
  margin-bottom: 0.5rem;
  font-weight: 600;
  color: #334155;
  font-size: 0.875rem;
}

.form-input {
  padding: 0.75rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.5rem;
  font-size: 1rem;
  transition: border-color 0.2s;
}

.form-input:focus {
  outline: none;
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
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

.error-message {
  color: #dc2626;
  padding: 0.75rem;
  background: #fee2e2;
  border-radius: 0.5rem;
  margin-bottom: 1rem;
  font-size: 0.875rem;
}

.modal-footer {
  display: flex;
  gap: 0.75rem;
  padding: 1.5rem;
  border-top: 1px solid #e2e8f0;
  background: #f8fafc;
}

.btn-cancel,
.btn-confirm {
  flex: 1;
  padding: 0.75rem;
  border: none;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-cancel {
  background: #f1f5f9;
  color: #475569;
  border: 1px solid #e2e8f0;
}

.btn-cancel:hover {
  background: #e2e8f0;
}

.btn-confirm {
  background: #667eea;
  color: white;
}

.btn-confirm:hover:not(:disabled) {
  background: #5568d3;
}

.btn-confirm:disabled {
  background: #cbd5e1;
  cursor: not-allowed;
}
</style>
