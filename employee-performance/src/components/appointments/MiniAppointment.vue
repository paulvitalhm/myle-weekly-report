<template>
  <div 
    class="mini-appointment" 
    :class="{ assigned: hasWorkers }"
    @click="$emit('click')"
  >
    <span class="time">{{ appointment.appointment_time }}</span>
    <span class="client">{{ truncate(appointment.customer_name, 12) }}</span>
  </div>
</template>

<script setup>
const props = defineProps({
  appointment: { type: Object, required: true }
})

defineEmits(['click'])

const hasWorkers = computed(() => 
  props.appointment.assignedWorkers && 
  props.appointment.assignedWorkers.length > 0
)

const truncate = (text, maxLength) => {
  if (!text) return ''
  if (text.length <= maxLength) return text
  return text.substring(0, maxLength - 2) + '..'
}
</script>

<style scoped>
.mini-appointment {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.375rem 0.5rem;
  background: #f1f5f9;
  border: 1px solid #e2e8f0;
  border-radius: 4px;
  cursor: pointer;
  transition: all 0.2s;
  font-size: 0.75rem;
}

.mini-appointment:hover {
  background: #e2e8f0;
}

.mini-appointment.assigned {
  background: #d1fae5;
  border-color: #10b981;
}

.time {
  font-weight: 600;
  color: #667eea;
}

.client {
  color: #374151;
  font-size: 0.688rem;
}
</style>
