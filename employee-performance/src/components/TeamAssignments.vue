<template>
  <div class="team-assignments-container">
    <NavigationBar :periodId="periodId" />
    
    <div class="sticky-header">
      <h1>Team Assignments</h1>
      <p class="period-info" v-if="periodInfo">
        {{ formatPeriod(periodInfo.startDate, periodInfo.endDate) }}
      </p>
      
      <div class="header-controls">
        <input 
          v-model="searchQuery" 
          type="text" 
          placeholder="Search teams, workers, clients..."
          class="search-input"
        />
        <select v-model="filterStatus" class="filter-select">
          <option value="all">All Teams</option>
          <option value="completed">Completed</option>
          <option value="pending">Pending</option>
        </select>
        <select v-model="sortBy" class="filter-select">
          <option value="date">Sort by Date</option>
          <option value="performance">Sort by Performance</option>
          <option value="efficiency">Sort by Efficiency</option>
        </select>
      </div>
    </div>

    <div v-if="loading" class="loading-state">
      <p>Loading team assignments...</p>
    </div>

    <div v-if="error" class="error-state">
      <p>{{ error }}</p>
    </div>
    
    <div v-if="!loading && !error" class="content">
      <UnassignedJobs 
        :jobs="unassignedJobs"
        @assign="openAssignmentModal"
      />

      <div v-if="sortedTeams.length === 0" class="empty-state">
        <h3>No teams found</h3>
        <p>Teams are automatically detected when multiple workers share appointments on the same day.</p>
      </div>
      
      <div v-else class="teams-grid">
        <TeamCard 
          v-for="team in sortedTeams" 
          :key="team.id"
          :team="team"
          @view-details="viewTeamDetails"
          @export="exportTeamData"
        />
      </div>

      <div class="footer-spacer"></div>
    </div>

    <AssignmentModal
      :show="showAssignmentModal"
      :job="selectedJob"
      :workers="availableWorkers"
      @close="closeAssignmentModal"
      @assign="handleAssignment"
    />

    <div class="fixed-footer">
      <button class="footer-btn" @click="goBack">
        ← Back
      </button>
      <button class="footer-btn" @click="refreshData">
        🔄 Refresh
      </button>
      <button class="footer-btn" @click="exportAllTeams">
        📊 Export All
      </button>
      <button class="footer-btn primary" @click="viewAnalytics">
        📈 Analytics
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../config/supabase'
import NavigationBar from './NavigationBar.vue'
import TeamCard from './team-assignments/TeamCard.vue'
import AssignmentModal from './team-assignments/AssignmentModal.vue'
import UnassignedJobs from './team-assignments/UnassignedJobs.vue'

const router = useRouter()

const props = defineProps({
  periodId: {
    type: String,
    required: true
  }
})

// State
const loading = ref(true)
const error = ref(null)
const periodInfo = ref(null)
const teams = ref([])
const unassignedJobs = ref([])
const searchQuery = ref('')
const filterStatus = ref('all')
const sortBy = ref('date')
const showAssignmentModal = ref(false)
const selectedJob = ref(null)
const availableWorkers = ref([])

// Computed
const filteredTeams = computed(() => {
  let filtered = teams.value

  if (searchQuery.value) {
    const query = searchQuery.value.toLowerCase()
    filtered = filtered.filter(team =>
      team.members.some(member => member.toLowerCase().includes(query)) ||
      team.clients.toLowerCase().includes(query) ||
      team.date.includes(query)
    )
  }

  if (filterStatus.value !== 'all') {
    filtered = filtered.filter(team => {
      if (filterStatus.value === 'completed') return team.isCompleted
      if (filterStatus.value === 'pending') return !team.isCompleted
      return true
    })
  }

  return filtered
})

const sortedTeams = computed(() => {
  const teamsCopy = [...filteredTeams.value]
  
  switch (sortBy.value) {
    case 'date':
      return teamsCopy.sort((a, b) => new Date(a.date) - new Date(b.date))
    case 'performance':
      return teamsCopy.sort((a, b) => parseFloat(b.index) - parseFloat(a.index))
    case 'efficiency':
      return teamsCopy.sort((a, b) => calculateEfficiency(b) - calculateEfficiency(a))
    default:
      return teamsCopy
  }
})

// Lifecycle
onMounted(async () => {
  await loadData()
})

