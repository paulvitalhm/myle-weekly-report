import streamlit as st
import pandas as pd
from supabase import create_client, Client
import datetime
import plotly.express as px
from typing import List, Dict

# --- CONFIGURATION ---
SUPABASE_URL = "https://qeyukktbtolkpnpmcoym.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFleXVra3RidG9sa3BucG1jb3ltIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI2OTY5NzIsImV4cCI6MjA3ODI3Mjk3Mn0.2nYizGqkYQgxJFXpjLzA_alpBwBGjLAhy5L9djoiAvc"

# Predefined Tags
PREDEFINED_TAGS = [
    "Angela", "Mariana", "Nanette", "Business", 
    "Individual", "Commercial", "Airbnb", "VIP", "New"
]

# Admin Check (Simple URL parameter: ?view=admin)
is_admin = st.query_params.get("view") == "admin"

# Initialize Supabase
@st.cache_resource
def get_supabase() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_KEY)

supabase = get_supabase()

st.set_page_config(page_title="Client Performance Dashboard", layout="wide")

# --- CSS FOR STYLING ---
st.markdown("""
    <style>
    .main {
        background-color: #f8f9fa;
    }
    .stMetric {
        background-color: white;
        padding: 15px;
        border-radius: 10px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.05);
    }
    .stDataFrame {
        border-radius: 10px;
    }
    </style>
""", unsafe_allow_html=True)

st.title("🚀 Client Performance Dashboard")
st.markdown("Rank clients by value, assign tags, and track monthly spend.")

# --- HELPERS ---
def fetch_all_from_supabase(table_name: str):
    """Fetch all rows from a table, bypasses the 1000 row limit."""
    all_data = []
    page_size = 1000
    current_page = 0
    
    while True:
        start = current_page * page_size
        end = start + page_size - 1
        res = supabase.table(table_name).select("*").range(start, end).execute()
        if not res.data:
            break
        all_data.extend(res.data)
        if len(res.data) < page_size:
            break
        current_page += 1
    return all_data

def fetch_client_data():
    """Fetch tags and mappings from Supabase."""
    try:
        # Fetch master clients
        res_masters_data = fetch_all_from_supabase("master_clients")
        masters = {m['id']: m for m in res_masters_data}
        
        # Fetch links
        res_links_data = fetch_all_from_supabase("client_links")
        links = {l['identifier']: l['master_client_id'] for l in res_links_data}
        
        return masters, links
    except Exception as e:
        st.error(f"Error fetching from Supabase: {e}")
        return {}, {}

def fetch_appointments(start_date=None, end_date=None):
    """Fetch all appointments from Supabase."""
    try:
        # If we have dates, pagination is trickier with filters in query.
        # But for this dashboard, we usually need the full set to calculate min/max dates for filters.
        # Let's fetch the full dataset from 'dashboard_appointments'
        data = fetch_all_from_supabase("dashboard_appointments")
        if not data:
            return pd.DataFrame()
            
        df = pd.DataFrame(data)
        # Force conversion to naive datetime to prevent object dtype conflicts when merging with Excel
        df['appointment_date'] = pd.to_datetime(df['appointment_date']).dt.tz_localize(None)
        
        # Apply filters in Python for simplicity since we fetched all
        if start_date:
            df = df[df['appointment_date'].dt.date >= start_date]
        if end_date:
            df = df[df['appointment_date'].dt.date <= end_date]
            
        return df
    except Exception as e:
        st.error(f"Error fetching appointments: {e}")
        return pd.DataFrame()

def upsert_appointments(df: pd.DataFrame):
    """Upsert appointment data using Booking ID."""
    try:
        # Step 1: Aggregate line items by Booking ID to get full cost per visit
        # and ensure one row per unique booking for the database PK.
        id_col = 'Booking ID'
        df_agg = df.groupby(id_col).agg({
            'Appointment date': 'first',
            'Cost': 'sum',
            'Customer name': 'first',
            'Email': 'first',
            'Phone': 'first',
            'Service/class/event': 'first',
            'Team member': 'first',
            'identifier': 'first'
        }).reset_index()
        
        # Map DataFrame columns to DB columns
        records = []
        for _, row in df_agg.iterrows():
            records.append({
                "booking_id": str(row[id_col]),
                "appointment_date": row['Appointment date'].isoformat() if hasattr(row['Appointment date'], 'isoformat') else str(row['Appointment date']),
                "cost": float(row['Cost']),
                "customer_name": str(row['Customer name']),
                "email": str(row.get('Email', '') or ''),
                "phone": str(row.get('Phone', '') or ''),
                "service_type": str(row.get('Service/class/event', '') or ''),
                "team_member": str(row.get('Team member', '') or ''),
                "identifier": str(row['identifier'])
            })
            
        # Supabase upsert works by passing a list of dicts. 
        # Chunk the upload to be safe with large files
        chunk_size = 500
        for i in range(0, len(records), chunk_size):
            chunk = records[i:i + chunk_size]
            supabase.table("dashboard_appointments").upsert(chunk, on_conflict="booking_id").execute()
        return True
    except Exception as e:
        st.error(f"Error upserting data: {e}")
        return False

