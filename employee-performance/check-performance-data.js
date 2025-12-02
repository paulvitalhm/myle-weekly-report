import { createClient } from '@supabase/supabase-js';

// Use environment variables or defaults
const supabaseUrl = process.env.VITE_SUPABASE_URL || 'https://your-supabase-url.supabase.co';
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY || 'your-anon-key';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkData() {
  try {
    console.log('=== CHECKING PERFORMANCE INDEX DATA ===\n');
    
    // Use the specific period ID provided
    const periodId = '91a20127-5cda-4220-a405-791640417f5d';
    
    // Get the specific period details
    const { data: period } = await supabase
      .from('periods')
      .select('id, start_date, end_date')
      .eq('id', periodId)
      .single();
    
    if (!period) {
      console.log('Period not found');
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
    
    console.log('\n=== DETAILED BREAKDOWN ===');
    
    // Check specific data for Paul and Mariana if they exist
    const paulData = performanceData.find(row => row.who.toLowerCase().includes('paul'));
    const marianaData = performanceData.find(row => row.who.toLowerCase().includes('mariana'));
    
    if (paulData) {
      console.log(`\\nPaul's Data:`);
      console.log(`  Index: ${paulData.index}`);
      console.log(`  Earned: $${paulData.earned}`);
      console.log(`  Hours: ${paulData.hours_worked}`);
      console.log(`  Date: ${paulData.work_date}`);
    }
    
    if (marianaData) {
      console.log(`\\nMariana's Data:`);
      console.log(`  Index: ${marianaData.index}`);
      console.log(`  Earned: $${marianaData.earned}`);
      console.log(`  Hours: ${marianaData.hours_worked}`);
      console.log(`  Date: ${marianaData.work_date}`);
    }
    
    // Get detailed assignment data to understand the calculations
    console.log('\\n=== ASSIGNMENT DETAILS ===');
    const { data: assignments } = await supabase
      .from('client_assignments')
      .select(`
        id,
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
    
    if (assignments && assignments.length > 0) {
      console.log('Assignment Details:');
      assignments.forEach(assign => {
        const employee = assign.work_day.employee.name;
        const date = assign.work_day.work_date;
        const customer = assign.appointment.customer_name;
        const cost = assign.appointment.cost;
        const hours = assign.actual_hours;
        const transport = assign.transportation_cost || 0;
        
        console.log(`  ${date}: ${employee} at ${customer} - $${cost} - Hours: ${hours} - Transport: $${transport}`);
      });
    }
    
  } catch (error) {
    console.error('Error:', error.message);
    console.error('Stack:', error.stack);
  }
}

checkData();
