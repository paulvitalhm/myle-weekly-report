<template>
  <div v-if="jobs.length > 0" class="unassigned-section">
    <h3 class="section-title">⚠️ Unassigned Jobs ({{ jobs.length }})</h3>
    <div class="unassigned-grid">
      <div 
        v-for="job in jobs" 
        :key="job.id"
        class="unassigned-card"
      >
        <div class="job-header">
          <span class="job-time">{{ job.appointment_time }}</span>
          <button @click="$emit('assign', job)" class="btn-assign-small">
            Assign
          </button>
        </div>
        <h5 class="job-client">{{ job.customer_name }}</h5>
        <p class="job-service">{{ job.service }} · ${{ job.cost }}</p>
        <p class="job-address">{{ job.address }}, {{ job.city }}</p>
      </div>
    </div>
  </div>
</template>

<script setup>
defineProps({
  jobs: {
    type: Array,
    required: true
  }
})

defineEmits(['assign'])
</script>

<style scoped>
.unassigned-section {
  margin-bottom: 2rem;
}

.unassigned-section .section-title {
  color: #d32f2f;
  margin-bottom: 1rem;
}

.unassigned-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1rem;
  margin-bottom: 2rem;
}

.unassigned-card {
  background: #fef2f2;
  border: 1px solid #fca5a5;
  border-radius: 8px;
  padding: 1rem;
}

.job-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.5rem;
}

.job-time {
  font-weight: 600;
  color: #667eea;
}

.btn-assign-small {
  padding: 0.25rem 0.75rem;
  background: #10b981;
  color: white;
  border: none;
  border-radius: 4px;
  font-size: 0.75rem;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-assign-small:hover {
  background: #059669;
}

.job-client {
  margin: 0.25rem 0;
  font-size: 0.9rem;
  font-weight: 600;
}

.job-service {
  margin: 0.25rem 0;
  font-size: 0.8rem;
  color: #667eea;
}

.job-address {
  margin: 0;
  font-size: 0.75rem;
  color: #64748b;
}
</style>
