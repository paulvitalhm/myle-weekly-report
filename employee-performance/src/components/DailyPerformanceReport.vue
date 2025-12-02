<template>
  <div class="daily-performance-report">
    <div class="header">
      <h1>Daily Performance Report</h1>
      <p class="subtitle">Team performance metrics by day</p>
      
      <!-- Controls -->
      <div class="controls">
        <label class="price-toggle">
          <input type="checkbox" v-model="showPrices" />
          <span class="toggle-label">Show Prices</span>
        </label>
      </div>
    </div>

    <div class="loading" v-if="loading">
      <p>Loading daily performance data...</p>
    </div>

    <div class="error" v-if="error">
      <p class="error-message">{{ error }}</p>
    </div>

    <div class="performance-list" v-if="!loading && dailyPerformance.length > 0">
      <div class="performance-card"
           v-for="day in dailyPerformance"
           :key="day.day_date"
           :class="getTierClass(day.performance_tier)">
        
        <div class="card-header">
          <div class="date-info">
            <div class="date">{{ formatDisplayDate(day.day_date) }}</div>
            <div class="rank">#{{ day.rank }}</div>
          </div>
          <div class="tier-badge" :class="day.performance_tier">
            {{ formatTierName(day.performance_tier) }}
          </div>
        </div>

        <div class="card-content">
          <div class="metrics-grid">
            <div class="metric">
              <div class="metric-value">{{ day.index }}</div>
              <div class="metric-label">Performance Index</div>
            </div>
            
            <div class="metric">
              <div class="metric-value" v-if="showPrices">${{ day.total_earned }}</div>
              <div class="metric-value" v-else>---</div>
              <div class="metric-label">Total Earned</div>
            </div>
            
            <div class="metric">
              <div class="metric-value">{{ day.total_hours }}h</div>
              <div class="metric-label">Total Hours</div>
            </div>
            
            <div class="metric">
              <div class="metric-value">{{ day.worker_count }}</div>
              <div class="metric-label">Workers</div>
            </div>
          </div>

          <!-- Worker Details -->
          <div class="worker-details" v-if="day.worker_details && day.worker_details.length > 0">
            <div class="section-label">Workers & Hours:</div>
            <div class="workers-list">
              <div v-for="worker in day.worker_details" :key="worker.employee_name" class="worker-item">
                <span class="worker-name">{{ worker.employee_name }}</span>
                <span class="worker-hours">{{ worker.hours_worked }}h</span>
              </div>
            </div>
          </div>

          <!-- Appointment Details -->
          <div class="appointment-details" v-if="day.appointment_details && day.appointment_details.length > 0">
            <div class="section-label">Appointments:</div>
            <div class="appointments-list">
              <div v-for="appointment in day.appointment_details" :key="appointment.customer_name" class="appointment-item">
                <span class="appointment-name">{{ appointment.customer_name }}</span>
                <span class="appointment-cost" v-if="showPrices">${{ appointment.cost }}</span>
                <span class="appointment-cost" v-else>---</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="empty-state" v-if="!loading && dailyPerformance.length === 0">
      <p>No daily performance data available for the selected period.</p>
    </div>

    <div class="tier-legend">
      <h3>Performance Tiers</h3>
      <div class="legend-items">
        <div class="legend-item top">
          <span class="legend-color"></span>
          <span class="legend-text">Top Performers (≥ 47)</span>
        </div>
        <div class="legend-item good">
          <span class="legend-color"></span>
          <span class="legend-text">Good Performers (35-46)</span>
        </div>
        <div class="legend-item needs-improvement">
          <span class="legend-color"></span>
          <span class="legend-text">Needs Improvement (< 35)</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { supabase } from '../config/supabase.js'

export default {
  name: 'DailyPerformanceReport',
  props: {
    periodId: {
      type: String,
      required: true
    }
  },
  data() {
    return {
      dailyPerformance: [],
      loading: false,
      error: null,
      showPrices: true
    }
  },
  async mounted() {
    await this.loadDailyPerformance()
  },
  watch: {
    periodId: {
      immediate: true,
      handler: 'loadDailyPerformance'
    }
  },
  methods: {
    async loadDailyPerformance() {
      if (!this.periodId) return

      this.loading = true
      this.error = null

      try {
        const { data, error } = await supabase.rpc('get_daily_performance_index', {
          p_period_id: this.periodId
        })

        if (error) throw error

        // Process the data to handle JSONB fields
        this.dailyPerformance = (data || []).map(day => ({
          ...day,
          worker_details: day.worker_details || [],
          appointment_details: day.appointment_details || []
        }))
      } catch (error) {
        console.error('Error loading daily performance:', error)
        this.error = 'Failed to load daily performance data'
      } finally {
        this.loading = false
      }
    },

    formatDisplayDate(dateString) {
      return new Date(dateString).toLocaleDateString('en-US', {
        weekday: 'short',
        month: 'short',
        day: 'numeric',
        year: 'numeric'
      })
    },

    getTierClass(tier) {
      return `tier-${tier}`
    },

    formatTierName(tier) {
      const tierNames = {
        'top': 'Top Performer',
        'good': 'Good Performer',
        'needs-improvement': 'Needs Improvement'
      }
      return tierNames[tier] || tier
    }
  }
}
</script>

