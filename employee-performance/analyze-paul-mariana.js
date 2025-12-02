import { createClient } from '@supabase/supabase-js';
import { supabase } from './src/config/supabase.js';

async function analyzeData() {
  try {
    console.log('=== ANALYZING PAUL & MARIANA PERFORMANCE DATA ===\n');
    
    const periodId = '91a20127-5cda-4220-a405-791640417f5d';
    
    // Get the specific period details
    const { data: period } = await supabase
      .from('periods')
      .select('id, start_date, end_date')
      .eq('id', periodId)
      .single();
    
    if (!period) {
      console.log('Period not found, checking if period exists...');
      
      // Check all periods
      const { data: allPeriods } = await supabase.from('periods').select('id, start_date, end_date');
      console.log('Available periods:', allPeriods);
      return;
    }
    
    console.log(`Period: ${period.start_date} to ${period.end_date} (ID: ${periodId})\n`);
    
    // Get the performance index data
    console.log('=== PERFORMANCE INDEX DATA ===');
    const { data: performanceData } = await supabase.rpc('get_performance_index', {
      p_period_id: periodId
    });
    
    if (!performanceData || performanceData.length === 0) {
      console.log('No performance index data found');
      return;
    }
    
    console.log('Performance Index Results:');
    performanceData.forEach(row => {
      console.log(`${row.who}: Index ${row.index}, Earned $${row.earned}, Hours ${row.hours_worked}, Date: ${row.work_date}`);
    });
    
    // Focus on Paul and Mariana
    console.log('\n=== PAUL & MARIANA ANALYSIS ===');
    const paulData = performanceData.find(row => row.who.toLowerCase().includes('paul'));
    const marianaData = performanceData.find(row => row.who.toLowerCase().includes('mariana'));
    
    if (paulData) {
      console.log(`Paul: Index ${paulData.index}, Earned $${paulData.earned}, Hours ${paulData.hours_worked}`);
      console.log(`Manual calculation: $${paulData.earned} ÷ ${paulData.hours_worked}h = ${(paulData.earned / paulData.hours_worked).toFixed(2)}`);
    }
    
    if (marianaData) {
      console.log(`Mariana: Index ${marianaData.index}, Earned $${marianaData.earned}, Hours ${marianaData.hours_worked}`);
      console.log(`Manual calculation: $${marianaData.earned} ÷ ${marianaData.hours_worked}h = ${(marianaData.earned / marianaData.hours_worked).toFixed(2)}`);
    }
    
    // Get detailed work day data
    console.log('\n=== WORK DAY DETAILS ===');
    const { data: workDays } = await supabase
      .from('work_days')
      .select(`
        work_date,
        hours_worked,
        employee:employees(name)
      `)
      .eq('employee.period_id', periodId)
      .order('work_date');
    
    const paulWorkDays = workDays?.filter(day => day.employee?.name?.toLowerCase().includes('paul'));
    const marianaWorkDays = workDays?.filter(day => day.employee?.name?.toLowerCase().includes('mariana'));
    
    console.log('Paul Work Days:');
    paulWorkDays?.forEach(day => {
      console.log(`  ${day.work_date}: ${day.hours_worked}h`);
    });
    
    console.log('Mariana Work Days:');
    marianaWorkDays?.forEach(day => {
      console.log(`  ${day.work_date}: ${day.hours_worked}h`);
    });
    
    // Get detailed assignment data
    console.log('\n=== ASSIGNMENT DETAILS ===');
    const { data: assignments } = await supabase
      .from('client_assignments')
      .select(`
        actual_hours,
        transportation_cost,
        work_day:work_days(
          work_date,
          hours_worked,
          employee:employees(name)
        ),
        appointment:appointments(
          customer_name,
          cost,
          appointment_date
        )
      `)
      .eq('work_day.employee.period_id', periodId)
      .order('work_day.work_date');
    
    const paulAssignments = assignments?.filter(assign => assign.work_day.employee?.name?.toLowerCase().includes('paul'));
    const marianaAssignments = assignments?.filter(assign => assign.work_day.employee?.name?.toLowerCase().includes('mariana'));
    
    console.log('Paul Assignments:');
    if (paulAssignments && paulAssignments.length > 0) {
      paulAssignments.forEach(assign => {
        console.log(`  ${assign.work_day.work_date}: ${assign.work_day.employee.name} at ${assign.appointment.customer_name} - $${assign.appointment.cost} - Hours: ${assign.actual_hours} - Transport: $${assign.transportation_cost || 0}`);
      });
    } else {
      console.log('  No assignments found for Paul');
    }
    
    console.log('Mariana Assignments:');
    if (marianaAssignments && marianaAssignments.length > 0) {
      marianaAssignments.forEach(assign => {
        console.log(`  ${assign.work_day.work_date}: ${assign.work_day.employee.name} at ${assign.appointment.customer_name} - $${assign.appointment.cost} - Hours: ${assign.actual_hours} - Transport: $${assign.transportation_cost || 0}`);
      });
    } else {
      console.log('  No assignments found for Mariana');
    }
    
  } catch (error) {
    console.error('Error:', error.message);
  }
}

analyzeData();
