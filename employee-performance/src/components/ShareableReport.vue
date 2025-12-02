<template>
  <div class="mobile-report">
    <!-- Navigation Bar -->
    <NavigationBar :periodId="periodId" />
    
    <!-- Sticky Header -->
    <div class="sticky-header">
      <h1 class="header-title">MYLE Performance Index</h1>
      <p class="header-dates" v-if="periodInfo">
        {{ formatCompactPeriod(periodInfo.startDate, periodInfo.endDate) }}
      </p>
      <p class="header-stats" v-if="reportData && reportData.performanceIndex.length > 0">
        {{ reportData.performanceIndex.length }} records | Avg Index: {{ calculateAvgIndex() }}
      </p>
      
      <!-- Search & Filter -->
      <div class="header-controls">
        <input 
          type="text" 
          v-model="searchQuery"
          placeholder="Search by name..." 
          class="search-input"
        />
        <select v-model="filterTier" class="filter-select">
          <option value="">All Tiers</option>
          <option value="Top">Top</option>
          <option value="Good">Good</option>
          <option value="Low">Low</option>
        </select>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="isLoading" class="loading-state">
      <p>Loading performance data...</p>
    </div>

    <!-- Error State -->
    <div v-if="error" class="error-state">
      <p>Error: {{ error }}</p>
    </div>

    <!-- Scrollable Content -->
    <div v-if="!isLoading && !error && reportData" class="scrollable-content">
      <!-- Performance Cards -->
      <div class="cards-list">
        <div 
          v-for="(row, index) in filteredData" 
          :key="`${row.who}-${row.when}`"
          class="performance-card"
          :class="{ expanded: expandedCards.has(index) }"
        >
          <!-- Part 1: Always Visible -->
          <div class="card-header" @click="toggleExpand(index)">
            <span class="rank-badge-corner">#{{ row.rank }}</span>
            <div class="card-content">
              <div 
                class="index-circle" 
                :class="getTierClass(row.tier)"
              >
                {{ row.index }}
              </div>
              <div class="employee-info">
                <span class="employee-name">{{ truncate(row.who, 25) }}</span>
                <span class="employee-date">
                  {{ formatCompactDate(row.workDate) }} · {{ formatHours(row.hoursWorked) }}
                </span>
              </div>
            </div>
          </div>

          <!-- Part 2: Expandable -->
          <div class="card-body" v-if="expandedCards.has(index)">
            <div class="clients-list">
              <span 
                v-for="(client, idx) in parseClients(row.where)" 
                :key="idx"
                class="client-badge"
                :class="getServiceColorClass(client.service)"
              >
                {{ client.name }}<span v-if="client.service" class="service-type"> ({{ client.service }})</span>
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- Best Team Card -->
      <div v-if="reportData.bestTeam" class="team-card best-team">
        <div class="team-emoji">🏆</div>
        <div class="team-content">
          <h3 class="team-title">Best Performing Team</h3>
          <p class="team-date">{{ reportData.bestTeam.date }}</p>
          <div class="team-badge">
            <span :class="getTierClass(reportData.bestTeam.tier)">
              {{ reportData.bestTeam.tier }} ({{ reportData.bestTeam.index }})
            </span>
          </div>
          <div class="team-details">
            <p><strong>Members:</strong> {{ reportData.bestTeam.members }}</p>
            <p><strong>Clients:</strong> {{ reportData.bestTeam.clients }}</p>
            <p><strong>Total Hours:</strong> {{ reportData.bestTeam.totalHours }}</p>
          </div>
        </div>
      </div>

      <!-- Lowest Team Card -->
      <div v-if="reportData.worstTeam" class="team-card worst-team">
        <div class="team-emoji">⚠️</div>
        <div class="team-content">
          <h3 class="team-title">Lowest Performing Team</h3>
          <p class="team-date">{{ reportData.worstTeam.date }}</p>
          <div class="team-badge">
            <span :class="getTierClass(reportData.worstTeam.tier)">
              {{ reportData.worstTeam.tier }} ({{ reportData.worstTeam.index }})
            </span>
          </div>
          <div class="team-details">
            <p><strong>Members:</strong> {{ reportData.worstTeam.members }}</p>
            <p><strong>Clients:</strong> {{ reportData.worstTeam.clients }}</p>
            <p><strong>Total Hours:</strong> {{ reportData.worstTeam.totalHours }}</p>
          </div>
        </div>
      </div>

      <!-- Padding for fixed footer -->
      <div class="footer-spacer"></div>
    </div>

    <!-- Fixed Footer -->
    <div v-if="!isLoading && !error" class="fixed-footer">
      <button class="footer-btn" @click="showAnalytics">
        📊<span>Analytics</span>
      </button>
      <button class="footer-btn" @click="exportReport">
        📤<span>Export</span>
      </button>
      <button class="footer-btn" @click="refreshData">
        🔄<span>Refresh</span>
      </button>
      <button class="footer-btn" @click="showSettings">
        ⚙️<span>Settings</span>
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { supabase } from '../config/supabase'
import NavigationBar from './NavigationBar.vue'

