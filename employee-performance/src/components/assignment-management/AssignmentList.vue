<template>
  <div class="assignment-list">
    <!-- Search and Filter Controls -->
    <div class="list-header">
      <div class="search-section">
        <input 
          v-model="searchQuery" 
          type="text" 
          placeholder="Search appointments, clients, addresses..."
          class="search-input"
        />
        <select v-model="statusFilter" class="filter-select">
          <option value="all">All Appointments</option>
          <option value="unassigned">Unassigned Only</option>
          <option value="assigned">Assigned Only</option>
          <option value="partial">Partially Assigned</option>
        </select>
      </div>
      
      <div class="action-section">
        <button @click="$emit('bulk-assign')" class="btn-bulk" :disabled="selectedAppointments.length === 0">
          Bulk Assign ({{ selectedAppointments.length }})
        </button>
        <button @click="$emit('refresh')" class="btn-refresh">
          🔄 Refresh
        </button>
      </div>
    </div>

    <!-- Stats Summary -->
    <div class="stats-bar">
      <div class="stat-item">
        <span class="stat-label">Total:</span>
        <span class="stat-value">{{ totalAppointments }}</span>
      </div>
      <div class="stat-item">
        <span class="stat-label">Unassigned:</span>
        <span class="stat-value unassigned">{{ unassignedCount }}</span>
      </div>
      <div class="stat-item">
        <span class="stat-label">Assigned:</span>
        <span class="stat-value assigned">{{ assignedCount }}</span>
      </div>
      <div class="stat-item">
        <span class="stat-label">Partial:</span>
        <span class="stat-value partial">{{ partialCount }}</span>
      </div>
    </div>

    <!-- Appointments Grid -->
    <div v-if="filteredAppointments.length === 0" class="empty-state">
      <h3>No appointments found</h3>
      <p>{{ searchQuery ? 'No appointments match your search criteria.' : 'No appointments available for this period.' }}</p>
    </div>

    <div v-else class="appointments-grid">
      <AssignmentCard
        v-for="appointment in filteredAppointments"
        :key="appointment.id"
        :appointment="appointment"
        :is-selected="isSelected(appointment.id)"
        :workers="getAppointmentWorkers(appointment.id)"
        @toggle-selection="toggleSelection"
        @assign="showAssignModal"
        @edit="showEditModal"
      />
    </div>

    <!-- Bulk Selection Info -->
    <div v-if="selectedAppointments.length > 0" class="selection-info">
      <p>{{ selectedAppointments.length }} appointments selected</p>
      <button @click="clearSelection" class="btn-clear">Clear Selection</button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import AssignmentCard from './AssignmentCard.vue'

const props = defineProps({
  appointments: {
    type: Array,
    required: true
  },
  assignments: {
    type: Array,
    required: true
  },
  workers: {
    type: Array,
    required: true
  }
})

const emit = defineEmits(['bulk-assign', 'refresh', 'assign', 'edit'])

// State
const searchQuery = ref('')
const statusFilter = ref('all')
const selectedAppointments = ref([])

// Computed
const filteredAppointments = computed(() => {
  let filtered = props.appointments

  // Apply search filter
  if (searchQuery.value) {
    const query = searchQuery.value.toLowerCase()
    filtered = filtered.filter(apt =>
      apt.customer_name.toLowerCase().includes(query) ||
      apt.service.toLowerCase().includes(query) ||
      apt.address.toLowerCase().includes(query) ||
      apt.city.toLowerCase().includes(query)
    )
  }

  // Apply status filter
  if (statusFilter.value !== 'all') {
    filtered = filtered.filter(apt => {
      const assignmentStatus = getAssignmentStatus(apt.id)
      return assignmentStatus === statusFilter.value
    })
  }

  return filtered
})

const totalAppointments = computed(() => props.appointments.length)
const unassignedCount = computed(() => props.appointments.filter(apt => getAssignmentStatus(apt.id) === 'unassigned').length)
const assignedCount = computed(() => props.appointments.filter(apt => getAssignmentStatus(apt.id) === 'assigned').length)
const partialCount = computed(() => props.appointments.filter(apt => getAssignmentStatus(apt.id) === 'partial').length)

