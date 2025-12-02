<template>
  <nav class="bottom-nav">
    <router-link 
      :to="`/report/${periodId}`" 
      class="nav-item"
      :class="{ active: $route.name === 'PerformanceReport' }"
    >
      <span class="icon">📊</span>
      <span class="label">Report</span>
    </router-link>
    
    <router-link 
      :to="`/appointments/${periodId}`" 
      class="nav-item"
      :class="{ active: $route.name === 'AppointmentsByDay' }"
    >
      <span class="icon">📅</span>
      <span class="label">Calendar</span>
    </router-link>
    
    <router-link 
      :to="`/add-time/${periodId}`" 
      class="nav-item"
      :class="{ active: $route.name === 'AddTimeEntry' }"
    >
      <span class="icon">⏰</span>
      <span class="label">Add Time</span>
    </router-link>
    
    <router-link
      :to="`/assignments/${periodId}`"
      class="nav-item"
      :class="{ active: $route.name === 'TeamAssignments' }"
    >
      <span class="icon">👥</span>
      <span class="label">Assignments</span>
    </router-link>
    
    <router-link
      :to="`/daily-report/${periodId}`"
      class="nav-item"
      :class="{ active: $route.name === 'DailyPerformanceReport' }"
    >
      <span class="icon">📈</span>
      <span class="label">Daily Report</span>
    </router-link>
  </nav>
</template>

<script setup>
defineProps({
  periodId: {
    type: String,
    required: true
  }
})
</script>

<style scoped>
.bottom-nav {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background: white;
  border-top: 1px solid #e0e0e0;
  display: flex;
  justify-content: space-around;
  padding: 0.5rem 0;
  box-shadow: 0 -2px 10px rgba(0,0,0,0.1);
  z-index: 100;
}

.nav-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.25rem;
  padding: 0.5rem 1rem;
  color: #666;
  text-decoration: none;
  transition: all 0.2s;
  border-radius: 8px;
  min-width: 80px;
}

.nav-item:hover {
  background: #f5f5f5;
}

.nav-item.active {
  color: #667eea;
  background: #f0f4ff;
}

.nav-item .icon {
  font-size: 1.5rem;
}

.nav-item .label {
  font-size: 0.75rem;
  font-weight: 500;
}

@media (min-width: 768px) {
  .bottom-nav {
    position: static;
    border-top: none;
    border-bottom: 1px solid #e0e0e0;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    padding: 1rem 2rem;
  }
  
  .nav-item {
    flex-direction: row;
    gap: 0.5rem;
    padding: 0.75rem 1.5rem;
  }
  
  .nav-item .icon {
    font-size: 1.25rem;
  }
  
  .nav-item .label {
    font-size: 1rem;
  }
}
</style>