const props = defineProps({
  periodId: {
    type: String,
    required: true
  }
})

const isLoading = ref(true)
const error = ref(null)
const reportData = ref(null)
const periodInfo = ref(null)
const expandedCards = ref(new Set())
const searchQuery = ref('')
const filterTier = ref('')

const avatarColors = [
  '#3b82f6', '#10b981', '#f59e0b', '#ef4444', 
  '#8b5cf6', '#ec4899', '#14b8a6', '#f97316'
]

onMounted(async () => {
  await loadReportData()
})

// Watch for period changes and reload data
watch(() => props.periodId, async (newPeriodId) => {
  if (newPeriodId) {
    await loadReportData()
  }
})

const loadReportData = async () => {
  isLoading.value = true
  error.value = null
  
  try {
    // Load period info
    const { data: period } = await supabase
      .from('periods')
      .select('start_date, end_date')
      .eq('id', props.periodId)
      .single()
    
    if (!period) throw new Error('Period not found')
    
    periodInfo.value = {
      startDate: period.start_date,
      endDate: period.end_date
    }
    
    // Load performance index data
    const performanceIndex = await loadPerformanceIndex()
    
    // Detect teams and calculate team performance
    const teams = await detectTeams()
    const teamPerformance = calculateTeamPerformance(teams, performanceIndex)
    
    reportData.value = {
      performanceIndex,
      bestTeam: teamPerformance.best,
      worstTeam: teamPerformance.worst
    }
    
  } catch (err) {
    console.error('Error loading report:', err)
    error.value = err.message
  } finally {
    isLoading.value = false
  }
}

const loadPerformanceIndex = async () => {
  const { data, error: queryError } = await supabase.rpc('get_performance_index', {
    p_period_id: props.periodId
  })
  
  if (queryError) throw queryError
  
  return data.map(row => ({
    rank: row.rank,
    index: Math.round(row.index),
    tier: getTier(row.index),
    who: row.who,
    when: row.when,
    where: row.where || 'Pending',
    earned: row.earned,
    workDayId: row.work_day_id,
    workDate: row.work_date,
    hoursWorked: row.hours_worked
  }))
}

const getTier = (index) => {
  if (index >= 47) return 'Top'
  if (index >= 35) return 'Good'
  return 'Low'
}

const getTierClass = (tier) => {
  const tierLower = tier.toLowerCase()
  if (tierLower === 'top') return 'tier-top'
  if (tierLower === 'good') return 'tier-good'
  return 'tier-low'
}

const getTierIcon = (tier) => {
  const tierLower = tier.toLowerCase()
  if (tierLower === 'top') return '🟢'
  if (tierLower === 'good') return '🟡'
  return '🔴'
}