// Methods
const getAssignmentStatus = (appointmentId) => {
  const assignmentCount = props.assignments.filter(a => a.appointment_id === appointmentId).length
  
  if (assignmentCount === 0) return 'unassigned'
  if (assignmentCount >= 2) return 'assigned' // Multiple workers = fully assigned
  return 'partial' // Single worker = partial assignment
}

const getAppointmentWorkers = (appointmentId) => {
  return props.assignments
    .filter(a => a.appointment_id === appointmentId)
    .map(a => {
      const worker = props.workers.find(w => w.id === a.worker_id)
      return worker ? worker.name : 'Unknown Worker'
    })
}

const isSelected = (appointmentId) => {
  return selectedAppointments.value.includes(appointmentId)
}

const toggleSelection = (appointmentId) => {
  const index = selectedAppointments.value.indexOf(appointmentId)
  if (index > -1) {
    selectedAppointments.value.splice(index, 1)
  } else {
    selectedAppointments.value.push(appointmentId)
  }
}

const showAssignModal = (appointment) => {
  emit('assign', appointment)
}

const showEditModal = (appointment) => {
  emit('edit', appointment)
}

const clearSelection = () => {
  selectedAppointments.value = []
}

// Watch for changes in appointments to update selection
watch(() => props.appointments, () => {
  // Remove selections for appointments that no longer exist
  const validIds = props.appointments.map(a => a.id)
  selectedAppointments.value = selectedAppointments.value.filter(id => validIds.includes(id))
}, { deep: true })
</script>

<style scoped>
.assignment-list {
  padding: 1rem;
}

.list-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.5rem;
  gap: 1rem;
  flex-wrap: wrap;
}

.search-section {
  display: flex;
  gap: 0.75rem;
  flex: 1;
  min-width: 300px;
}

.search-input {
  flex: 1;
  padding: 0.75rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.5rem;
  font-size: 0.875rem;
}

.filter-select {
  padding: 0.75rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  background: white;
  min-width: 150px;
}

.action-section {
  display: flex;
  gap: 0.75rem;
}

.btn-bulk,
.btn-refresh {
  padding: 0.75rem 1rem;
  border: none;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-bulk {
  background: #667eea;
  color: white;
}

.btn-bulk:hover:not(:disabled) {
  background: #5568d3;
}

.btn-bulk:disabled {
  background: #cbd5e1;
  cursor: not-allowed;
}

.btn-refresh {
  background: #f1f5f9;
  color: #475569;
  border: 1px solid #e2e8f0;
}

.btn-refresh:hover {
  background: #e2e8f0;
}

.stats-bar {
  display: flex;
  gap: 2rem;
  margin-bottom: 1.5rem;
  padding: 1rem;
  background: #f8fafc;
  border-radius: 0.75rem;
  border: 1px solid #e2e8f0;
}

.stat-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.25rem;
}

.stat-label {
  font-size: 0.75rem;
  color: #64748b;
  font-weight: 500;
}

.stat-value {
  font-size: 1.25rem;
  font-weight: 700;
  color: #1e293b;
}

.stat-value.unassigned {
  color: #dc2626;
}

.stat-value.assigned {
  color: #10b981;
}

.stat-value.partial {
  color: #f59e0b;
}

.empty-state {
  text-align: center;
  padding: 3rem;
  background: white;
  border-radius: 0.75rem;
  margin: 1rem 0;
}

.empty-state h3 {
  margin: 0 0 0.5rem 0;
  color: #1e293b;
}

.empty-state p {
  margin: 0;
  color: #64748b;
}

.appointments-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
  gap: 1rem;
  margin-bottom: 1rem;
}

.selection-info {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem;
  background: #eef2ff;
  border: 1px solid #667eea;
  border-radius: 0.5rem;
  margin-top: 1rem;
}

.selection-info p {
  margin: 0;
  font-weight: 600;
  color: #667eea;
}

.btn-clear {
  padding: 0.5rem 1rem;
  background: white;
  color: #667eea;
  border: 1px solid #667eea;
  border-radius: 0.375rem;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-clear:hover {
  background: #667eea;
  color: white;
}

@media (max-width: 768px) {
  .list-header {
    flex-direction: column;
    align-items: stretch;
  }
  
  .search-section {
    flex-direction: column;
  }
  
  .stats-bar {
    flex-wrap: wrap;
    gap: 1rem;
  }
  
  .appointments-grid {
    grid-template-columns: 1fr;
  }
}
</style>
