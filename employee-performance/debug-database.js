import { supabase } from './src/config/supabase.js';

async function debugPerformanceIndex() {
  try {
    console.log('=== DEBUGGING PERFORMANCE INDEX CALCULATION ===\n');
    
    const periodId = '91a20127-5cda-4220-a405-791640417f5d';
    
    // Check what's in the database
    console.log('1. CHECKING DATABASE CONTENTS:');
    
    // Check periods
    const { data: periods } = await supabase.from('periods').select('*');
    console.log('Periods count:', periods?.length);
    
    // Check employees
    const { data: employees } = await supabase.from('employees').select('*').eq('period_id', periodId);
    console.log('Employees count:', employees?.length);
    
    // Check work days
    const { data: workDays } = await supabase.from('work_days').select('*').eq('employee.period_id', periodId);
    console.log('Work days count:', workDays?.length);
    
    // Check appointments
    const { data: appointments } = await supabase.from('appointments').select('*').eq('period_id', periodId);
    console.log('Appointments count:', appointments?.length);
    
    // Check client assignments
    const { data: assignments } = await supabase.from('client_assignments').select('*');
    console.log('Client assignments count:', assignments?.length);
    
    // Get sample of Paul and Mariana work days
    const { data: paulMarianaWorkDays } = await supabase
      .from('work_days')
      .select(`
        id,
        work_date,
        hours_worked,
        employee:employees(name)
      `)
      .eq('employee.period_id', periodId)
      .or('name.ilike.%paul%,name.ilike.%mariana%');
    
    console.log('\n2. PAUL & MARIANA WORK DAYS:');
    paulMarianaWorkDays?.forEach(day => {
      console.log(`  ${day.work_date}: ${day.employee.name} - ${day.hours_worked}h (ID: ${day.id})`);
    });
    
    // Check if there are any assignments for these work days
    if (paulMarianaWorkDays && paulMarianaWorkDays.length > 0) {
      const workDayIds = paulMarianaWorkDays.map(day => day.id);
      
      const { data: relatedAssignments } = await supabase
        .from('client_assignments')
        .select('*')
        .in('work_day_id', workDayIds);
      
      console.log('\n3. ASSIGNMENTS FOR PAUL & MARIANA WORK DAYS:');
      console.log('Assignments count:', relatedAssignments?.length);
      relatedAssignments?.forEach(assign => {
        console.log(`  WorkDay ${assign.work_day_id}: Hours ${assign.actual_hours}, Transport $${assign.transportation_cost || 0}`);
      });
    }
    
  } catch (error) {
    console.error('Error:', error.message);
  }
}

debugPerformanceIndex();