def save_tag(master_id: str, tags: List[str]):
    """Update tags for a master client."""
    try:
        supabase.table("master_clients").update({"tags": tags}).eq("id", master_id).execute()
    except Exception as e:
        st.error(f"Error saving tags: {e}")

def create_master_and_link(name: str, identifier: str):
    """Create a new master client and link an identifier to it."""
    try:
        # Create master
        res_master = supabase.table("master_clients").insert({"name": name, "tags": []}).execute()
        if res_master.data:
            master_id = res_master.data[0]['id']
            # Create link
            supabase.table("client_links").insert({"identifier": identifier, "master_client_id": master_id}).execute()
            return master_id
    except Exception as e:
        st.error(f"Error creating client record: {e}")
    return None

def process_data(df, masters, links):
    """Process appointment data and merge with Supabase info."""
    if df.empty:
        return df
        
    df = df.copy()
    
    # Identify unique identifiers if not already present
    if 'identifier' not in df.columns:
        # Robust column finding (case-insensitive, strips spaces)
        cols_map = {c.lower().strip(): c for c in df.columns}
        
        email_col = cols_map.get('email', 'Email')
        phone_col = cols_map.get('phone', 'Phone')
        name_col = cols_map.get('customer name', cols_map.get('customer_name', 'Customer name'))
        
        # Ensure fallback columns exist in DF to avoid KeyError
        for col in [email_col, phone_col, name_col]:
            if col not in df.columns:
                df[col] = "" # Create empty if missing
        
        df['identifier'] = df[email_col].fillna(df[phone_col]).fillna(df[name_col]).astype(str)
        # Clean up empty strings to NaN for fillna to work properly
        df['identifier'] = df['identifier'].replace('', pd.NA).fillna(df[phone_col]).fillna(df[name_col]).astype(str)
    
    # Resolve Master IDs
    master_ids = []
    for ident in df['identifier']:
        if ident in links:
            master_ids.append(links[ident])
        else:
            master_ids.append(None)
    
    df['master_client_id'] = master_ids
    return df

# --- DATA LOADING ---
masters, links = fetch_client_data()
df_db = fetch_appointments()

# Standardize DB columns to Excel-like names for consistency in the logic
if not df_db.empty:
    df_db = df_db.rename(columns={
        'customer_name': 'Customer name',
        'cost': 'Cost',
        'appointment_date': 'Appointment date',
        'email': 'Email',
        'phone': 'Phone',
        'service_type': 'Service/class/event',
        'team_member': 'Team member',
        'booking_id': 'Booking ID'
    })

# --- SIDEBAR ---
df_display = df_db.copy()

