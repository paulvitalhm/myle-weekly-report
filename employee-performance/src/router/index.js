import { createRouter, createWebHashHistory } from 'vue-router'
import ShareableReport from '../components/ShareableReport.vue'
import AppointmentsByDay from '../components/AppointmentsByDay.vue'
import TeamAssignments from '../components/TeamAssignments.vue'
import SetupAssignments from '../components/SetupAssignments.vue'
import AssignmentManagement from '../components/AssignmentManagement.vue'
import PeriodOverviewCalendar from '../components/PeriodOverviewCalendar.vue'
import AddTimeEntry from '../components/AddTimeEntry.vue'
import DailyPerformanceReport from '../components/DailyPerformanceReport.vue'

const routes = [
  {
    path: '/',
    redirect: '/report/default'
  },
  {
    path: '/report/:periodId',
    name: 'PerformanceReport',
    component: ShareableReport,
    props: true
  },
  {
    path: '/appointments/:periodId',
    name: 'AppointmentsByDay',
    component: AppointmentsByDay,
    props: true
  },
  {
    path: '/assignments/:periodId',
    name: 'TeamAssignments',
    component: TeamAssignments,
    props: true
  },
  {
    path: '/setup/:periodId',
    name: 'SetupAssignments',
    component: SetupAssignments,
    props: true
  },
  {
    path: '/management/:periodId',
    name: 'AssignmentManagement',
    component: AssignmentManagement,
    props: true
  },
  {
    path: '/calendar/:periodId',
    name: 'PeriodOverviewCalendar',
    component: PeriodOverviewCalendar,
    props: true
  },
  {
    path: '/add-time/:periodId',
    name: 'AddTimeEntry',
    component: AddTimeEntry,
    props: true
  },
  {
    path: '/daily-report/:periodId',
    name: 'DailyReport',
    component: DailyPerformanceReport,
    props: true
  }
]

const router = createRouter({
  history: createWebHashHistory(), // Using hash mode for better compatibility
  routes
})

export default router
