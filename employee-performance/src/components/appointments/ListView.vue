<template>
  <div class="list-view">
    <div v-if="appointments.length === 0" class="empty">
      <h3>No appointments found</h3>
      <p>No appointments match your search criteria.</p>
    </div>
    
    <div v-else class="day-groups">
      <div v-for="day in groupedDays" :key="day.date" class="day-group">
        <div class="day-header">
          <h4>{{ formatDate(day.date) }}</h4>
          <span>{{ day.appointments.length }} appointments</span>
        </div>
        
        <div class="appointments">
          <AppointmentCard 
            v-for="apt in day.appointments" 
            :key="apt.id"
            :appointment="apt"
            @view="$emit('view', apt)"
            @assign="$emit('assign', apt)"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import AppointmentCard from './AppointmentCard.vue'

const props = defineProps({
  appointments: { type: Array, required: true }
})

defineEmits(['view', 'assign'])

const groupedDays = computed(() => {
  const groups = {}
  
  props.appointments.forEach(apt => {
    if (!groups[apt.appointment_date]) {
      groups[apt.appointment_date] = []
    }
    groups[apt.appointment_date].push(apt)
  })
  
  return Object.entries(groups)
    .sort(([a], [b]) => new Date(a) - new Date(b))
    .map(([date, appointments]) => ({
      date,
      appointments: appointments.sort((a, b) => a.appointment_time.localeCompare(b.appointment_time))
    }))
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
.list-view {
  padding: 1rem;
}

.empty {
  text-align: center;
  padding: 3rem;
  background: white;
  border-radius: 8px;
}

.day-groups {
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

.day-group {
  background: white;
  border-radius: 8px;
  overflow: hidden;
}

.day-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem;
  background: #f8fafc;
  border-bottom: 1px solid #e2e8f0;
}

.day-header h4 {
  margin: 0;
  font-size: 1.1rem;
  color: #1e293b;
}

.day-header span {
  color: #64748b;
  font-size: 0.9rem;
}

.appointments {
  padding: 1rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}
</style>
