<template>
  <div 
    class="job-card" 
    :class="[getTierClass(), { 'compact': compact }]"
    @click="$emit('click')"
  >
    <div class="job-header">
      <h4 class="client-name">{{ job.customer_name }}</h4>
      <span class="service-badge" :class="getServiceClass()">
        {{ job.service }}
      </span>
    </div>
    
    <p class="job-address">{{ job.address }}, {{ job.city }}</p>
    <p class="job-cost">${{ formatCurrency(job.cost) }}</p>
    
    <div class="worker-list">
      <div 
        v-for="(worker, index) in workers" 
        :key="index"
        class="worker-item"
      >
        <span class="worker-name">{{ worker }}</span>
        <span class="worker-status" :class="getWorkerStatusClass(worker)">
          {{ getWorkerStatusText(worker) }}
        </span>
      </div>
    </div>
    
    <div v-if="hasTransportationCosts" class="transportation-section">
      <div class="transportation-title">Transportation Costs:</div>
      <div 
        v-for="(worker, index) in workers" 
        :key="`transport-${index}`"
        class="transportation-item"
      >
        <span class="worker-name-small">{{ worker }}:</span>
        <span class="transport-cost">${{ getTransportationCost(worker) }}</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  job: {
    type: Object,
    required: true
  },
  workers: {
    type: Array,
    default: () => []
  },
  compact: {
    type: Boolean,
    default: false
  }
})

defineEmits(['click'])

// Computed
const hasTransportationCosts = computed(() => {
  // This would need to be implemented based on your assignment data
  // For now, return false
  return false
})

// Methods
const getTierClass = () => {
  // This would need to be implemented based on worker performance
  // For now, return random tier
  const tiers = ['tier-top', 'tier-good', 'tier-low']
  return tiers[Math.floor(Math.random() * tiers.length)]
}

const getServiceClass = () => {
  const service = props.job.service?.toLowerCase() || ''
  
  if (service.includes('airbnb')) return 'service-airbnb'
  if (service.includes('maintenance')) return 'service-maintenance'
  if (service.includes('one-time') || service.includes('first time') || service.includes('deep')) {
    return 'service-onetime'
  }
  if (service.includes('moving') || service.includes('pre-sale')) return 'service-moving'
  
  return 'service-default'
}

const getWorkerStatusClass = (worker) => {
  // This would need to be implemented based on assignment data
  // For now, return random status
  const statuses = ['on-time', 'late', 'early-leave']
  const status = statuses[Math.floor(Math.random() * statuses.length)]
  return `status-${status}`
}

const getWorkerStatusText = (worker) => {
  // This would need to be implemented based on assignment data
  // For now, return random status text
  const statuses = ['On time', '+15 min late', 'Early leave: -20 min']
  return statuses[Math.floor(Math.random() * statuses.length)]
}

const getTransportationCost = (worker) => {
  // This would need to be implemented based on assignment data
  // For now, return random cost
  return (Math.random() * 10 + 1).toFixed(2)
}

const formatCurrency = (amount) => {
  return (amount || 0).toFixed(2)
}
</script>

<style scoped>
.job-card {
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 0.5rem;
  padding: 0.75rem;
  margin-bottom: 0.5rem;
  cursor: pointer;
  transition: all 0.2s ease;
  position: relative;
  border-left: 4px solid transparent;
}

.job-card:hover {
  border-color: #cbd5e1;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  transform: translateY(-1px);
}

.job-card.compact {
  padding: 0.5rem;
  margin-bottom: 0.25rem;
}

.job-card.tier-top {
  border-left-color: #3b82f6;
}

.job-card.tier-good {
  border-left-color: #f59e0b;
}

.job-card.tier-low {
  border-left-color: #ef4444;
}

.job-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 0.5rem;
  gap: 0.5rem;
}

.client-name {
  margin: 0;
  font-size: 0.875rem;
  font-weight: 600;
  color: #1e293b;
  flex: 1;
}

.compact .client-name {
  font-size: 0.813rem;
}

.service-badge {
  flex-shrink: 0;
  padding: 0.25rem 0.5rem;
  border-radius: 0.375rem;
  font-size: 0.688rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  white-space: nowrap;
}

.service-badge.service-airbnb {
  background: #dbeafe;
  color: #1e40af;
  border: 1px solid #93c5fd;
}

.service-badge.service-maintenance {
  background: #fef3c7;
  color: #d97706;
  border: 1px solid #fde68a;
}

.service-badge.service-onetime {
  background: #fee2e2;
  color: #dc2626;
  border: 1px solid #fecaca;
}

.service-badge.service-moving {
  background: #fbbf24;
  color: #92400e;
  border: 1px solid #f59e0b;
}

.service-badge.service-default {
  background: #f3f4f6;
  color: #6b7280;
  border: 1px solid #d1d5db;
}

.job-address {
  margin: 0 0 0.25rem 0;
  font-size: 0.75rem;
  color: #64748b;
}

.compact .job-address {
  font-size: 0.688rem;
}

.job-cost {
  margin: 0 0 0.5rem 0;
  font-size: 0.813rem;
  color: #667eea;
  font-weight: 600;
}

.compact .job-cost {
  font-size: 0.75rem;
}

.worker-list {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  margin-bottom: 0.5rem;
}

.worker-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.25rem 0;
}

.worker-name {
  font-size: 0.75rem;
  color: #374151;
  font-weight: 500;
}

.compact .worker-name {
  font-size: 0.688rem;
}

.worker-status {
  font-size: 0.688rem;
  font-weight: 500;
  padding: 0.125rem 0.375rem;
  border-radius: 0.25rem;
  white-space: nowrap;
}

.worker-status.status-on-time {
  color: #059669;
  background: #d1fae5;
}

.worker-status.status-late {
  color: #dc2626;
  background: #fee2e2;
}

.worker-status.status-early-leave {
  color: #d97706;
  background: #fef3c7;
}

.transportation-section {
  margin-top: 0.5rem;
  padding-top: 0.5rem;
  border-top: 1px solid #f1f5f9;
}

.transportation-title {
  font-size: 0.688rem;
  color: #64748b;
  font-weight: 500;
  margin-bottom: 0.25rem;
}

.transportation-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.125rem 0;
}

.worker-name-small {
  font-size: 0.688rem;
  color: #475569;
}

.transport-cost {
  font-size: 0.688rem;
  color: #64748b;
  font-weight: 500;
}

@media (max-width: 768px) {
  .job-card {
    padding: 0.625rem;
  }
  
  .job-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.25rem;
  }
  
  .service-badge {
    align-self: flex-start;
  }
}
</style>