const detectTeams = async () => {
  const { data: workDays } = await supabase
    .from('work_days')
    .select(`
      id,
      work_date,
      hours_worked,
      employee:employees!inner(id, name),
      assignments:client_assignments(
        id,
        actual_hours,
        appointment:appointments!inner(id, customer_name, cost)
      )
    `)
    .eq('employee.period_id', props.periodId)
    .gt('hours_worked', 0)
  
  if (!workDays) return []
  
  const dateGroups = {}
  workDays.forEach(wd => {
    if (!dateGroups[wd.work_date]) {
      dateGroups[wd.work_date] = []
    }
    dateGroups[wd.work_date].push({
      workDayId: wd.id,
      employeeId: wd.employee.id,
      employeeName: wd.employee.name,
      hoursWorked: wd.hours_worked,
      appointments: wd.assignments.map(a => ({
        id: a.appointment.id,
        name: a.appointment.customer_name,
        cost: a.appointment.cost,
        actualHours: a.actual_hours
      }))
    })
  })
  
  const teams = []
  Object.entries(dateGroups).forEach(([date, workers]) => {
    if (workers.length < 2) return
    
    const appointmentMap = {}
    workers.forEach(worker => {
      worker.appointments.forEach(apt => {
        if (!appointmentMap[apt.id]) {
          appointmentMap[apt.id] = []
        }
        appointmentMap[apt.id].push(worker)
      })
    })
    
    const teamAppointments = Object.entries(appointmentMap)
      .filter(([_, workers]) => workers.length > 1)
    
    if (teamAppointments.length > 0) {
      const teamMembers = new Set()
      teamAppointments.forEach(([_, workers]) => {
        workers.forEach(w => teamMembers.add(w.employeeName))
      })
      
      const teamMemberData = workers.filter(w => teamMembers.has(w.employeeName))
      
      teams.push({
        date,
        members: Array.from(teamMembers),
        memberData: teamMemberData,
        sharedAppointments: teamAppointments.map(([id]) => id)
      })
    }
  })
  
  return teams
}

const calculateTeamPerformance = (teams, performanceIndex) => {
  if (teams.length === 0) return { best: null, worst: null }
  
  const teamScores = teams.map(team => {
    let totalRevenue = 0
    let totalHours = 0
    const clientsSet = new Set()
    
    team.memberData.forEach(member => {
      const sharedApts = member.appointments.filter(apt => 
        team.sharedAppointments.includes(apt.id)
      )
      
      sharedApts.forEach(apt => {
        clientsSet.add(apt.name)
        const totalHoursOnApt = team.memberData.reduce((sum, m) => {
          const aptData = m.appointments.find(a => a.id === apt.id)
          return sum + (aptData ? aptData.actualHours : 0)
        }, 0)
        
        const allocation = (apt.actualHours / totalHoursOnApt) * apt.cost
        totalRevenue += allocation
      })
      
      totalHours += member.hoursWorked
    })
    
    const teamIndex = totalHours > 0 ? (totalRevenue / totalHours).toFixed(2) : 0
    
    return {
      date: formatCompactDate(team.date),
      members: team.members.join(', '),
      index: teamIndex,
      tier: getTier(parseFloat(teamIndex)),
      clients: Array.from(clientsSet).join(', '),
      totalHours: formatHours(totalHours),
      indexValue: parseFloat(teamIndex)
    }
  })
  
  teamScores.sort((a, b) => b.indexValue - a.indexValue)
  
  return {
    best: teamScores[0] || null,
    worst: teamScores[teamScores.length - 1] || null
  }
}

const formatCompactPeriod = (start, end) => {
  const startDate = new Date(start + 'T12:00:00')
  const endDate = new Date(end + 'T12:00:00')
  
  return `${startDate.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })} - ${endDate.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' })}`
}

const formatCompactDate = (dateStr) => {
  const date = new Date(dateStr + 'T12:00:00')
  return date.toLocaleDateString('en-US', { 
    weekday: 'short',
    month: 'short',
    day: 'numeric'
  })
}

const formatHours = (hours) => {
  const h = Math.floor(hours)
  const m = Math.round((hours - h) * 60)
  return `${h}h ${m}m`
}

const truncate = (text, maxLength) => {
  if (!text) return ''
  if (text.length <= maxLength) return text
  return text.substring(0, maxLength - 3) + '...'
}

const parseClients = (clientsStr) => {
  if (!clientsStr || clientsStr === 'Pending') return []
  
  const clients = clientsStr.split(',').map(c => c.trim())
  return clients.map(client => {
    const match = client.match(/^(.+?)\s*\((.+?)\)$/)
    if (match) {
      return { name: match[1].trim(), service: match[2].trim() }
    }
    // If no service type, return just name with empty service
    return { name: client, service: '' }
  })
}

