<template>
  <div class="appointment-card" :class="{ assigned: hasWorkers }">
    <div class="time">
      <span class="time-badge">{{ appointment.appointment_time }}</span>
    </div>
    
    <div class="details">
      <h5 class="client">{{ appointment.customer_name }}</h5>
      <p class="service">{{ appointment.service }} · ${{ appointment.cost }}</p>
      <p class="address">{{ appointment.address }}, {{ appointment.city }}</p>
      
      <div v-if="hasWorkers" class="assignment-info">
        <span class="assigned-badge">
          ✓ Assigned ({{ appointment.assignedWorkers.join(', ') }})
        </span>
      </div>
    </div>
    
    <div class="actions">
      <button @click="$emit('view', appointment)" class="btn-view">View</button>
      <button 
        v-if="!hasWorkers" 
        @click="$emit('assign', appointment)" 
        class="btn-assign"
      >
        Assign
      </button>
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  appointment: { type: Object, required: true }
})

defineEmits(['view', 'assign'])

const hasWorkers = computed(() => 
  props.appointment.assignedWorkers && 
  props.appointment.assignedWorkers.length > 0
)
</script>

<style scoped>
.appointment-card {
  display: flex;
  gap: 1rem;
  padding: 1rem;
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  transition: all 0.2s ease;
}

.appointment-card:hover {
  border-color: #cbd5e1;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

.appointment-card.assigned {
  border-color: #10b981;
  background: #f0fdf4;
}

.time {
  flex-shrink: 0;
}

.time-badge {
  display: inline-block;
  padding: 0.375rem 0.75rem;
  background: #667eea;
  color: white;
  border-radius: 6px;
  font-size: 0.875rem;
  font-weight: 600;
}

.details {
  flex: 1;
  min-width: 0;
}

.client {
  margin: 0 0 0.25rem 0;
  font-size: 1rem;
  font-weight: 600;
  color: #1e293b;
}

.service {
  margin: 0 0 0.25rem 0;
  font-size: 0.875rem;
  color: #667eea;
  font-weight: 500;
}

.address {
  margin: 0 0 0.5rem 0;
  font-size: 0.813rem;
  color: #64748b;
}

.assignment-info {
  margin-top: 0.5rem;
}

.assigned-badge {
  display: inline-block;
  padding: 0.25rem 0.5rem;
  background: #10b981;
  color: white;
  border-radius: 4px;
  font-size: 0.75rem;
  font-weight: 600;
}

.actions {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.btn-view, .btn-assign {
  padding: 0.5rem 1rem;
  border: none;
  border-radius: 6px;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  white-space: nowrap;
}

.btn-view {
  background: #f1f5f9;
  color: #475569;
}

.btn-view:hover {
  background: #e2e8f0;
}

.btn-assign {
  background: #667eea;
  color: white;
}

.btn-assign:hover {
  background: #5568d3;
}
</style>
