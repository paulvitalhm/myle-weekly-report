<template>
  <div class="team-card" :class="{ 'best-team': team.isBest, 'worst-team': team.isWorst }">
    <div class="team-header">
      <div class="team-date-section">
        <h3 class="team-date">{{ formatDate(team.date) }}</h3>
        <div class="team-badge" :class="getTierClass(team.tier)">
          {{ team.tier }} ({{ team.index }})
        </div>
      </div>
      <div class="team-stats">
        <div class="stat-item">
          <span class="stat-label">Performance</span>
          <span class="stat-value">{{ team.index }}</span>
        </div>
        <div class="stat-item">
          <span class="stat-label">Hours</span>
          <span class="stat-value">{{ team.totalHours }}</span>
        </div>
        <div class="stat-item">
          <span class="stat-label">Efficiency</span>
          <span class="stat-value">{{ calculateEfficiency(team) }}%</span>
        </div>
      </div>
    </div>

    <div class="team-members">
      <h4 class="section-title">Team Members</h4>
      <div class="members-list">
        <div 
          v-for="member in team.members" 
          :key="member"
          class="member-tag"
        >
          {{ member }}
        </div>
      </div>
    </div>

    <div class="daily-assignments">
      <h4 class="section-title">Assignments for {{ formatDate(team.date) }}</h4>
      <div class="assignment-cards">
        <div 
          v-for="assignment in deduplicatedAssignments" 
          :key="assignment.uniqueId"
          class="assignment-card"
        >
          <div class="assignment-header">
            <span class="assignment-time">{{ assignment.time }}</span>
            <span class="assignment-workers">{{ assignment.workers.join(', ') }}</span>
          </div>
          <h6 class="assignment-client">{{ assignment.client }}</h6>
          <p class="assignment-service">{{ assignment.service }} · ${{ assignment.cost }}</p>
          <p class="assignment-address">{{ assignment.address }}</p>
          <div class="assignment-meta">
            <span class="assignment-team-size">Team: {{ assignment.teamSize }} workers</span>
            <span class="assignment-status" :class="assignment.status">
              {{ assignment.status }}
            </span>
          </div>
        </div>
      </div>
    </div>

    <div class="team-summary">
      <div class="summary-item">
        <span class="summary-label">Total Revenue:</span>
        <span class="summary-value">${{ formatCurrency(team.totalRevenue) }}</span>
      </div>
      <div class="summary-item">
        <span class="summary-label">Jobs Completed:</span>
        <span class="summary-value">{{ team.completedJobs }}/{{ team.assignments.length }}</span>
      </div>
      <div class="summary-item">
        <span class="summary-label">Avg Revenue/Job:</span>
        <span class="summary-value">${{ formatCurrency(team.totalRevenue / team.assignments.length) }}</span>
      </div>
    </div>

    <div class="team-actions">
      <button @click="$emit('view-details', team)" class="btn-primary">
        View Details
      </button>
      <button @click="$emit('export', team)" class="btn-secondary">
        Export
      </button>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  team: {
    type: Object,
    required: true
  }
})

defineEmits(['view-details', 'export'])

const deduplicatedAssignments = computed(() => {
  const grouped = {}
  
  props.team.assignments.forEach(assignment => {
    const key = `${assignment.client}-${assignment.time}-${assignment.address}`
    if (!grouped[key]) {
      grouped[key] = {
        ...assignment,
        uniqueId: key,
        teamSize: 0,
        workers: []
      }
    }
    assignment.workers.forEach(worker => {
      if (!grouped[key].workers.includes(worker)) {
        grouped[key].workers.push(worker)
      }
    })
    grouped[key].teamSize = grouped[key].workers.length
  })
  
  return Object.values(grouped)
})

const formatDate = (dateStr) => {
  const date = new Date(dateStr + 'T12:00:00')
  return date.toLocaleDateString('en-US', { 
    weekday: 'short',
    month: 'short',
    day: 'numeric'
  })
}

const formatCurrency = (amount) => {
  return amount.toFixed(2)
}

const getTierClass = (tier) => {
  if (tier === 'Top') return 'tier-top'
  if (tier === 'Good') return 'tier-good'
  return 'tier-low'
}

