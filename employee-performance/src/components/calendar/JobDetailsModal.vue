<template>
  <div v-if="show" class="modal-overlay" @click="$emit('close')">
    <div class="modal-content" @click.stop>
      <div class="modal-header">
        <h3>Job Details</h3>
        <button @click="$emit('close')" class="modal-close">×</button>
      </div>
      
      <div class="modal-body">
        <!-- Job Summary -->
        <div class="job-summary">
          <div class="summary-section">
            <h4 class="client-name">{{ job.customer_name }}</h4>
            <p class="service-info">
              <span class="service-badge" :class="getServiceClass()">
                {{ job.service }}
              </span>
            </p>
            <p class="appointment-time">
              {{ formatDate(job.appointment_date) }} at {{ job.appointment_time }}
            </p>
            <p class="job-address">{{ job.address }}, {{ job.city }}</p>
            <p class="job-cost">Job Cost: ${{ formatCurrency(job.cost) }}</p>
          </div>
        </div>

        <!-- Assigned Workers -->
        <div class="workers-section">
          <h4>Assigned Workers ({{ workers.length }})</h4>
          <div class="workers-list">
            <div 
              v-for="(worker, index) in workers" 
              :key="index"
              class="worker-card"
            >
              <div class="worker-header">
                <span class="worker-name">{{ worker }}</span>
                <span class="worker-status" :class="getWorkerStatusClass(worker)">
                  {{ getWorkerStatusText(worker) }}
                </span>
              </div>
              
              <div class="worker-details">
                <div class="detail-row">
                  <span class="detail-label">Hours Worked:</span>
                  <span class="detail-value">{{ getWorkerHours(worker) }}</span>
                </div>
                <div class="detail-row">
                  <span class="detail-label">Performance Index:</span>
                  <span class="detail-value">
                    <span class="index-badge" :class="getWorkerTierClass(worker)">
                      {{ getWorkerIndex(worker) }}
                    </span>
                  </span>
                </div>
                <div v-if="getTransportationCost(worker) > 0" class="detail-row">
                  <span class="detail-label">Transportation Cost:</span>
                  <span class="detail-value">${{ getTransportationCost(worker) }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Job Notes/Additional Info -->
        <div v-if="job.notes" class="notes-section">
          <h4>Job Notes</h4>
          <p class="job-notes">{{ job.notes }}</p>
        </div>
      </div>

      <div class="modal-footer">
        <button @click="$emit('close')" class="btn-close">Close</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  show: {
    type: Boolean,
    required: true
  },
  job: {
    type: Object,
    default: null
  },
  workers: {
    type: Array,
    default: () => []
  }
})

defineEmits(['close'])

// Computed
const hasTransportationCosts = computed(() => {
  return props.workers.some(worker => getTransportationCost(worker) > 0)
})

// Methods
const getServiceClass = () => {
  const service = props.job?.service?.toLowerCase() || ''
  
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

const getWorkerHours = (worker) => {
  // This would need to be implemented based on assignment data
  // For now, return random hours
  const hours = Math.random() * 6 + 2 // Random between 2-8 hours
  const h = Math.floor(hours)
  const m = Math.round((hours - h) * 60)
  return m > 0 ? `${h}h ${m}m` : `${h}h`
}

const getWorkerIndex = (worker) => {
  // This would need to be implemented based on performance calculation
  // For now, return random index
  return (Math.random() * 30 + 35).toFixed(2) // Random between 35-65
}

const getWorkerTierClass = (worker) => {
  const index = parseFloat(getWorkerIndex(worker))
  if (index >= 47) return 'tier-top'
  if (index >= 35) return 'tier-good'
  return 'tier-low'
}

const getTransportationCost = (worker) => {
  // This would need to be implemented based on assignment data
  // For now, return random cost
  return (Math.random() * 10 + 1).toFixed(2)
}

const formatDate = (dateStr) => {
  if (!dateStr) return ''
  const date = new Date(dateStr + 'T12:00:00')
  return date.toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric'
  })
}

const formatCurrency = (amount) => {
  return (amount || 0).toFixed(2)
}
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 1rem;
}

.modal-content {
  background: white;
  border-radius: 1rem;
  max-width: 600px;
  width: 100%;
  max-height: 90vh;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem;
  border-bottom: 1px solid #e2e8f0;
}

.modal-header h3 {
  margin: 0;
  font-size: 1.25rem;
  font-weight: 700;
  color: #1e293b;
}

.modal-close {
  background: none;
  border: none;
  font-size: 1.5rem;
  color: #94a3b8;
  cursor: pointer;
  padding: 0.25rem;
  line-height: 1;
  transition: color 0.2s;
}

.modal-close:hover {
  color: #64748b;
}

.modal-body {
  flex: 1;
  overflow-y: auto;
  padding: 1.5rem;
}

.job-summary {
  margin-bottom: 1.5rem;
}

.summary-section {
  padding: 1rem;
  background: linear-gradient(135deg, #f1f5f9 0%, #e2e8f0 100%);
  border-radius: 0.75rem;
}

.client-name {
  margin: 0 0 0.5rem 0;
  font-size: 1.25rem;
  font-weight: 700;
  color: #1e293b;
}

.service-info {
  margin: 0 0 0.5rem 0;
}

.service-badge {
  display: inline-block;
  padding: 0.375rem 0.75rem;
  border-radius: 0.5rem;
  font-size: 0.813rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
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

.appointment-time {
  margin: 0 0 0.25rem 0;
  font-size: 0.875rem;
  color: #64748b;
}

.job-address {
  margin: 0 0 0.25rem 0;
  font-size: 0.875rem;
  color: #64748b;
}

.job-cost {
  margin: 0;
  font-size: 1rem;
  color: #667eea;
  font-weight: 700;
}

.workers-section {
  margin-bottom: 1.5rem;
}

.workers-section h4 {
  margin: 0 0 1rem 0;
  font-size: 1rem;
  font-weight: 700;
  color: #1e293b;
}

.workers-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.worker-card {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 0.5rem;
  padding: 1rem;
}

.worker-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.75rem;
}

.worker-name {
  font-size: 1rem;
  font-weight: 600;
  color: #1e293b;
}

.worker-status {
  font-size: 0.75rem;
  font-weight: 500;
  padding: 0.25rem 0.5rem;
  border-radius: 0.375rem;
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

.worker-details {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.detail-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.25rem 0;
}

.detail-label {
  font-size: 0.875rem;
  color: #64748b;
  font-weight: 500;
}

.detail-value {
  font-size: 0.875rem;
  color: #1e293b;
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

.notes-section {
  margin-top: 1.5rem;
  padding-top: 1.5rem;
  border-top: 1px solid #e2e8f0;
}

.notes-section h4 {
  margin: 0 0 0.5rem 0;
  font-size: 1rem;
  font-weight: 700;
  color: #1e293b;
}

.job-notes {
  margin: 0;
  font-size: 0.875rem;
  color: #475569;
  line-height: 1.5;
  background: #f8fafc;
  padding: 1rem;
  border-radius: 0.5rem;
  border-left: 3px solid #667eea;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  padding: 1.5rem;
  border-top: 1px solid #e2e8f0;
  background: #f8fafc;
}

.btn-close {
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  background: #f1f5f9;
  color: #475569;
}

.btn-close:hover {
  background: #e2e8f0;
}

@media (max-width: 768px) {
  .modal-content {
    margin: 1rem;
    max-height: calc(100vh - 2rem);
  }
  
  .modal-header,
  .modal-body,
  .modal-footer {
    padding: 1rem;
  }
  
  .worker-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.5rem;
  }
}
</style>
