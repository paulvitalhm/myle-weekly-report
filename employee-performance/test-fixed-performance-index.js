import { createClient } from '@supabase/supabase-js';

// Use environment variables or defaults
const supabaseUrl = process.env.VITE_SUPABASE_URL || 'https://your-supabase-url.supabase.co';
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY || 'your-anon-key';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testFixedPerformanceIndex() {
  try {
    console.log('=== TESTING FIXED PERFORMANCE INDEX CALCULATION ===\n');
    
    const periodId = '91a20127-5cda-4220-a405-791640417f5d';
    
    // Test the fixed performance index function
    console.log('=== PERFORMANCE INDEX AFTER FIX ===');
    const { data: performanceData, error } = await supabase.rpc('get_performance_index', {
      p_period_id: periodId
    });
    
    if (error) {
      console.error('Error calling performance index function:', error);
      return;
    }
    
    if (!performanceData || performanceData.length === 0) {
      console.log('No performance index data found');
      return;
    }
    
    console.log('Performance Index Results (After Fix):');
    performanceData.forEach(row => {
      console.log(`${row.who}: Index ${row.index}, Earned $${row.earned}, Hours ${row.hours_worked}, Date: ${row.work_date}`);
    });
    
    // Focus on Paul and Mariana
    console.log('\n=== PAUL & MARIANA AFTER FIX ===');
    const paulData = performanceData.find(row => row.who.toLowerCase().includes('paul') && row.work_date === '2025-11-15');
    const marianaData = performanceData.find(row => row.who.toLowerCase().includes('mariana') && row.work_date === '2025-11-15');
    
    if (paulData) {
      console.log(`Paul: Index ${paulData.index}, Earned $${paulData.earned}, Hours ${paulData.hours_worked}`);
      console.log(`Manual calculation: $${paulData.earned} ÷ ${paulData.hours_worked}h = ${(paulData.earned / paulData.hours_worked).toFixed(2)}`);
    }
    
    if (marianaData) {
      console.log(`Mariana: Index ${marianaData.index}, Earned $${marianaData.earned}, Hours ${marianaData.hours_worked}`);
      console.log(`Manual calculation: $${marianaData.earned} ÷ ${marianaData.hours_worked}h = ${(marianaData.earned / marianaData.hours_worked).toFixed(2)}`);
    }
    
    // Verify they have the same index
    if (paulData && marianaData) {
      const paulIndex = paulData.index;
      const marianaIndex = marianaData.index;
      
      console.log('\n=== VERIFICATION ===');
      console.log(`Paul's Index: ${paulIndex}`);
      console.log(`Mariana's Index: ${marianaIndex}`);
      
      if (Math.abs(paulIndex - marianaIndex) < 0.01) {
        console.log('✅ SUCCESS: Both employees have the same performance index!');
      } else {
        console.log('❌ FAILED: Performance indices are different');
      }
      
      // Calculate expected index based on total revenue and hours
      const totalRevenue = 237.50; // $150 + $87.50
      const totalHours = 6.17; // 5.17 + 1.00
      const expectedIndex = totalRevenue / totalHours;
      
      console.log(`Expected Index (based on formula): ${expectedIndex.toFixed(2)}`);
      console.log(`Paul's Actual Index: ${paulIndex}`);
      console.log(`Mariana's Actual Index: ${marianaIndex}`);
    }
    
  } catch (error) {
    console.error('Error:', error.message);
  }
}

testFixedPerformanceIndex();