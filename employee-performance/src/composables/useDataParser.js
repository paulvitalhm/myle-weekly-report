import { ref } from 'vue'
import * as XLSX from 'xlsx'

export function useDataParser() {
  const employees = ref([])
  const appointments = ref([])
  const isLoading = ref(false)
  const error = ref(null)

  // Parse hours from "Xh Ym" format to total hours
  const parseHours = (hoursStr) => {
    if (!hoursStr) return 0
    const match = hoursStr.match(/(\d+)h\s*(\d+)m/)
    if (match) {
      return parseInt(match[1]) + parseInt(match[2]) / 60
    }
    return 0
  }

  // Parse date from Excel format (normalized to YYYY-MM-DD)
  const parseDate = (dateValue) => {
    if (typeof dateValue === 'number') {
      // Excel date format (days since 1900-01-01)
      // Excel incorrectly treats 1900 as a leap year, so adjust
      const excelEpoch = new Date(1899, 11, 30) // Dec 30, 1899
      const date = new Date(excelEpoch.getTime() + dateValue * 86400000)
      const year = date.getFullYear()
      const month = String(date.getMonth() + 1).padStart(2, '0')
      const day = String(date.getDate()).padStart(2, '0')
      return `${year}-${month}-${day}`
    }
    if (typeof dateValue === 'string') {
      // Handle various string date formats
      const parts = dateValue.match(/(\d{4})-(\d{2})-(\d{2})/)
      if (parts) {
        return `${parts[1]}-${parts[2]}-${parts[3]}`
      }
      // Try parsing as date
      const date = new Date(dateValue)
      if (!isNaN(date.getTime())) {
        const year = date.getFullYear()
        const month = String(date.getMonth() + 1).padStart(2, '0')
        const day = String(date.getDate()).padStart(2, '0')
        return `${year}-${month}-${day}`
      }
    }
    return dateValue
  }

  // Load and parse payroll data
  const loadPayrollData = async () => {
    try {
      const response = await fetch('/payroll.xlsx')
      const arrayBuffer = await response.arrayBuffer()
      const workbook = XLSX.read(arrayBuffer, { type: 'array' })
      
      const employeeData = []
      
      // Skip the summary sheet, process individual employee sheets
      workbook.SheetNames.forEach((sheetName, index) => {
        if (index === 0) return // Skip summary sheet
        
        const sheet = workbook.Sheets[sheetName]
        const data = XLSX.utils.sheet_to_json(sheet, { header: 1 })
        
        // Extract employee name from sheet name (format: "1.Angela Batang")
        const employeeName = sheetName.split('.')[1]?.trim()
        if (!employeeName) return
        
        // Find the data rows (skip headers)
        const workDays = []
        for (let i = 6; i < data.length; i++) {
          const row = data[i]
          if (!row[1]) break // Stop at empty rows
          
          const date = parseDate(row[1])
          const hours = row[4] // "Xh Ym" format
          
          if (date && hours) {
            workDays.push({
              date,
              hours: parseHours(hours),
              hoursDisplay: hours
            })
          }
        }
        
        if (workDays.length > 0) {
          employeeData.push({
            name: employeeName,
            workDays
          })
        }
      })
      
      employees.value = employeeData
      return employeeData
    } catch (err) {
      error.value = `Error loading payroll data: ${err.message}`
      throw err
    }
  }

  // Load and parse appointments data
  const loadAppointmentsData = async () => {
    try {
      const response = await fetch('/appointments.xlsx')
      const arrayBuffer = await response.arrayBuffer()
      const workbook = XLSX.read(arrayBuffer, { type: 'array' })
      
      const sheet = workbook.Sheets[workbook.SheetNames[0]]
      const data = XLSX.utils.sheet_to_json(sheet)
      
      const appointmentsList = data.map(row => ({
        date: parseDate(row['Appointment date']),
        time: row['Appointment time'],
        service: row['Service/class/event'],
        cost: row['Cost'],
        team: row['Team member'],
        customer: row['Customer name'],
        address: row['Address'],
        city: row['City'],
        status: row['Status'],
        bookingId: row['Booking ID']
      })).filter(apt => apt.date && apt.customer)
      
      appointments.value = appointmentsList
      
      // Debug: Log date samples
      console.log('Sample payroll dates:', employees.value[0]?.workDays.slice(0, 3).map(d => d.date))
      console.log('Sample appointment dates:', appointmentsList.slice(0, 3).map(d => d.date))
      console.log('Total appointments loaded:', appointmentsList.length)
      
      return appointmentsList
    } catch (err) {
      error.value = `Error loading appointments data: ${err.message}`
      throw err
    }
  }

  // Load data from uploaded files
  const loadFromFiles = async (payrollFile, appointmentsFile, updateRefs = true) => {
    isLoading.value = true
    error.value = null
    
    try {
      // Load payroll
      const payrollBuffer = await payrollFile.arrayBuffer()
      const payrollWorkbook = XLSX.read(payrollBuffer, { type: 'array' })
      
      const employeeData = []
      payrollWorkbook.SheetNames.forEach((sheetName, index) => {
        if (index === 0) return // Skip summary sheet
        
        const sheet = payrollWorkbook.Sheets[sheetName]
        const data = XLSX.utils.sheet_to_json(sheet, { header: 1 })
        
        const employeeName = sheetName.split('.')[1]?.trim()
        if (!employeeName) return
        
        // Collect all work entries first
        const workEntries = []
        for (let i = 6; i < data.length; i++) {
          const row = data[i]
          if (!row[1]) break
          
          const date = parseDate(row[1])
          const hours = row[4]
          
          if (date && hours) {
            workEntries.push({
              date,
              hours: parseHours(hours)
            })
          }
        }
        
        // Aggregate hours by date (multiple shifts per day)
        const workDayMap = new Map()
        workEntries.forEach(entry => {
          if (workDayMap.has(entry.date)) {
            workDayMap.get(entry.date).hours += entry.hours
          } else {
            workDayMap.set(entry.date, { date: entry.date, hours: entry.hours })
          }
        })
        
        // Convert to array with display format
        const workDays = Array.from(workDayMap.values()).map(day => ({
          date: day.date,
          hours: day.hours,
          hoursDisplay: `${Math.floor(day.hours)}h ${Math.round((day.hours % 1) * 60)}m`
        }))
        
        if (workDays.length > 0) {
          employeeData.push({
            name: employeeName,
            workDays
          })
        }
      })
      
      if (updateRefs) {
        employees.value = employeeData
      }
      
      // Load appointments
      const appointmentsBuffer = await appointmentsFile.arrayBuffer()
      const appointmentsWorkbook = XLSX.read(appointmentsBuffer, { type: 'array' })
      
      const sheet = appointmentsWorkbook.Sheets[appointmentsWorkbook.SheetNames[0]]
      const data = XLSX.utils.sheet_to_json(sheet)
      
      const appointmentsList = data.map(row => ({
        date: parseDate(row['Appointment date']),
        time: row['Appointment time'],
        service: row['Service/class/event'],
        cost: row['Cost'],
        team: row['Team member'],
        customer: row['Customer name'],
        address: row['Address'],
        city: row['City'],
        status: row['Status'],
        bookingId: row['Booking ID']
      })).filter(apt => apt.date && apt.customer)
      
      if (updateRefs) {
        appointments.value = appointmentsList
      }
      
      return { employees: employeeData, appointments: appointmentsList }
    } catch (err) {
      error.value = `Error loading files: ${err.message}`
      throw err
    } finally {
      isLoading.value = false
    }
  }

  // Load all data
  const loadAllData = async () => {
    isLoading.value = true
    error.value = null
    
    try {
      await Promise.all([
        loadPayrollData(),
        loadAppointmentsData()
      ])
    } catch (err) {
      console.error('Error loading data:', err)
    } finally {
      isLoading.value = false
    }
  }

  return {
    employees,
    appointments,
    isLoading,
    error,
    loadAllData,
    loadFromFiles
  }
}
