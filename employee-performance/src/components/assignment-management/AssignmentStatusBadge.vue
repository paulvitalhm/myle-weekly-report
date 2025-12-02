<template>
  <span 
    class="status-badge" 
    :class="statusClass"
  >
    {{ statusText }}
  </span>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  status: {
    type: String,
    required: true,
    validator: (value) => ['unassigned', 'assigned', 'partial'].includes(value)
  }
})

const statusClass = computed(() => {
  return `status-${props.status}`
})

const statusText = computed(() => {
  switch (props.status) {
    case 'unassigned':
      return 'Unassigned'
    case 'assigned':
      return 'Assigned'
    case 'partial':
      return 'Partial'
    default:
      return 'Unknown'
  }
})
</script>

<style scoped>
.status-badge {
  display: inline-block;
  padding: 0.375rem 0.75rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  white-space: nowrap;
}

.status-unassigned {
  background: #fee2e2;
  color: #dc2626;
  border: 1px solid #fecaca;
}

.status-assigned {
  background: #d1fae5;
  color: #059669;
  border: 1px solid #a7f3d0;
}

.status-partial {
  background: #fef3c7;
  color: #d97706;
  border: 1px solid #fde68a;
}
</style>