const getServiceColorClass = (service) => {
  const serviceLower = service.toLowerCase()
  if (serviceLower.includes('airbnb')) return 'service-airbnb'
  if (serviceLower.includes('maintenance')) return 'service-maintenance'
  if (serviceLower.includes('one-time') || serviceLower.includes('first time') || serviceLower.includes('deep')) return 'service-onetime'
  if (serviceLower.includes('moving') || serviceLower.includes('pre-sale')) return 'service-moving'
  return 'service-default'
}

const getInitials = (name) => {
  if (!name) return '??'
  const parts = name.trim().split(' ')
  if (parts.length === 1) return parts[0].substring(0, 2).toUpperCase()
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
}

const getAvatarColor = (index) => {
  return avatarColors[index % avatarColors.length]
}

const toggleExpand = (index) => {
  if (expandedCards.value.has(index)) {
    expandedCards.value.delete(index)
  } else {
    expandedCards.value.add(index)
  }
  expandedCards.value = new Set(expandedCards.value)
}

const calculateAvgIndex = () => {
  if (!reportData.value || reportData.value.performanceIndex.length === 0) return '0'
  const sum = reportData.value.performanceIndex.reduce((acc, row) => acc + parseFloat(row.index), 0)
  return (sum / reportData.value.performanceIndex.length).toFixed(1)
}

const filteredData = computed(() => {
  if (!reportData.value) return []
  
  let data = reportData.value.performanceIndex
  
  if (searchQuery.value) {
    const query = searchQuery.value.toLowerCase()
    data = data.filter(row => row.who.toLowerCase().includes(query))
  }
  
  if (filterTier.value) {
    data = data.filter(row => row.tier === filterTier.value)
  }
  
  return data
})

// Footer actions
const showAnalytics = () => {
  alert('Analytics feature coming soon!')
}

const exportReport = () => {
  alert('Export feature coming soon!')
}

const refreshData = () => {
  loadReportData()
}

const showSettings = () => {
  alert('Settings feature coming soon!')
}
</script>

<style scoped>
.mobile-report {
  max-width: 100vw;
  min-height: 100vh;
  background: #f8fafc;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  padding-bottom: 80px;
}

/* Sticky Header */
.sticky-header {
  position: sticky;
  top: 0;
  z-index: 100;
  background: linear-gradient(135deg, #2563eb 0%, #1e40af 100%);
  color: white;
  padding: 1rem;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.header-title {
  font-size: 1.25rem;
  font-weight: 700;
  margin: 0 0 0.5rem 0;
}

.header-dates {
  font-size: 0.875rem;
  margin: 0 0 0.25rem 0;
  opacity: 0.9;
}

.header-stats {
  font-size: 0.813rem;
  margin: 0 0 1rem 0;
  opacity: 0.8;
}

.header-controls {
  display: flex;
  gap: 0.5rem;
}

.search-input,
.filter-select {
  flex: 1;
  padding: 0.5rem;
  border: none;
  border-radius: 0.5rem;
  font-size: 0.875rem;
}

.filter-select {
  flex: 0 0 100px;
}

/* Scrollable Content */
.scrollable-content {
  padding: 1rem;
}

/* Performance Cards */
.cards-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  margin-bottom: 1.5rem;
}

.performance-card {
  background: white;
  border-radius: 0.75rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  overflow: hidden;
  transition: all 0.2s ease;
}

.performance-card:active {
  transform: scale(0.98);
}

.card-header {
  position: relative;
  display: flex;
  padding: 1rem;
  cursor: pointer;
}

.rank-badge-corner {
  position: absolute;
  top: 0.5rem;
  right: 0.5rem;
  background: #e2e8f0;
  color: #64748b;
  padding: 0.375rem 0.625rem;
  border-radius: 0.5rem;
  font-size: 0.75rem;
  font-weight: 600;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.12);
  border: 1px solid #cbd5e1;
}

.card-content {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  flex: 1;
}

