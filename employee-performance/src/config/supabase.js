import { createClient } from '@supabase/supabase-js'

// INSTRUCTIONS: Update these values with your actual Supabase credentials
// You can find these in your Supabase project settings:
// 1. Go to https://supabase.com/dashboard
// 2. Select your project
// 3. Go to Settings > API
// 4. Copy the Project URL and anon/public key

const supabaseUrl = 'https://qeyukktbtolkpnpmcoym.supabase.co' // e.g., 'https://xxxxxxxxxxxxx.supabase.co'
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFleXVra3RidG9sa3BucG1jb3ltIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI2OTY5NzIsImV4cCI6MjA3ODI3Mjk3Mn0.2nYizGqkYQgxJFXpjLzA_alpBwBGjLAhy5L9djoiAvc' // Your public anon key

// Create the Supabase client
export const supabase = createClient(supabaseUrl, supabaseKey)

// Helper function to check if Supabase is configured
export function isSupabaseConfigured() {
  return supabaseUrl !== 'YOUR_SUPABASE_URL_HERE' && 
         supabaseKey !== 'YOUR_SUPABASE_ANON_KEY_HERE'
}