with st.sidebar:
    if is_admin:
        st.header("Admin Controls")
        uploaded_file = st.file_uploader("Upload Appointments Excel", type=["xlsx"])
        if uploaded_file:
            try:
                df_new = pd.read_excel(uploaded_file)
                # Standardize Excel
                df_new.columns = [c.strip() for c in df_new.columns] # Strip spaces
                df_new['Appointment date'] = pd.to_datetime(df_new['Appointment date'], errors='coerce').dt.tz_localize(None)
                df_new = df_new.dropna(subset=['Appointment date'])
                df_new['Cost'] = pd.to_numeric(df_new['Cost'], errors='coerce').fillna(0)
                
                # Identify identifier for aggregation
                cols_map = {c.lower(): c for c in df_new.columns}
                e_col = cols_map.get('email', 'Email')
                p_col = cols_map.get('phone', 'Phone')
                n_col = cols_map.get('customer name', 'Customer name')
                for c in [e_col, p_col, n_col]:
                    if c not in df_new.columns: df_new[c] = ""
                df_new['identifier'] = df_new[e_col].fillna(df_new[p_col]).fillna(df_new[n_col]).astype(str)

                # AGGREGATE PREVIEW: Group by Booking ID to avoid duplicate row counting/revenue loss
                df_new_agg = df_new.groupby('Booking ID').agg({
                    'Appointment date': 'first',
                    'Cost': 'sum',
                    'Customer name': 'first',
                    'identifier': 'first',
                    'Email': 'first',
                    'Phone': 'first',
                    'Service/class/event': 'first',
                    'Team member': 'first'
                }).reset_index()
                
                # PREVIEW LOGIC
                if not df_db.empty and 'Booking ID' in df_db.columns:
                    # Merge and keep latest version from file for existing IDs
                    df_display = pd.concat([df_db, df_new_agg]).drop_duplicates(subset='Booking ID', keep='last')
                else:
                    df_display = df_new_agg
                
                st.warning("👀 PREVIEW MODE: You are looking at the file data. Click 'Publish' to save it.")
                
                if st.button("🚀 Publish (Save to Database)"):
                    with st.spinner("Saving..."):
                        if upsert_appointments(df_new):
                            st.success("Data published!")
                            st.rerun()
            except Exception as e:
                st.error(f"Error reading file: {e}")
        
        st.divider()
        if st.checkbox("View as Employee"):
            st.query_params["view"] = ""
            st.rerun()
    else:
        st.info("Employee View (Read-Only)")
        if st.button("Switch to Admin"):
            st.query_params["view"] = "admin"
            st.rerun()

    st.header("Filters")
    if not df_display.empty:
        min_date_val = df_display['Appointment date'].min().date()
        max_date_val = df_display['Appointment date'].max().date()
        
        date_range = st.date_input(
            "Select Date Range",
            value=(min_date_val, max_date_val),
            min_value=min_date_val,
            max_value=max_date_val
        )
    else:
        date_range = []

if not df_display.empty and len(date_range) == 2:
    start_date, end_date = date_range
    st.markdown(f"### 📅 Reporting Period: **{start_date}** to **{end_date}**")
    
    # Filter data
    df = df_display[(df_display['Appointment date'].dt.date >= start_date) & (df_display['Appointment date'].dt.date <= end_date)]
    # st.write("DEBUB COLUMNS:", df.columns.tolist()) # Temporary debug
    df = process_data(df, masters, links)
    
    if not df.empty:
        # --- AGGREGATION ---
        df['effective_master_id'] = df['master_client_id'].fillna(df['identifier'])
        
        client_stats = df.groupby('effective_master_id').agg({
            'Cost': 'sum',
            'identifier': 'count',
            'Customer name': 'first'
        }).rename(columns={'Cost': 'Total Spent', 'identifier': '# of Visits', 'Customer name': 'Client Name'})
        
        client_stats['Avg Spent'] = client_stats['Total Spent'] / client_stats['# of Visits']
        
        # Monthly Pivot
        df['Month'] = df['Appointment date'].dt.strftime('%Y-%m')
        monthly_pivot = df.pivot_table(
            index='effective_master_id', 
            columns='Month', 
            values='Cost', 
            aggfunc='sum'
        ).fillna(0)
        
        # Combine
        final_df = client_stats.join(monthly_pivot)
        
        # Add Tags
        def get_tags(mid):
            if mid in masters:
                return masters[mid].get('tags', [])
            return []
        final_df['Tags'] = [get_tags(mid) for mid in final_df.index]
        
        # --- RENDER KPI ---
        col1, col2, col3, col4 = st.columns(4)
        # Final safety check for column names
        cost_col = 'Cost' if 'Cost' in df.columns else ('cost' if 'cost' in df.columns else 'Cost')
        col1.metric("Total Revenue", f"${df[cost_col].sum():,.2f}")
        col2.metric("Total Visits", f"{len(df)}")
        col3.metric("Unique Clients", f"{final_df.index.nunique()}")
        col4.metric("Avg Ticket", f"${df[cost_col].mean():,.2f}")
        
        st.divider()
        
        # --- RENDER TABLE ---
        st.subheader("Client Ranking & Tagging")
        if is_admin:
            st.info("💡 You can edit clinical tags directly in the table. Click 'Save All Changes' below.")
        
        # Ordering columns based on User Screenshot
        # 1. Client Name, 2. Tags, 3. Total Spent, 4. Avg Spent, 5. # of Visits, then months
        ordered_cols = ['Client Name', 'Tags', 'Total Spent', 'Avg Spent', '# of Visits']
        month_cols = sorted(monthly_pivot.columns.tolist())
        final_df = final_df[ordered_cols + month_cols]
        final_df = final_df.sort_values(by='Total Spent', ascending=False)
        
        # Add Total Row
        total_row = pd.Series(index=final_df.columns)
        total_row['Client Name'] = "GRAND TOTAL"
        total_row['Total Spent'] = final_df['Total Spent'].sum()
        total_row['# of Visits'] = final_df['# of Visits'].sum()
        total_row['Avg Spent'] = final_df['Total Spent'].sum() / final_df['# of Visits'].sum()
        for mc in month_cols:
            total_row[mc] = final_df[mc].sum()
        
        # Display table
        column_config = {
            "Total Spent": st.column_config.NumberColumn(format="$%.2f"),
            "Avg Spent": st.column_config.NumberColumn(format="$%.2f"),
            "Client Name": st.column_config.TextColumn("Client Name", width="medium"),
            "Tags": st.column_config.MultiselectColumn("Tags", options=PREDEFINED_TAGS) if is_admin else st.column_config.ListColumn("Tags"),
        }
        for col in month_cols:
            column_config[col] = st.column_config.NumberColumn(label=col, format="$%.2f")
            
        # UI: Static table for summary row at top or bottom? Streamlit data_editor doesn't support fixed summary rows easily.
        # We will show the Grand Total in a separate small table for clarity
        st.write("**Summary Row**")
        st.dataframe(pd.DataFrame([total_row]), width="stretch", hide_index=True, column_config=column_config)
        
        edited_df = st.data_editor(
            final_df,
            column_config=column_config,
            width="stretch",
            num_rows="fixed",
            disabled=["Client Name", "Total Spent", "Avg Spent", "# of Visits"] + month_cols if not is_admin else [c for c in final_df.columns if c != "Tags"]
        )
        
        if is_admin and st.button("Save All Changes"):
            any_change = False
            for mid, row in edited_df.iterrows():
                if not (row['Tags'] == final_df.loc[mid, 'Tags']):
                    any_change = True
                    actual_mid = mid
                    if mid not in masters:
                        actual_mid = create_master_and_link(row['Client Name'], mid)
                    if actual_mid:
                        save_tag(actual_mid, row['Tags'])
            if any_change:
                st.success("✅ Changes saved!")
                st.rerun()

        st.divider()
        
        # Identity Merging Tool
        with st.expander("🔗 Link Multiple Identities (Merge Clients)"):
            st.write("Use this tool to group multiple addresses or names under a single client.")
            
            col_m1, col_m2 = st.columns(2)
            
            # List identifiers currently in the data
            all_idents = df['identifier'].unique().tolist()
            
            with col_m1:
                target_client = st.selectbox("Select Master Client", options=list(masters.keys()), format_func=lambda x: masters[x]['name'])
            
            with col_m2:
                ident_to_link = st.selectbox("Identifier to Link", options=[i for i in all_idents if i not in links])
            
            if st.button("Link Identifier"):
                try:
                    supabase.table("client_links").insert({
                        "identifier": ident_to_link,
                        "master_client_id": target_client
                    }).execute()
                    st.success(f"Linked {ident_to_link} to {masters[target_client]['name']}!")
                    st.rerun()
                except Exception as e:
                    st.error(f"Error linking: {e}")

