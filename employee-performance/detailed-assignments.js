import { createClient } from '@supabase/supabase-js';
import { supabase } from './src/config/supabase.js';

async function getDetailedAssignments() {
  try {
    console.log('=== DETAILED ASSIGNMENT ANALYSIS ===\n');
    
    const periodId = '91a20127-5cda-4220-a405-791640417f5d';
    
    // Get detailed assignment data with all relationships
    const { data: assignments } = await supabase
      .from('client_assignments')
      .select(`
        id,
        actual_hours,
        transportation_cost,
        work_day:work_days(
          id,
          work_date,
          hours_worked,
          employee:employees(name)
        ),
        appointment:appointments(
          id,
          customer_name,
          cost,
          appointment_date,
          appointment_time
        )
      `)
      .eq('work_day.employee.period_id', periodId)
      .order('work_day.work_date');
    
    console.log('All Assignments:');
    assignments?.forEach(assign => {
      const employee = assign.work_day.employee.name;
      const date = assign.work_day.work_date;
      const customer = assign.appointment.customer_name;
      const cost = assign.appointment.cost;
      const hours = assign.actual_hours;
      const transport = assign.transportation_cost || 0;
      const workDayHours = assign.work_day.hours_worked;
      
      console.log(`  ${date}: ${employee} at ${customer} - $${cost} - Hours: ${hours} - Transport: $${transport} - WorkDay: ${workDayHours}h`);
    });
    
    // Focus on Paul and Mariana specifically
    console.log('\n=== PAUL & MARIANA ASSIGNMENTS ===');
    const paulMarianaAssignments = assignments?.filter(assign => 
      assign.work_day.employee.name.toLowerCase().includes('paul') || 
      assign.work_day.employee.name.toLowerCase().includes('mariana')
    );
    
    if (paulMarianaAssignments && paulMarianaAssignments.length > 0) {
      paulMarianaAssignments.forEach(assign => {
        const employee = assign.work_day.employee.name;
        const date = assign.work_day.work_date;
        const customer = assign.appointment.customer_name;
        const cost = assign.appointment.cost;
        const hours = assign.actual_hours;
        const transport = assign.transportation_cost || 0;
        const workDayHours = assign.work_day.hours_worked;
        
        console.log(`  ${date}: ${employee} at ${customer} - $${cost} - Hours: ${hours} - Transport: $${transport} - WorkDay: ${workDayHours}h`);
      });
    } else {
      console.log('  No assignments found for Paul or Mariana');
    }
    
  } catch (error) {
    console.error('Error:', error.message);
  }
}

getDetailedAssignments();