.index-circle {
  width: 52px;
  height: 52px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-weight: 700;
  font-size: 1.125rem;
  flex-shrink: 0;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.index-circle.tier-top {
  background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
  box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
}

.index-circle.tier-good {
  background: linear-gradient(135deg, #10b981 0%, #059669 100%);
}

.index-circle.tier-low {
  background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
}

.employee-info {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
  min-width: 0;
  flex: 1;
}

.employee-name {
  font-weight: 600;
  font-size: 0.938rem;
  color: #1e293b;
  text-align: left;
}

.employee-date {
  font-size: 0.75rem;
  color: #64748b;
  text-align: left;
}

.card-body {
  padding: 0 1rem 1rem 1rem;
  border-top: 1px solid #f1f5f9;
}

.clients-list {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  padding-top: 0.75rem;
}

.client-badge {
  display: inline-block;
  padding: 0.375rem 0.625rem;
  border-radius: 0.5rem;
  font-size: 0.75rem;
  font-weight: 600;
  border: 1px solid;
}

.service-type {
  font-weight: 500;
  opacity: 0.8;
}

.client-badge.service-airbnb {
  background: #dbeafe;
  color: #1e40af;
  border-color: #93c5fd;
}

.client-badge.service-maintenance {
  background: #fef3c7;
  color: #92400e;
  border-color: #fcd34d;
}

.client-badge.service-onetime {
  background: #fee2e2;
  color: #991b1b;
  border-color: #fca5a5;
}

.client-badge.service-moving {
  background: #fef3c7;
  color: #78350f;
  border-color: #fbbf24;
}

.client-badge.service-default {
  background: #f1f5f9;
  color: #475569;
  border-color: #cbd5e0;
}

/* Team Cards */
.team-card {
  display: flex;
  gap: 1rem;
  padding: 1rem;
  border-radius: 0.75rem;
  margin-bottom: 1rem;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.best-team {
  background: linear-gradient(135deg, #d1fae5 0%, #a7f3d0 100%);
  border: 2px solid #10b981;
}

.worst-team {
  background: linear-gradient(135deg, #fee2e2 0%, #fecaca 100%);
  border: 2px solid #ef4444;
}

.team-emoji {
  font-size: 2rem;
  flex-shrink: 0;
}

.team-content {
  flex: 1;
}

.team-title {
  font-size: 1rem;
  font-weight: 700;
  margin: 0 0 0.25rem 0;
  color: #1e293b;
}

.team-date {
  font-size: 0.813rem;
  margin: 0 0 0.5rem 0;
  color: #475569;
}

.team-badge span {
  display: inline-block;
  padding: 0.25rem 0.625rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 700;
  margin-bottom: 0.75rem;
}

.team-badge .tier-top {
  background: #047857;
  color: white;
}

.team-badge .tier-good {
  background: #b45309;
  color: white;
}

.team-badge .tier-low {
  background: #b91c1c;
  color: white;
}

.team-details p {
  margin: 0.375rem 0;
  font-size: 0.813rem;
  color: #334155;
}

.team-details strong {
  font-weight: 600;
}

.footer-spacer {
  height: 20px;
}

/* Fixed Footer */
.fixed-footer {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background: white;
  border-top: 1px solid #e2e8f0;
  display: flex;
  justify-content: space-around;
  padding: 0.75rem;
  box-shadow: 0 -2px 8px rgba(0, 0, 0, 0.05);
  z-index: 100;
}

.footer-btn {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.25rem;
  background: none;
  border: none;
  padding: 0.5rem;
  cursor: pointer;
  color: #64748b;
  font-size: 1.25rem;
  transition: color 0.2s ease;
}

.footer-btn:active {
  transform: scale(0.95);
}

.footer-btn span {
  font-size: 0.625rem;
  font-weight: 500;
}

.footer-btn:hover {
  color: #2563eb;
}

/* States */
.loading-state,
.error-state {
  text-align: center;
  padding: 3rem 1rem;
}

.error-state {
  color: #dc2626;
  background: #fee2e2;
  margin: 1rem;
  border-radius: 0.5rem;
}

/* Tablet/Desktop */
@media (min-width: 768px) {
  .mobile-report {
    max-width: 768px;
    margin: 0 auto;
  }
  
  .scrollable-content {
    padding: 1.5rem;
  }
}
</style>