<style scoped>
.daily-performance-report {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}

.header {
  text-align: center;
  margin-bottom: 30px;
}

.header h1 {
  color: #333;
  margin-bottom: 8px;
}

.subtitle {
  color: #666;
  font-size: 1.1em;
  margin-bottom: 16px;
}

.controls {
  margin-bottom: 20px;
  display: flex;
  justify-content: center;
}

.price-toggle {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 16px;
  background: #f8f9fa;
  border-radius: 6px;
  cursor: pointer;
  transition: background-color 0.2s;
}

.price-toggle:hover {
  background: #e9ecef;
}

.price-toggle input[type="checkbox"] {
  margin: 0;
}

.toggle-label {
  font-weight: 500;
  color: #495057;
}

.loading, .error {
  text-align: center;
  padding: 40px;
}

.error-message {
  color: #d32f2f;
  font-weight: 500;
}

.performance-list {
  display: grid;
  gap: 20px;
  margin-bottom: 40px;
}

.performance-card {
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  padding: 20px;
  background: white;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
  padding-bottom: 12px;
  border-bottom: 1px solid #f0f0f0;
}

.date-info {
  display: flex;
  align-items: center;
  gap: 12px;
}

.date {
  font-size: 1.1em;
  font-weight: 500;
  color: #333;
}

.rank {
  font-size: 0.9em;
  font-weight: bold;
  color: #666;
  background: #f8f9fa;
  padding: 4px 8px;
  border-radius: 4px;
}

.tier-badge {
  padding: 4px 12px;
  border-radius: 20px;
  font-size: 0.9em;
  font-weight: 500;
  text-transform: uppercase;
}

.tier-badge.top {
  background: #4caf50;
  color: white;
}

.tier-badge.good {
  background: #ff9800;
  color: white;
}

.tier-badge.needs-improvement {
  background: #f44336;
  color: white;
}

.metrics-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 20px;
  margin-bottom: 16px;
}

.metric {
  text-align: center;
}

.metric-value {
  font-size: 1.5em;
  font-weight: bold;
  color: #333;
  margin-bottom: 4px;
}

.metric-label {
  font-size: 0.9em;
  color: #666;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

/* Worker Details */
.worker-details {
  margin-top: 16px;
  padding-top: 16px;
  border-top: 1px solid #f0f0f0;
}

.section-label {
  font-weight: 500;
  color: #666;
  margin-bottom: 8px;
  font-size: 0.9em;
}

.workers-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.worker-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 6px 8px;
  background: #f8f9fa;
  border-radius: 4px;
}

.worker-name {
  font-weight: 500;
  color: #333;
}

.worker-hours {
  color: #666;
  font-size: 0.9em;
}

/* Appointment Details */
.appointment-details {
  margin-top: 16px;
  padding-top: 16px;
  border-top: 1px solid #f0f0f0;
}

.appointments-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.appointment-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 6px 8px;
  background: #f8f9fa;
  border-radius: 4px;
}

.appointment-name {
  font-weight: 500;
  color: #333;
}

.appointment-cost {
  color: #28a745;
  font-weight: 600;
  font-size: 0.9em;
}

/* Tier styling for cards */
.tier-top {
  border-left: 4px solid #4caf50;
}

.tier-good {
  border-left: 4px solid #ff9800;
}

.tier-needs-improvement {
  border-left: 4px solid #f44336;
}

.tier-legend {
  background: #f8f9fa;
  padding: 20px;
  border-radius: 8px;
  border: 1px solid #e0e0e0;
}

.tier-legend h3 {
  margin-bottom: 16px;
  color: #333;
}

.legend-items {
  display: flex;
  gap: 20px;
  flex-wrap: wrap;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 8px;
}

.legend-color {
  width: 16px;
  height: 16px;
  border-radius: 4px;
}

.legend-item.top .legend-color {
  background: #4caf50;
}

.legend-item.good .legend-color {
  background: #ff9800;
}

.legend-item.needs-improvement .legend-color {
  background: #f44336;
}

.legend-text {
  color: #666;
  font-size: 0.9em;
}

.empty-state {
  text-align: center;
  padding: 60px 20px;
  color: #666;
}

@media (max-width: 768px) {
  .daily-performance-report {
    padding: 10px;
  }
  
  .metrics-grid {
    grid-template-columns: repeat(2, 1fr);
  }
  
  .legend-items {
    flex-direction: column;
    gap: 12px;
  }
  
  .card-header {
    flex-direction: column;
    gap: 8px;
    text-align: center;
  }
  
  .date-info {
    flex-direction: column;
    gap: 4px;
  }
  
  .worker-item, .appointment-item {
    flex-direction: column;
    align-items: flex-start;
    gap: 2px;
  }
}
</style>