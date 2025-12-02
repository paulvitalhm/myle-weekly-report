<template>
  <div v-if="show" class="modal-overlay" @click="$emit('close')">
    <div class="modal-content" @click.stop>
      <div class="modal-header">
        <h3>Assign Worker to Job</h3>
        <button @click="$emit('close')" class="modal-close">×</button>
      </div>
      <div class="modal-body">
        <div class="job-details">
          <h4>{{ job?.customer_name }}</h4>
          <p>{{ job?.service }} · ${{ job?.cost }}</p>
          <p>{{ job?.address }}, {{ job?.city }}</p>
          <p>Time: {{ job?.appointment_time }}</p>
        </div>
        
        <div class="worker-selection">
          <h5>Select Worker:</h5>
          <div class="worker-list">
            <div 
              v-for="worker in workers" 
              :key="worker.id"
              class="worker-option"
              :class="{ selected: selectedWorker?.id === worker.id }"
              @click="selectWorker(worker)"
            >
              <span class="worker-name">{{ worker.name }}</span>
            </div>
          </div>
        </div>
      </div>
      <div class="modal-footer">
        <button @click="$emit('close')" class="btn-secondary">Cancel</button>
        <button 
          @click="confirmAssignment" 
          class="btn-primary"
          :disabled="!selectedWorker"
        >
          Assign Worker
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue'

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

const emit = defineEmits(['close', 'assign'])

const selectedWorker = ref(null)

const selectWorker = (worker) => {
  selectedWorker.value = worker
}

const confirmAssignment = () => {
  if (selectedWorker.value && props.job) {
    emit('assign', {
      job: props.job,
      worker: selectedWorker.value
    })
  }
}

watch(() => props.show, (newVal) => {
  if (!newVal) {
    selectedWorker.value = null
  }
})
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
}

.modal-content {
  background: white;
  border-radius: 8px;
  width: 90%;
  max-width: 500px;
  max-height: 80vh;
  overflow-y: auto;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem;
  border-bottom: 1px solid #e2e8f0;
}

.modal-header h3 {
  margin: 0;
  color: #1e293b;
}

.modal-close {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: #64748b;
}

.modal-body {
  padding: 1rem;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 1rem;
  padding: 1rem;
  border-top: 1px solid #e2e8f0;
}

.job-details {
  margin-bottom: 1.5rem;
}

.job-details h4 {
  margin: 0 0 0.5rem 0;
  color: #1e293b;
}

.job-details p {
  margin: 0.25rem 0;
  color: #64748b;
}

.worker-selection h5 {
  margin: 0 0 1rem 0;
  color: #374151;
}

.worker-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.worker-option {
  padding: 0.75rem;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.2s;
}

.worker-option:hover {
  background: #f1f5f9;
}

.worker-option.selected {
  background: #667eea;
  color: white;
  border-color: #667eea;
}

.worker-name {
  font-weight: 500;
}

.btn-primary,
.btn-secondary {
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: 0.5rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-primary {
  background: #667eea;
  color: white;
}

.btn-primary:hover:not(:disabled) {
  background: #5568d3;
}

.btn-primary:disabled {
  background: #cbd5e1;
  cursor: not-allowed;
}

.btn-secondary {
  background: #f1f5f9;
  color: #475569;
  border: 1px solid #e2e8f0;
}

.btn-secondary:hover {
  background: #e2e8f0;
}
</style>