const calculateEfficiency = (team) => {
  const revenuePerHour = team.totalRevenue / team.totalHours
  const maxEfficiency = 100
  return Math.min(100, Math.round((revenuePerHour / maxEfficiency) * 100))
}
</script>

<style scoped>
.team-card {
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 0.75rem;
  padding: 1.5rem;
  transition: all 0.2s ease;
}

.team-card:hover {
  border-color: #cbd5e1;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
}

.team-card.best-team {
  border-color: #10b981;
  background: linear-gradient(135deg, #ecfdf5 0%, #d1fae5 100%);
}

.team-card.worst-team {
  border-color: #ef4444;
  background: linear-gradient(135deg, #fef2f2 0%, #fee2e2 100%);
}

.team-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 1rem;
}

.team-date-section {
  flex: 1;
}

.team-date {
  margin: 0 0 0.5rem 0;
  font-size: 1.125rem;
  font-weight: 600;
  color: #1e293b;
}

.team-badge {
  display: inline-block;
  padding: 0.25rem 0.75rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.team-badge.tier-top {
  background: #047857;
  color: white;
}

.team-badge.tier-good {
  background: #b45309;
  color: white;
}

.team-badge.tier-low {
  background: #b91c1c;
  color: white;
}

.team-stats {
  display: flex;
  gap: 1rem;
}

.stat-item {
  text-align: center;
}

.stat-label {
  display: block;
  font-size: 0.75rem;
  color: #64748b;
  margin-bottom: 0.25rem;
}

.stat-value {
  display: block;
  font-size: 1.125rem;
  font-weight: 700;
  color: #1e293b;
}

.section-title {
  margin: 0 0 0.75rem 0;
  font-size: 0.875rem;
  font-weight: 600;
  color: #374151;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.team-members,
.daily-assignments,
.team-summary {
  margin-bottom: 1.5rem;
}

.members-list {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.member-tag {
  padding: 0.375rem 0.75rem;
  background: #f1f5f9;
  border: 1px solid #e2e8f0;
  border-radius: 0.375rem;
  font-size: 0.813rem;
  color: #475569;
}

.daily-assignments {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 0.5rem;
  padding: 1rem;
}

.assignment-cards {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.assignment-card {
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  padding: 0.75rem;
  transition: all 0.2s ease;
}

.assignment-card:hover {
  border-color: #cbd5e1;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
}

.assignment-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.5rem;
}

.assignment-time {
  font-weight: 600;
  color: #667eea;
  font-size: 0.875rem;
}

.assignment-workers {
  font-size: 0.75rem;
  color: #64748b;
}

.assignment-client {
  margin: 0.25rem 0;
  font-size: 0.9rem;
  font-weight: 600;
  color: #1e293b;
}

.assignment-service {
  margin: 0.25rem 0;
  font-size: 0.8rem;
  color: #667eea;
}

.assignment-address {
  margin: 0;
  font-size: 0.75rem;
  color: #64748b;
}

.assignment-meta {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 0.5rem;
}

.assignment-team-size {
  font-size: 0.75rem;
  color: #64748b;
}

.assignment-status {
  display: inline-block;
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  font-size: 0.75rem;
  font-weight: 600;
}

.assignment-status.completed {
  background: #d1fae5;
  color: #047857;
}

.team-summary {
  background: #f1f5f9;
  border: 1px solid #e2e8f0;
  border-radius: 0.5rem;
  padding: 1rem;
}

.summary-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.375rem 0;
  font-size: 0.875rem;
}

.summary-item:not(:last-child) {
  border-bottom: 1px solid #e2e8f0;
}

.summary-label {
  color: #64748b;
  font-weight: 500;
}

.summary-value {
  font-weight: 600;
  color: #1e293b;
}

.team-actions {
  display: flex;
  gap: 0.75rem;
}

.btn-primary,
.btn-secondary {
  flex: 1;
  padding: 0.75rem;
  border: none;
  border-radius: 0.5rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  font-size: 0.875rem;
}

.btn-primary {
  background: #667eea;
  color: white;
}

.btn-primary:hover {
  background: #5568d3;
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