if is_admin:
    st.divider()
    with st.expander("🛠️ Admin: Supabase SQL Setup Instructions"):
        st.write("If you haven't setup your database yet, please run this SQL in your Supabase SQL Editor:")
        st.code("""
-- 1. Master Clients
CREATE TABLE IF NOT EXISTS master_clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT,
    tags TEXT[] DEFAULT '{}',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Client Links
CREATE TABLE IF NOT EXISTS client_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    identifier TEXT UNIQUE,
    master_client_id UUID REFERENCES master_clients(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Dashboard Appointments (Renamed to avoid conflict)
CREATE TABLE IF NOT EXISTS dashboard_appointments (
    booking_id TEXT PRIMARY KEY,
    appointment_date TIMESTAMP WITH TIME ZONE,
    cost NUMERIC,
    customer_name TEXT,
    email TEXT,
    phone TEXT,
    service_type TEXT,
    team_member TEXT,
    identifier TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Access Policies
ALTER TABLE master_clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE dashboard_appointments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow All Access" ON master_clients;
CREATE POLICY "Allow All Access" ON master_clients FOR ALL USING (true);

DROP POLICY IF EXISTS "Allow All Access" ON client_links;
CREATE POLICY "Allow All Access" ON client_links FOR ALL USING (true);

DROP POLICY IF EXISTS "Allow All Access" ON dashboard_appointments;
CREATE POLICY "Allow All Access" ON dashboard_appointments FOR ALL USING (true);
        """, language="sql")

if df_display.empty:
    st.info("👋 Welcome! The database is currently empty. Please upload a file in Admin mode.")
