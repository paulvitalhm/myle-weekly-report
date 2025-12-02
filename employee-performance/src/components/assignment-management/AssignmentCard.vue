<template>
  <div 
    class="assignment-card" 
    :class="{ 
      selected: isSelected,
      'status-unassigned': assignmentStatus === 'unassigned',
      'status-assigned': assignmentStatus === 'assigned',
      'status-partial': assignmentStatus === 'partial'
    }"
  >
    <!-- Selection Checkbox -->
    <div class="card-header">
      <input 
        type="checkbox" 
        :checked="isSelected"
        @change="$emit('toggle-selection', appointment.id)"
        class="selection-checkbox"
      />
      <AssignmentStatusBadge :status="assignmentStatus" />
    </div>

    <!-- Appointment Details -->
    <div class="appointment-details">
      <h3 class="client-name">{{ appointment.customer_name }}</h3>
      <p class="appointment-time">
        {{ formatDate(appointment.appointment_date) }} at {{ appointment.appointment_time }}
      </p>
      <p class="service-info">
        {{ appointment.service }} · ${{ appointment.cost }}
      </p>
      <p class="address-info">
        {{ appointment.address }}, {{ appointment.city }}
      </p>
    </div>

    <!-- Assignment Info -->
    <div v-if="workers.length > 0" class="assignment-info">
      <h4 class="workers-title">Assigned Workers ({{ workers.length }})</h4>
      <div class="workers-list">
        <span 
          v-for="(worker, index) in workers" 
          :key="index"
          class="worker-tag"
        >
          {{ worker }}
        </span>
      </div>
    </div>

    <!-- Action Buttons -->
    <div class="card-actions">
      <button 
        v-if="assignmentStatus === 'unassigned'"
        @click="$emit('assign', appointment)"
        class="btn-assign"
      >
        Assign Workers
      </button>
      <button 
        v-else
        @click="$emit('edit', appointment)"
        class="btn-edit"
      >
        Edit Assignment
      </button>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import AssignmentStatusBadge from './AssignmentStatusBadge.vue'

const props = defineProps({
  appointment: {
    type: Object,
    required: true
  },
  isSelected: {
    type: Boolean,
    default: false
  },
  workers: {
    type: Array,
    default: () => []
  }
})

defineEmits(['toggle-selection', 'assign', 'edit'])

const assignmentStatus = computed(() => {
  if (props.workers.length === 0) return 'unassigned'
  if (props.workers.length >= 2) return 'assigned'
  return 'partial'
})

const formatDate = (dateStr) => {
  const date = new Date(dateStr + 'T12:00:00')
  return date.toLocaleDateString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric'
  })
}
</script>

<style scoped>
.assignment-card {
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 0.75rem;
  padding: 1.25rem;
  transition: all 0.2s ease;
  cursor: pointer;
  position: relative;
}

.assignment-card:hover {
  border-color: #cbd5e1;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
  transform: translateY(-2px);
}

.assignment-card.selected {
  border-color: #667eea;
  background: #f8fafcff;
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.15);
}

.assignment-card.status-unassigned {
  border-left: 4px solid #dc2626;
}

.assignment-card.status-assigned {
  border-left: 4px solid #10b981;
}

.assignment-card.status-partial {
  border-left: 4px solid #f59e0b;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.selection-checkbox {
  width: 1.25rem;
  height: 1.25rem;
  cursor: pointer;
  accent-color: #667eea;
}

.appointment-details {
  margin-bottom: 1rem;
}

.client-name {
  margin: 0 0 0.5rem 0;
  font-size: 1.125rem;
  font-weight: 700;
  color: #1e293b;
}

.appointment-time {
  margin: 0 0 0.25rem 0;
  font-size: 0.875rem;
  color: #64748b;
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

.assignment-info {
  margin-bottom: 1rem;
  padding: 0.75rem;
  background: #f8fafc;
  border-radius: 0.5rem;
  border: 1px solid #e2e8f0;
}

.workers-title {
  margin: 0 0 0.5rem 0;
  font-size: 0.875rem;
  font-weight: 600;
  color: #374151;
}

.workers-list {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.worker-tag {
  display: inline-block;
  padding: 0.375rem 0.75rem;
  background: #667eea;
  color: white;
  border-radius: 0.375rem;
  font-size: 0.75rem;
  font-weight: 500;
}

.card-actions {
  display: flex;
  gap: 0.75rem;
}

.btn-assign,
.btn-edit {
  flex: 1;
  padding: 0.75rem;
  border: none;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-assign {
  background: #667eea;
  color: white;
}

.btn-assign:hover {
  background: #5568d3;
}

.btn-edit {
  background: #f1f5f9;
  color: #475569;
  border: 1px solid #e2e8f0;
}

.btn-edit:hover {
  background: #e2e8f0;
}

@media (max-width: 768px) {
  .assignment-card {
    padding: 1rem;
  }
  
  .card-actions {
    flex-direction: column;
  }
}
</style>
