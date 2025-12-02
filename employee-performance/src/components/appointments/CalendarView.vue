<template>
  <div class="calendar-view">
    <div class="calendar-header">
      <button @click="$emit('previous')" class="nav-btn">←</button>
      <h3>{{ weekRange }}</h3>
      <button @click="$emit('next')" class="nav-btn">→</button>
    </div>
    
    <div class="calendar-grid">
      <div v-for="day in weekDays" :key="day.date" class="calendar-day">
        <div class="day-header">
          <span class="day-name">{{ day.name }}</span>
          <span class="day-number">{{ day.number }}</span>
        </div>
        
        <div class="day-appointments">
          <MiniAppointment
            v-for="apt in day.appointments.slice(0, 3)"
            :key="apt.id"
            :appointment="apt"
            @click="$emit('view', apt)"
          />
          
          <div v-if="day.appointments.length > 3" class="more">
            +{{ day.appointments.length - 3 }} more
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import MiniAppointment from './MiniAppointment.vue'

const props = defineProps({
  appointments: { type: Array, required: true },
  currentWeek: { type: Date, required: true }
})

defineEmits(['previous', 'next', 'view'])

const weekDays = computed(() => {
  const days = []
  const startDate = new Date(props.currentWeek)
  
  for (let i = 0; i < 7; i++) {
    const date = new Date(startDate)
    date.setDate(startDate.getDate() + i)
    const dateStr = date.toISOString().split('T')[0]
    
    days.push({
      date: dateStr,
      name: date.toLocaleDateString('en-US', { weekday: 'short' }),
      number: date.getDate(),
      appointments: props.appointments.filter(apt => apt.appointment_date === dateStr)
    })
  }
  
  return days
})

const weekRange = computed(() => {
  const start = new Date(props.currentWeek)
  const end = new Date(start)
  end.setDate(start.getDate() + 6)
  
  return `${start.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })} - ${end.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}`
})
</script>

<style scoped>
.calendar-view {
  background: white;
  border-radius: 8px;
  overflow: hidden;
}

.calendar-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem;
  background: #f8fafc;
  border-bottom: 1px solid #e2e8f0;
}

.calendar-header h3 {
  margin: 0;
  font-size: 1.1rem;
  color: #1e293b;
}

.nav-btn {
  padding: 0.5rem 1rem;
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  cursor: pointer;
}

.nav-btn:hover {
  background: #f1f5f9;
}

.calendar-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  min-height: 400px;
}

.calendar-day {
  border-right: 1px solid #e2e8f0;
  border-bottom: 1px solid #e2e8f0;
  padding: 0.75rem;
  min-height: 120px;
}

.calendar-day:nth-child(7n) {
  border-right: none;
}

.day-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.5rem;
}

.day-name {
  font-size: 0.75rem;
  color: #64748b;
  font-weight: 600;
}

.day-number {
  font-size: 0.875rem;
  color: #1e293b;
  font-weight: 600;
}

.day-appointments {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.more {
  text-align: center;
  padding: 0.25rem;
  color: #64748b;
  font-size: 0.75rem;
  font-style: italic;
}

@media (max-width: 768px) {
  .calendar-grid {
    grid-template-columns: 1fr;
  }
  
  .calendar-day {
    min-height: auto;
  }
}
</style>
