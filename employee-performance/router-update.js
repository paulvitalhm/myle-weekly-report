// Router configuration update for Daily Performance Report
// Add this to your existing router configuration

import DailyPerformanceReport from './src/components/DailyPerformanceReport.vue'

// Add this route to your existing routes array
const dailyReportRoute = {
  path: '/daily-report',
  name: 'DailyReport',
  component: DailyPerformanceReport
}

// Example of how to add it to your existing routes:
const routes = [
  // ... your existing routes ...
  {
    path: '/',
    name: 'Home',
    component: Home
  },
  {
    path: '/report',
    name: 'Report',
    component: PerformanceReport
  },
  // Add the daily report route here
  dailyReportRoute,
  // ... other routes ...
]

// If you're using Vue Router 4, your router/index.js might look like:
import { createRouter, createWebHashHistory } from 'vue-router'
import Home from '../components/Home.vue'
import PerformanceReport from '../components/PerformanceReport.vue'
import DailyPerformanceReport from '../components/DailyPerformanceReport.vue'

const routes = [
  {
    path: '/',
    name: 'Home',
    component: Home
  },
  {
    path: '/report',
    name: 'Report',
    component: PerformanceReport
  },
  {
    path: '/daily-report',
    name: 'DailyReport',
    component: DailyPerformanceReport
  }
]

const router = createRouter({
  history: createWebHashHistory(),
  routes
})

export default router

// Also add a navigation link to your navigation component
// In NavigationBar.vue, add:
/*
<router-link to="/daily-report" class="nav-link">
  Daily Performance
</router-link>
*/