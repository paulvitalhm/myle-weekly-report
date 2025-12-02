<template>
  <div class="report">
    <!-- Loading State -->
    <div v-if="isLoading" class="loading">Loading performance data...</div>
    
    <!-- Error State -->
    <div v-if="error" class="error">{{ error }}</div>
    
    <!-- Report Content -->
    <div v-else-if="reportData">
      <!-- Header Section -->
      <div class="report-header">
        <h1>MYLE Employee Performance Report</h1>
        <div class="period-info">
          <p class="period-dates">{{ formatPeriodDates(periodInfo.startDate, periodInfo.endDate) }}</p>
          <p class="period-stats">
            {{ periodInfo.calendarDays }} calendar days · {{ periodInfo.workRecords }} work records
          </p>
        </div>
      </div>

      <!-- Report Description -->
      <div class="report-description">
        <p>
          This report analyzes individual and team performance metrics over the selected period. 
          The Performance Index measures value created per hour worked, reflecting both individual 
          productivity and team efficiency. Teams are identified by employees working together on 
          overlapping client assignments the same day. Use this data to identify top performers, 
          optimize team compositions, and flag inconsistencies in time reporting.
        </p>
      </div>

      <!-- Performance Index Table -->
      <div class="section">
        <h2>Performance Index</h2>
        <div class="table-wrapper">
          <table class="performance-table">
            <thead>
              <tr>
                <th>Rank</th>
                <th>Index</th>
                <th>Tier</th>
                <th>Who</th>
                <th>When</th>
                <th>Where</th>
                <th>Transport</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in reportData.performanceIndex" :key="`${row.who}-${row.when}`">
                <td class="rank">{{ row.rank }}</td>
                <td class="index">{{ row.index }}</td>
                <td>
                  <span class="tier-badge" :class="`tier-${row.tier.toLowerCase()}`">
                    {{ row.tier }}
                  </span>
                </td>
                <td class="who">{{ row.who }}</td>
                <td class="when">{{ row.when }}</td>
                <td class="where">{{ row.where }}</td>
                <td class="transport" v-if="row.transportCost > 0">
                  | Trans: +${{ row.transportCost.toFixed(2) }}
                </td>
                <td class="transport" v-else></td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Best Performing Team -->
      <div v-if="reportData.bestTeam" class="section">
        <h2>Best Performing Team</h2>
        <div class="team-card best-team">
          <div class="team-header">
            <h3>{{ reportData.bestTeam.date }} | {{ reportData.bestTeam.members }} | {{ reportData.bestTeam.tier }} ({{ reportData.bestTeam.index }})</h3>
          </div>
          <div class="team-details">
            <div class="detail-row">
              <span class="label">Team Members:</span>
              <span class="value">{{ reportData.bestTeam.members }}</span>
            </div>
            <div class="detail-row">
              <span class="label">Clients Served:</span>
              <span class="value">{{ reportData.bestTeam.clients }}</span>
            </div>
            <div class="detail-row">
              <span class="label">Total Hours:</span>
              <span class="value">{{ reportData.bestTeam.totalHours }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Worst Performing Team -->
      <div v-if="reportData.worstTeam" class="section">
        <h2>Lowest Performing Team</h2>
        <div class="team-card worst-team">
          <div class="team-header">
            <h3>{{ reportData.worstTeam.date }}</h3>
            <span class="tier-badge" :class="`tier-${reportData.worstTeam.tier.toLowerCase()}`">
              {{ reportData.worstTeam.tier }} ({{ reportData.worstTeam.index }})
            </span>
          </div>
          <div class="team-details">
            <div class="detail-row">
              <span class="label">Team Members:</span>
              <span class="value">{{ reportData.worstTeam.members }}</span>
            </div>
            <div class="detail-row">
              <span class="label">Clients Served:</span>
              <span class="value">{{ reportData.worstTeam.clients }}</span>
            </div>
            <div class="detail-row">
              <span class="label">Total Hours:</span>
              <span class="value">{{ reportData.worstTeam.totalHours }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Hours Discrepancies - COMMENTED OUT (not accurate) -->
      <!-- <div v-if="reportData.discrepancies.length > 0" class="section">
        <h2>Hours Discrepancies</h2>
        <p class="section-description">
          Showing team members with hours worked differing by more than 5 minutes from their team average.
        </p>
        <div class="discrepancy-list">
          <div 
            v-for="disc in reportData.discrepancies" 
            :key="`${disc.date}-${disc.member}`"
            class="discrepancy-item"
          >
            <div class="discrepancy-header">
              <h4>{{ disc.date }}</h4>
              <span class="team-info">Team: {{ disc.teamMembers }}</span>
            </div>
            <div class="discrepancy-details">
              <div class="detail-row">
                <span class="label">{{ disc.member }}</span>
                <span class="hours">{{ disc.hoursWorked }}</span>
                <span class="difference" :class="{ negative: disc.differenceRaw < 0 }">
                  {{ disc.difference }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div> -->
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { supabase } from '../config/supabase'

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

onMounted(async () => {
  await loadReportData()
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
    
    // Calculate calendar days and work records
    const startDate = new Date(period.start_date)
    const endDate = new Date(period.end_date)
    const calendarDays = Math.ceil((endDate - startDate) / (1000 * 60 * 60 * 24)) + 1
    
    // Get work records count by joining through employees
    const { data: employees } = await supabase
      .from('employees')
      .select('id')
      .eq('period_id', props.periodId)
    
    let workRecords = 0
    if (employees && employees.length > 0) {
      const employeeIds = employees.map(e => e.id)
      const { count } = await supabase
        .from('work_days')
        .select('*', { count: 'exact', head: true })
        .in('employee_id', employeeIds)
      workRecords = count || 0
    }
    
    periodInfo.value = {
      startDate: period.start_date,
      endDate: period.end_date,
      calendarDays,
      workRecords: workRecords || 0
    }
    
    // Load performance index data
    const performanceIndex = await loadPerformanceIndex()
    
    // Detect teams and calculate team performance
    const teams = await detectTeams()
    const teamPerformance = calculateTeamPerformance(teams, performanceIndex)
    
    // Calculate hours discrepancies
    const discrepancies = calculateDiscrepancies(teams)
    
    reportData.value = {
      performanceIndex,
      bestTeam: teamPerformance.best,
      worstTeam: teamPerformance.worst,
      discrepancies
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
  
  // Get transportation costs for each work day
  const workDayIds = data.map(row => row.work_day_id).filter(id => id)
  const { data: transportData } = await supabase
    .from('client_assignments')
    .select('work_day_id, transportation_cost')
    .in('work_day_id', workDayIds)
  
  // Group transportation costs by work day
  const transportByWorkDay = {}
  transportData?.forEach(item => {
    if (!transportByWorkDay[item.work_day_id]) {
      transportByWorkDay[item.work_day_id] = 0
    }
    transportByWorkDay[item.work_day_id] += parseFloat(item.transportation_cost || 0)
  })
  
  return data.map(row => ({
    rank: row.rank,
    index: row.index,
    tier: getTier(row.index),
    who: row.who,
    when: row.when,
    where: row.where || 'Pending',
    earned: row.earned,
    workDayId: row.work_day_id,
    workDate: row.work_date,
    hoursWorked: row.hours_worked,
    transportCost: transportByWorkDay[row.work_day_id] || 0
  }))
}

const getTier = (index) => {
  if (index >= 47) return 'Top'
  if (index >= 35) return 'Good'
  return 'Low'
}

const detectTeams = async () => {
  // Get all work days with their assignments
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
  
  // Group by date
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
  
  // Identify teams (employees with shared appointments on same date)
  const teams = []
  Object.entries(dateGroups).forEach(([date, workers]) => {
    if (workers.length < 2) return // Solo workers don't form teams
    
    // Find employees with overlapping appointments
    const appointmentMap = {}
    workers.forEach(worker => {
      worker.appointments.forEach(apt => {
        if (!appointmentMap[apt.id]) {
          appointmentMap[apt.id] = []
        }
        appointmentMap[apt.id].push(worker)
      })
    })
    
    // Find appointments with multiple workers (team work)
    const teamAppointments = Object.entries(appointmentMap)
      .filter(([_, workers]) => workers.length > 1)
    
    if (teamAppointments.length > 0) {
      // Get unique team members
      const teamMembers = new Set()
      teamAppointments.forEach(([_, workers]) => {
        workers.forEach(w => teamMembers.add(w.employeeName))
      })
      
      // Get all team member data
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
    // Calculate total revenue from shared appointments
    let totalRevenue = 0
    let totalHours = 0
    const clientsSet = new Set()
    
    team.memberData.forEach(member => {
      const sharedApts = member.appointments.filter(apt => 
        team.sharedAppointments.includes(apt.id)
      )
      
      sharedApts.forEach(apt => {
        clientsSet.add(apt.name)
        // Allocate revenue proportionally
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
      date: formatDateLong(team.date),
      members: team.members.join(', '),
      index: teamIndex,
      tier: getTier(parseFloat(teamIndex)),
      clients: Array.from(clientsSet).join(', '),
      totalHours: formatHours(totalHours),
      indexValue: parseFloat(teamIndex)
    }
  })
  
  // Sort by index
  teamScores.sort((a, b) => b.indexValue - a.indexValue)
  
  return {
    best: teamScores[0] || null,
    worst: teamScores[teamScores.length - 1] || null
  }
}

const calculateDiscrepancies = (teams) => {
  const discrepancies = []
  
  teams.forEach(team => {
    if (team.memberData.length < 2) return
    
    // Calculate average hours for team
    const totalHours = team.memberData.reduce((sum, m) => sum + m.hoursWorked, 0)
    const avgHours = totalHours / team.memberData.length
    
    // Find discrepancies > 5 minutes (0.0833 hours)
    team.memberData.forEach(member => {
      const difference = member.hoursWorked - avgHours
      const diffMinutes = Math.abs(difference * 60)
      
      if (diffMinutes > 5) {
        discrepancies.push({
          date: formatDateLong(team.date),
          teamMembers: team.members.join(', '),
          member: member.employeeName,
          hoursWorked: formatHours(member.hoursWorked),
          difference: formatHoursDiff(difference),
          differenceRaw: difference,
          diffMinutes
        })
      }
    })
  })
  
  // Sort by largest difference first
  discrepancies.sort((a, b) => b.diffMinutes - a.diffMinutes)
  
  return discrepancies
}

const formatPeriodDates = (start, end) => {
  const startDate = new Date(start + 'T12:00:00')
  const endDate = new Date(end + 'T12:00:00')
  
  return `${startDate.toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })} - ${endDate.toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}`
}

const formatDateLong = (dateStr) => {
  const date = new Date(dateStr + 'T12:00:00')
  return date.toLocaleDateString('en-US', { 
    weekday: 'short',
    year: 'numeric',
    month: 'short',
    day: 'numeric'
  })
}

const formatHours = (hours) => {
  const h = Math.floor(hours)
  const m = Math.round((hours - h) * 60)
  return `${h}h ${m}m`
}

const formatHoursDiff = (diff) => {
  const sign = diff >= 0 ? '+' : ''
  const h = Math.floor(Math.abs(diff))
  const m = Math.round((Math.abs(diff) - h) * 60)
  return `${sign}${h}h ${m}m`
}
</script>

<style scoped>
.report {
  max-width: 1400px;
  margin: 0 auto;
  padding: 2rem;
}

.loading {
  text-align: center;
  padding: 3rem;
  font-size: 1.2rem;
  color: #666;
}

.error {
  color: #d32f2f;
  padding: 1rem;
  background: #ffebee;
  border-radius: 4px;
  margin-bottom: 1rem;
}

.report-header {
  background: white;
  padding: 2rem;
  border-radius: 8px;
  margin-bottom: 1.5rem;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.report-header h1 {
  margin: 0 0 1rem 0;
  color: #333;
  font-size: 2rem;
}

.period-info {
  margin: 0;
}

.period-dates {
  font-size: 1.1rem;
  font-weight: 500;
  color: #333;
  margin: 0 0 0.5rem 0;
}

.period-stats {
  color: #666;
  margin: 0;
}

.report-description {
  background: #f5f5f5;
  padding: 1.5rem;
  border-radius: 8px;
  margin-bottom: 2rem;
  border-left: 4px solid #F4A000;
}

.report-description p {
  margin: 0;
  line-height: 1.6;
  color: #555;
}

.section {
  background: white;
  padding: 2rem;
  border-radius: 8px;
  margin-bottom: 2rem;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.section h2 {
  margin: 0 0 1.5rem 0;
  color: #333;
  font-size: 1.5rem;
}

.section-description {
  color: #666;
  margin: 0 0 1rem 0;
  font-style: italic;
}

.table-wrapper {
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}

.performance-table {
  width: 100%;
  border-collapse: collapse;
  min-width: 700px;
}

.performance-table th {
  background: #f5f5f5;
  padding: 0.75rem;
  text-align: left;
  font-weight: 600;
  color: #333;
  border-bottom: 2px solid #ddd;
  white-space: nowrap;
}

.performance-table td {
  padding: 0.75rem;
  border-bottom: 1px solid #eee;
  color: #555;
}

.performance-table tr:hover {
  background: #fafafa;
}

.rank {
  font-weight: 600;
  color: #F4A000;
}

.index {
  font-weight: 600;
  font-size: 1.1rem;
  color: #333;
}

.who {
  font-weight: 500;
}

.when {
  color: #666;
  font-size: 0.9rem;
}

.where {
  color: #555;
}

.tier-badge {
  display: inline-block;
  padding: 0.25rem 0.75rem;
  border-radius: 12px;
  font-size: 0.875rem;
  font-weight: 600;
  white-space: nowrap;
}

.tier-top {
  background: #c8e6c9;
  color: #2e7d32;
}

.tier-good {
  background: #fff3cd;
  color: #f57f17;
}

.tier-low {
  background: #ffcdd2;
  color: #c62828;
}

.team-card {
  padding: 1.5rem;
  border-radius: 8px;
  border: 2px solid;
}

.best-team {
  background: #c8e6c9;
  border-color: #4caf50;
}

.worst-team {
  background: #ffcdd2;
  border-color: #f44336;
}

.team-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.team-header h3 {
  margin: 0;
  color: #333;
  font-size: 1.25rem;
}

.team-details {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.detail-row {
  display: flex;
  gap: 0.5rem;
  align-items: baseline;
}

.detail-row .label {
  font-weight: 600;
  color: #555;
  min-width: 130px;
}

.detail-row .value {
  color: #333;
}

.discrepancy-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.discrepancy-item {
  padding: 1rem;
  background: #f9f9f9;
  border-radius: 4px;
  border-left: 4px solid #ff9800;
}

.discrepancy-header {
  margin-bottom: 0.75rem;
}

.discrepancy-header h4 {
  margin: 0 0 0.25rem 0;
  color: #333;
  font-size: 1rem;
}

.team-info {
  font-size: 0.875rem;
  color: #666;
}

.discrepancy-details .detail-row {
  display: grid;
  grid-template-columns: 1fr auto auto;
  gap: 1rem;
  align-items: center;
}

.discrepancy-details .label {
  font-weight: 500;
  color: #333;
}

.hours {
  color: #666;
  text-align: right;
}

.difference {
  font-weight: 600;
  color: #f57f17;
  text-align: right;
  min-width: 80px;
}

.difference.negative {
  color: #d32f2f;
}

@media (max-width: 768px) {
  .report {
    padding: 1rem;
  }

  .report-header {
    padding: 1.5rem;
  }

  .report-header h1 {
    font-size: 1.5rem;
  }

  .section {
    padding: 1.5rem;
  }

  .section h2 {
    font-size: 1.25rem;
  }

  .performance-table th,
  .performance-table td {
    padding: 0.5rem;
    font-size: 0.9rem;
  }

  .team-header {
    flex-direction: column;
    align-items: flex-start;
  }

  .detail-row {
    flex-direction: column;
    gap: 0.25rem;
  }

  .detail-row .label {
    min-width: auto;
  }

  .discrepancy-details .detail-row {
    grid-template-columns: 1fr;
    gap: 0.5rem;
  }

  .hours,
  .difference {
    text-align: left;
  }
}
</style>