// Methods
const loadData = async () => {
  try {
    loading.value = true
    
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

    const [teamsData, unassignedData] = await Promise.all([
      loadTeamAssignments(),
      loadUnassignedJobs()
    ])
    
    teams.value = teamsData
    unassignedJobs.value = unassignedData
    loading.value = false
  } catch (err) {
    console.error('Error loading team assignments:', err)
    error.value = err.message
    loading.value = false
  }
}

const loadTeamAssignments = async () => {
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
        transportation_cost,
        appointment:appointments!inner(id, customer_name, cost, appointment_time, service, address, city)
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
      assignments: wd.assignments.map(a => ({
        id: a.appointment.id,
        name: a.appointment.customer_name,
        cost: a.appointment.cost,
        actualHours: a.actual_hours,
        transportationCost: a.transportation_cost || 0,
        time: a.appointment.appointment_time,
        service: a.appointment.service,
        address: a.appointment.address,
        city: a.appointment.city
      }))
    })
  })

  const teams = []
  Object.entries(dateGroups).forEach(([date, workers]) => {
    if (workers.length < 2) return

    const appointmentMap = {}
    workers.forEach(worker => {
      worker.assignments.forEach(apt => {
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

      let totalRevenue = 0
      let totalHours = 0
      const clientsSet = new Set()
      let assignmentCount = 0
      const assignments = []

      teamMemberData.forEach(member => {
        const sharedApts = member.assignments.filter(apt => 
          teamAppointments.some(([aptId]) => aptId === apt.id)
        )

        sharedApts.forEach(apt => {
          clientsSet.add(apt.name)
          assignmentCount++

          const totalHoursOnApt = teamMemberData.reduce((sum, m) => {
            const aptData = m.assignments.find(a => a.id === apt.id)
            return sum + (aptData ? aptData.actualHours : 0)
          }, 0)

          const allocation = (apt.actualHours / totalHoursOnApt) * apt.cost - apt.transportationCost
          totalRevenue += allocation

          assignments.push({
            id: apt.id,
            time: apt.time,
            client: apt.name,
            service: apt.service,
            cost: apt.cost,
            address: apt.address,
            workers: teamMemberData.map(w => w.employeeName),
            status: 'completed'
          })
        })

        totalHours += member.hoursWorked
      })

      const teamIndex = totalHours > 0 ? (totalRevenue / totalHours) : 0
      const completedJobs = assignments.filter(a => a.status === 'completed').length

      teams.push({
        id: `${date}-team`,
        date,
        members: Array.from(teamMembers),
        clients: Array.from(clientsSet).join(', '),
        totalRevenue,
        totalHours,
        assignmentCount,
        assignments,
        completedJobs,
        index: teamIndex.toFixed(2),
        tier: getTier(teamIndex),
        isCompleted: completedJobs === assignments.length,
        isBest: false,
        isWorst: false
      })
    }
  })

  teams.sort((a, b) => parseFloat(b.index) - parseFloat(a.index))
  if (teams.length > 0) {
    teams[0].isBest = true
    if (teams.length > 1) {
      teams[teams.length - 1].isWorst = true
    }
  }

  return teams
}

const loadUnassignedJobs = async () => {
  const { data: appointments } = await supabase
    .from('appointments')
    .select(`
      id,
      appointment_date,
      appointment_time,
      customer_name,
      service,
      cost,
      address,
      city
    `)
    .eq('period_id', props.periodId)
    .order('appointment_date', { ascending: true })
    .order('appointment_time', { ascending: true })

  const { data: assignedAppointments } = await supabase
    .from('client_assignments')
    .select('appointment_id')
    .eq('work_day.work_days.employee.period_id', props.periodId)

  const assignedIds = new Set(assignedAppointments?.map(a => a.appointment_id) || [])
  
  return (appointments || []).filter(apt => !assignedIds.has(apt.id))
}

const getTier = (index) => {
  if (index >= 47) return 'Top'
  if (index >= 35) return 'Good'
  return 'Low'
}

const formatPeriod = (start, end) => {
  return `${start} to ${end}`
}

const formatDate = (dateStr) => {
  const date = new Date(dateStr + 'T12:00:00')
  return date.toLocaleDateString('en-US', { 
    weekday: 'short',
    month: 'short',
    day: 'numeric'
  })
}

const calculateEfficiency = (team) => {
  const revenuePerHour = team.totalRevenue / team.totalHours
  const maxEfficiency = 100
  return Math.min(100, Math.round((revenuePerHour / maxEfficiency) * 100))
}

// Modal functions
const openAssignmentModal = async (job) => {
  selectedJob.value = job
  await loadAvailableWorkers()
  showAssignmentModal.value = true
}

const closeAssignmentModal = () => {
  showAssignmentModal.value = false
  selectedJob.value = null
  selectedWorker.value = null
}

const loadAvailableWorkers = async () => {
  const { data: workers } = await supabase
    .from('employees')
    .select('id, name')
    .eq('period_id', props.periodId)
    .order('name', { ascending: true })
  
  availableWorkers.value = workers || []
}

const handleAssignment = async ({ job, worker }) => {
  try {
    const { data: workDay } = await supabase
      .from('work_days')
      .insert({
        employee_id: worker.id,
        work_date: job.appointment_date,
        hours_worked: 0
      })
      .select()
      .single()
    
    if (workDay) {
      await supabase
        .from('client_assignments')
        .insert({
          work_day_id: workDay.id,
          appointment_id: job.id,
          actual_hours: 0,
          transportation_cost: 0
        })
      
      await loadData()
      closeAssignmentModal()
    }
  } catch (err) {
    console.error('Error assigning worker:', err)
    error.value = 'Failed to assign worker. Please try again.'
  }
}

// Action handlers
const viewTeamDetails = (team) => {
  console.log('View team details:', team)
}

const exportTeamData = (team) => {
  const data = {
    team: team,
    exportDate: new Date().toISOString()
  }
  downloadJSON(data, `team-${team.date}-data.json`)
}

const exportAllTeams = () => {
  const data = {
    teams: teams.value,
    unassignedJobs: unassignedJobs.value,
    period: periodInfo.value,
    exportDate: new Date().toISOString()
  }
  downloadJSON(data, `all-teams-${props.periodId}.json`)
}

const viewAnalytics = () => {
  console.log('View team analytics')
}

const refreshData = async () => {
  await loadData()
}

const goBack = () => {
  router.back()
}

const downloadJSON = (data, filename) => {
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}
</script>

<style scoped>
.team-assignments-container {
  min-height: 100vh;
  background: #ffffff;
  padding-bottom: 80px;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

.sticky-header {
  position: sticky;
  top: 0;
  z-index: 100;
  background: #ffffff;
  color: #1e293b;
  padding: 1rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  border-bottom: 1px solid #e2e8f0;
}

.sticky-header h1 {
  margin: 0 0 0.5rem 0;
  font-size: 1.25rem;
  font-weight: 700;
}

.period-info {
  margin: 0 0 1rem 0;
  font-size: 0.875rem;
  color: #64748b;
}

.header-controls {
  display: flex;
  gap: 0.5rem;
}

.search-input,
.filter-select {
  flex: 1;
  padding: 0.75rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  background: white;
}

.filter-select {
  flex: 0 0 120px;
}

.content {
  padding: 1rem;
}

.empty-state {
  text-align: center;
  padding: 3rem 1rem;
  background: white;
  border-radius: 0.75rem;
  margin: 1rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.empty-state h3 {
  margin: 0 0 0.5rem 0;
  color: #1e293b;
}

.empty-state p {
  margin: 0;
  color: #64748b;
}

.teams-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(400px, 1fr));
  gap: 1rem;
}

.loading-state,
.error-state {
  text-align: center;
  padding: 3rem 1rem;
  color: #64748b;
}

.error-state {
  color: #dc2626;
  background: #fee2e2;
  margin: 1rem;
  border-radius: 0.5rem;
}

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
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  background: none;
  border: none;
  cursor: pointer;
  color: #64748b;
  font-size: 0.875rem;
  font-weight: 500;
  transition: color 0.2s;
  white-space: nowrap;
}

.footer-btn:hover {
  color: #667eea;
}

.footer-btn.primary {
  background: #667eea;
  color: white;
  border-radius: 0.5rem;
}

.footer-btn.primary:hover {
  background: #5568d3;
}

.footer-spacer {
  height: 20px;
}

@media (max-width: 768px) {
  .teams-grid {
    grid-template-columns: 1fr;
  }
  
  .footer-btn {
    font-size: 0.75rem;
    padding: 0.5rem;
  }
}
</style>
