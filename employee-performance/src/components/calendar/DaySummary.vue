<template>
  <div class="day-summary-card">
    <div class="summary-header">
      <h3 class="summary-title">Day Summary</h3>
      <div class="summary-stats">
        <span class="stat-item">
          <span class="stat-label">Jobs:</span>
          <span class="stat-value">{{ jobs.length }}</span>
        </span>
        <span class="stat-item">
          <span class="stat-label">Revenue:</span>
          <span class="stat-value">${{ formatCurrency(totalRevenue) }}</span>
        </span>
        <span class="stat-item">
          <span class="stat-label">Hours:</span>
          <span class="stat-value">{{ formatHours(totalHours) }}</span>
        </span>
      </div>
    </div>

    <div class="worker-table">
      <div class="table-header">
        <div class="worker-col">Worker</div>
        <div class="hours-col">Hours</div>
        <div class="index-col">Performance</div>
      </div>
      
      <div class="table-body">
        <div 
          v-for="worker in workerStats" 
          :key="worker.id"
          class="worker-row"
        >
          <div class="worker-cell">
            <span class="worker-name">{{ worker.name }}</span>
          </div>
          <div class="hours-cell">
            <span class="hours-value">{{ formatHours(worker.hours) }}</span>
          </div>
          <div class="index-cell">
            <span 
              class="index-badge"
              :class="getTierClass(worker.index)"
            >
              {{ formatIndex(worker.index) }}
            </span>
          </div>
        </div>
      </div>
    </div>

    <div class="summary-footer">
      <div class="total-row">
        <span class="total-label">TOTAL</span>
        <span class="total-hours">{{ formatHours(totalHours) }}</span>
        <span class="total-revenue">${{ formatCurrency(totalRevenue) }}</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  day: {
    type: Object,
    required: true
  },
  workers: {
    type: Array,
    required: true
  },
  jobs: {
    type: Array,
    required: true
  }
})

// Computed
const workerStats = computed(() => {
  return props.workers.map(workerName => {
    const workerJobs = props.jobs.filter(job => {
      // This would need to be implemented based on your assignment logic
      // For now, return basic stats
      return true // Placeholder
    })
    
    return {
      id: workerName,
      name: workerName,
      hours: calculateWorkerHours(workerName),
      index: calculateWorkerIndex(workerName),
      revenue: calculateWorkerRevenue(workerName)
    }
  })
})

const totalRevenue = computed(() => {
  return props.jobs.reduce((sum, job) => sum + (job.cost || 0), 0)
})

const totalHours = computed(() => {
  return props.workers.reduce((sum, workerName) => sum + calculateWorkerHours(workerName), 0)
})

// Methods
const calculateWorkerHours = (workerName) => {
  // This would need to be implemented based on your assignment data
  // For now, return placeholder value
  return Math.random() * 8 + 2 // Random between 2-10 hours
}

const calculateWorkerIndex = (workerName) => {
  // This would need to be implemented based on your performance calculation
  // For now, return placeholder value
  return Math.random() * 30 + 35 // Random between 35-65
}

const calculateWorkerRevenue = (workerName) => {
  // This would need to be implemented based on your assignment data
  // For now, return placeholder value
  return Math.random() * 200 + 100 // Random between 100-300
}

const getTierClass = (index) => {
  if (index >= 47) return 'tier-top'
  if (index >= 35) return 'tier-good'
  return 'tier-low'
}

const formatCurrency = (amount) => {
  return (amount || 0).toFixed(2)
}

const formatHours = (hours) => {
  if (!hours) return '0h 0m'
  const h = Math.floor(hours)
  const m = Math.round((hours - h) * 60)
  return m > 0 ? `${h}h ${m}m` : `${h}h`
}

const formatIndex = (index) => {
  return index.toFixed(2)
}
</script>

<style scoped>
.day-summary-card {
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 0.75rem;
  padding: 1rem;
  margin-bottom: 1rem;
}

.summary-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  padding-bottom: 0.75rem;
  border-bottom: 1px solid #f1f5f9;
}

.summary-title {
  margin: 0;
  font-size: 1rem;
  font-weight: 700;
  color: #1e293b;
}

.summary-stats {
  display: flex;
  gap: 1rem;
}

.stat-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.125rem;
}

.stat-label {
  font-size: 0.688rem;
  color: #64748b;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.stat-value {
  font-size: 0.875rem;
  font-weight: 700;
  color: #1e293b;
}

.worker-table {
  margin-bottom: 1rem;
}

.table-header {
  display: grid;
  grid-template-columns: 1fr 80px 100px;
  gap: 0.5rem;
  padding: 0.5rem 0.75rem;
  background: #f8fafc;
  border-radius: 0.375rem;
  margin-bottom: 0.5rem;
}

.table-header > div {
  font-size: 0.75rem;
  font-weight: 600;
  color: #475569;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.worker-col {
  text-align: left;
}

.hours-col {
  text-align: center;
}

.index-col {
  text-align: center;
}

.table-body {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.worker-row {
  display: grid;
  grid-template-columns: 1fr 80px 100px;
  gap: 0.5rem;
  padding: 0.5rem 0.75rem;
  border-radius: 0.375rem;
  transition: background-color 0.2s;
}

.worker-row:hover {
  background-color: #f8fafc;
}

.worker-cell,
.hours-cell,
.index-cell {
  display: flex;
  align-items: center;
}

.worker-name {
  font-size: 0.875rem;
  font-weight: 500;
  color: #1e293b;
}

.hours-value {
  font-size: 0.813rem;
  color: #64748b;
  font-weight: 500;
}

.index-badge {
  display: inline-block;
  padding: 0.25rem 0.5rem;
  border-radius: 0.375rem;
  font-size: 0.75rem;
  font-weight: 600;
  text-align: center;
  min-width: 60px;
}

.index-badge.tier-top {
  background: #dbeafe;
  color: #1e40af;
  border: 1px solid #93c5fd;
}

.index-badge.tier-good {
  background: #fef3c7;
  color: #d97706;
  border: 1px solid #fde68a;
}

.index-badge.tier-low {
  background: #fee2e2;
  color: #dc2626;
  border: 1px solid #fecaca;
}

.summary-footer {
  padding-top: 0.75rem;
  border-top: 1px solid #f1f5f9;
}

.total-row {
  display: grid;
  grid-template-columns: 1fr 80px 100px;
  gap: 0.5rem;
  padding: 0.5rem 0.75rem;
  background: #f1f5f9;
  border-radius: 0.375rem;
  font-weight: 600;
}

.total-label {
  font-size: 0.813rem;
  color: #475569;
}

.total-hours,
.total-revenue {
  font-size: 0.813rem;
  color: #1e293b;
  text-align: center;
}
</style>
