<template>
  <div class="multi-worker-selector">
    <div class="selector-header">
      <h3>Select Workers</h3>
      <div class="selected-count">
        {{ selectedWorkers.length }} worker{{ selectedWorkers.length !== 1 ? 's' : '' }} selected
      </div>
    </div>

    <div class="worker-grid">
      <div 
        v-for="worker in availableWorkers" 
        :key="worker.id"
        class="worker-card"
        :class="{ 
          selected: isSelected(worker.id),
          disabled: isDisabled(worker.id)
        }"
        @click="toggleWorker(worker)"
      >
        <div class="worker-checkbox">
          <input 
            type="checkbox" 
            :checked="isSelected(worker.id)"
            @change="toggleWorker(worker)"
            :disabled="isDisabled(worker.id)"
          />
        </div>
        
        <div class="worker-info">
          <h4 class="worker-name">{{ worker.name }}</h4>
          <p class="worker-details">
            {{ worker.role || 'Worker' }} · {{ worker.experience || 'Experienced' }}
          </p>
          <div class="worker-stats">
            <span class="stat-item">
              <span class="stat-label">Assigned:</span>
              <span class="stat-value">{{ getWorkerAssignmentCount(worker.id) }}</span>
            </span>
            <span class="stat-item">
              <span class="stat-label">Capacity:</span>
              <span class="stat-value">{{ worker.maxAssignments || 'Unlimited' }}</span>
            </span>
          </div>
        </div>

        <div class="worker-status">
          <span 
            v-if="isDisabled(worker.id)" 
            class="status-badge disabled"
          >
            At Capacity
          </span>
          <span 
            v-else-if="isSelected(worker.id)" 
            class="status-badge selected"
          >
            Selected
          </span>
        </div>
      </div>
    </div>

    <div class="selector-actions">
      <button @click="$emit('cancel')" class="btn-cancel">
        Cancel
      </button>
      <button 
        @click="confirmSelection" 
        class="btn-confirm"
        :disabled="selectedWorkers.length === 0"
      >
        Confirm Selection
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'

const props = defineProps({
  workers: {
    type: Array,
    required: true
  },
  currentAssignments: {
    type: Array,
    default: () => []
  },
  maxWorkers: {
    type: Number,
    default: 5
  }
})

const emit = defineEmits(['update:selected', 'cancel', 'confirm'])

const selectedWorkers = ref([])

// Computed
const availableWorkers = computed(() => {
  return props.workers.map(worker => ({
    ...worker,
    currentAssignments: getWorkerAssignmentCount(worker.id),
    isAtCapacity: isAtCapacity(worker.id)
  }))
})

// Methods
const isSelected = (workerId) => {
  return selectedWorkers.value.includes(workerId)
}

const isDisabled = (workerId) => {
  const worker = props.workers.find(w => w.id === workerId)
  if (!worker) return true
  
  // Check if worker is at capacity
  if (worker.maxAssignments && getWorkerAssignmentCount(workerId) >= worker.maxAssignments) {
    return true
  }
  
  return false
}

const isAtCapacity = (workerId) => {
  const worker = props.workers.find(w => w.id === workerId)
  if (!worker || !worker.maxAssignments) return false
  
  return getWorkerAssignmentCount(workerId) >= worker.maxAssignments
}

const getWorkerAssignmentCount = (workerId) => {
  return props.currentAssignments.filter(a => a.worker_id === workerId).length
}

const toggleWorker = (worker) => {
  if (isDisabled(worker.id)) return
  
  const index = selectedWorkers.value.indexOf(worker.id)
  
  if (index > -1) {
    // Remove worker
    selectedWorkers.value.splice(index, 1)
  } else {
    // Add worker (respect maxWorkers limit)
    if (selectedWorkers.value.length < props.maxWorkers) {
      selectedWorkers.value.push(worker.id)
    }
  }
}

const confirmSelection = () => {
  emit('confirm', selectedWorkers.value)
}

// Initialize with any pre-selected workers if provided
const initializeSelection = () => {
  // This could be used to pre-select workers based on existing assignments
  // For now, start with empty selection
  selectedWorkers.value = []
}

// Call initialization when component mounts
initializeSelection()
</script>

<style scoped>
.multi-worker-selector {
  background: white;
  border-radius: 0.75rem;
  padding: 1.5rem;
  max-height: 70vh;
  overflow-y: auto;
}

.selector-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.5rem;
}

.selector-header h3 {
  margin: 0;
  font-size: 1.25rem;
  color: #1e293b;
}

.selected-count {
  font-size: 0.875rem;
  color: #64748b;
  font-weight: 500;
}

.worker-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1rem;
  margin-bottom: 1.5rem;
  max-height: 50vh;
  overflow-y: auto;
}

.worker-card {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1rem;
  border: 2px solid #e2e8f0;
  border-radius: 0.5rem;
  cursor: pointer;
  transition: all 0.2s ease;
  background: white;
}

.worker-card:hover:not(.disabled) {
  border-color: #667eea;
  transform: translateY(-1px);
}

.worker-card.selected {
  border-color: #667eea;
  background: #f8fafcff;
}

.worker-card.disabled {
  opacity: 0.5;
  cursor: not-allowed;
  background: #f8fafc;
}

.worker-checkbox {
  flex-shrink: 0;
}

.worker-checkbox input {
  width: 1.25rem;
  height: 1.25rem;
  cursor: pointer;
  accent-color: #667eea;
}

.worker-checkbox input:disabled {
  cursor: not-allowed;
}

.worker-info {
  flex: 1;
  min-width: 0;
}

.worker-name {
  margin: 0 0 0.25rem 0;
  font-size: 1rem;
  font-weight: 600;
  color: #1e293b;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.worker-details {
  margin: 0 0 0.5rem 0;
  font-size: 0.813rem;
  color: #64748b;
}

.worker-stats {
  display: flex;
  gap: 1rem;
  font-size: 0.75rem;
}

.stat-item {
  display: flex;
  gap: 0.25rem;
}

.stat-label {
  color: #64748b;
  font-weight: 500;
}

.stat-value {
  color: #374151;
  font-weight: 600;
}

.worker-status {
  flex-shrink: 0;
}

.status-badge {
  display: inline-block;
  padding: 0.25rem 0.5rem;
  border-radius: 0.375rem;
  font-size: 0.688rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.status-badge.disabled {
  background: #fee2e2;
  color: #dc2626;
  border: 1px solid #fecaca;
}

.status-badge.selected {
  background: #d1fae5;
  color: #059669;
  border: 1px solid #a7f3d0;
}

.selector-actions {
  display: flex;
  gap: 0.75rem;
  padding-top: 1rem;
  border-top: 1px solid #e2e8f0;
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

@media (max-width: 768px) {
  .worker-grid {
    grid-template-columns: 1fr;
  }
  
  .selector-actions {
    flex-direction: column;
  }
}
</style>
