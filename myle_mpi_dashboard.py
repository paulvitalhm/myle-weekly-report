import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime
import io
import json
from supabase import create_client, Client

# ──────────────────────
# Configuration Supabase
# ──────────────────────
SUPABASE_URL = "https://qeyukktbtolkpnpmcoym.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFleXVra3RidG9sa3BucG1jb3ltIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI2OTY5NzIsImV4cCI6MjA3ODI3Mjk3Mn0.2nYizGqkYQgxJFXpjLzA_alpBwBGjLAhy5L9djoiAvc"

@st.cache_resource
def init_supabase():
    try:
        return create_client(SUPABASE_URL, SUPABASE_KEY)
    except Exception as e:
        st.error(f"Erreur de connexion Supabase: {e}")
        return None

supabase = init_supabase()

# ──────────────────────
# Config Page
# ──────────────────────
st.set_page_config(page_title="MYLE MPI Dashboard", layout="wide", page_icon="🚀")

# ──────────────────────
# Fonctions Helper
# ──────────────────────
def get_tier(mpi):
    if mpi >= 47:
        return "🔵 Top Performing"
    elif 35 <= mpi < 47:
        return "🟢 Good"
    else:
        return "🔴 Low Performing"

def get_tier_color(mpi):
    if mpi >= 47:
        return "#2980b9"  # Blue
    elif 35 <= mpi < 47:
        return "#2ecc71"  # Green
    else:
        return "#e74c3c"  # Red

def save_report_to_supabase(start_date, end_date, df_json):
    if not supabase:
        return None
    try:
        # Check for duplicate
        existing = supabase.table("mpi_reports").select("id").eq("start_date", start_date.isoformat()).eq("end_date", end_date.isoformat()).execute()
        
        data = {
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "report_data": df_json
        }
        
        if existing.data:
            # Update existing
            report_id = existing.data[0]['id']
            supabase.table("mpi_reports").update(data).eq("id", report_id).execute()
            return report_id
        else:
            # Insert new
            response = supabase.table("mpi_reports").insert(data).execute()
            if response.data:
                return response.data[0]['id']
        return None
    except Exception as e:
        st.error(f"Erreur lors de la sauvegarde: {e}")
        return None

def delete_report(report_id):
    if not supabase:
        return False
    try:
        supabase.table("mpi_reports").delete().eq("id", report_id).execute()
        return True
    except Exception as e:
        st.error(f"Erreur lors de la suppression: {e}")
        return False

def get_report_from_supabase(report_id):
    if not supabase:
        return None
    try:
        response = supabase.table("mpi_reports").select("*").eq("id", report_id).execute()
        if response.data:
            return response.data[0]
        return None
    except Exception as e:
        st.error(f"Erreur lors du chargement: {e}")
        return None

def get_all_reports():
    if not supabase:
        return []
    try:
        response = supabase.table("mpi_reports").select("id, start_date, end_date, created_at, report_data").order("start_date", desc=True).execute()
        return response.data
    except Exception as e:
        return []

# ──────────────────────
# Interface Principale
# ──────────────────────

st.title("🚀 MYLE Performance Index – MPI Dashboard")

# Navigation Sidebar
with st.sidebar:
    st.header("Navigation")
    
    # Mode Selection
    mode = st.radio("Mode", ["Single Report", "Global Overview"])
    
    st.divider()
    
    if mode == "Single Report":
        if st.button("🏠 Nouveau Rapport", use_container_width=True):
            st.query_params.clear()
            st.rerun()
        
        st.subheader("Historique")
        reports = get_all_reports()
        if reports:
            for rep in reports:
                # Calculate Week Number
                try:
                    s_date = datetime.strptime(rep['start_date'], "%Y-%m-%d")
                    week_num = s_date.isocalendar()[1]
                    label = f"[W{week_num}] {rep['start_date']} au {rep['end_date']}"
                except:
                    label = f"{rep['start_date']} au {rep['end_date']}"
                
                col_nav, col_del = st.columns([0.8, 0.2])
                with col_nav:
                    if st.button(label, key=f"btn_{rep['id']}"):
                        st.query_params["id"] = rep['id']
                        st.rerun()
                with col_del:
                    if st.button("🗑️", key=f"del_{rep['id']}", help="Supprimer ce rapport"):
                        if delete_report(rep['id']):
                            st.success("Supprimé")
                            st.rerun()
        else:
            st.write("Aucun rapport sauvegardé.")
            
    elif mode == "Global Overview":
        st.info("Sélectionnez les périodes à comparer ci-dessous.")

# ──────────────────────
# Logic: Global Overview
# ──────────────────────
if mode == "Global Overview":
    st.header("📊 Global Overview")
    
    all_reports = get_all_reports()
    if not all_reports:
        st.warning("Aucune donnée disponible.")
    else:
        # Multiselect for periods
        report_options = {f"{r['start_date']} au {r['end_date']}": r for r in all_reports}
        selected_labels = st.multiselect("Choisir les périodes", list(report_options.keys()), default=list(report_options.keys())[:5])
        
        if selected_labels:
            overview_data = []
            
            for label in selected_labels:
                rep = report_options[label]
                try:
                    df_rep = pd.read_json(io.StringIO(json.dumps(rep['report_data'])))
                    
                    # Aggregations
                    total_ca = df_rep["CA ($)"].sum()
                    total_hours = df_rep["Heures payées"].sum()
                    total_jobs = df_rep["Jobs"].sum()
                    total_emps = df_rep["Employees"].sum() # Sum of daily employees (approx effort)
                    
                    mpi = total_ca / total_hours if total_hours > 0 else 0
                    jobs_per_emp = total_jobs / total_emps if total_emps > 0 else 0
                    rev_per_job = total_ca / total_jobs if total_jobs > 0 else 0
                    
                    overview_data.append({
                        "Period": label,
                        "Start Date": rep['start_date'],
                        "MPI": mpi,
                        "CA": total_ca,
                        "Hours": total_hours,
                        "Jobs": total_jobs,
                        "Jobs/Emp": jobs_per_emp,
                        "Rev/Job": rev_per_job
                    })
                except Exception as e:
                    continue
            
            df_overview = pd.DataFrame(overview_data).sort_values("Start Date")
            
            # Display Comparative Metrics
            st.subheader("Comparatif")
            st.dataframe(
                df_overview.style.format({
                    "MPI": "{:.2f} $/h",
                    "CA": "{:,.0f} $",
                    "Hours": "{:.1f} h",
                    "Jobs": "{:.0f}",
                    "Jobs/Emp": "{:.1f}",
                    "Rev/Job": "{:.0f} $"
                }),
                use_container_width=True
            )
            
            # Charts
            c1, c2 = st.columns(2)
            with c1:
                fig_mpi = px.line(df_overview, x="Period", y="MPI", markers=True, title="Évolution du MPI")
                fig_mpi.update_traces(line_color='#2980b9', line_width=3)
                st.plotly_chart(fig_mpi, use_container_width=True)
            
            with c2:
                fig_ca = px.bar(df_overview, x="Period", y="CA", title="Évolution du Chiffre d'Affaires")
                fig_ca.update_traces(marker_color='#2ecc71')
                st.plotly_chart(fig_ca, use_container_width=True)

# ──────────────────────
# Logic: Single Report
# ──────────────────────
else:
    # Gestion des Query Params
    query_params = st.query_params
    report_id = query_params.get("id", None)
    
    df_final = None
    start_date_obj = None
    end_date_obj = None

    if report_id:
        # Mode Lecture
        report_data = get_report_from_supabase(report_id)
        if report_data:
            st.info(f"📅 Rapport du **{report_data['start_date']}** au **{report_data['end_date']}**")
            
            # Share Section
            with st.expander("🔗 Partager ce rapport", expanded=False):
                base_url = st.text_input("Base URL (ex: https://mon-app.streamlit.app)", value="http://localhost:8501")
                full_url = f"{base_url}/?id={report_id}"
                st.code(full_url, language="text")
                st.caption("Copiez l'URL ci-dessus pour partager.")

            df_final = pd.read_json(io.StringIO(json.dumps(report_data['report_data'])))
            if "Date" in df_final.columns:
                 df_final["Date"] = pd.to_datetime(df_final["Date"], unit='ms').dt.date
            
            # Backward compatibility for old reports
            if "Employees List" not in df_final.columns:
                df_final["Employees List"] = [[] for _ in range(len(df_final))]
            if "Clients List" not in df_final.columns:
                df_final["Clients List"] = [[] for _ in range(len(df_final))]

        else:
            st.error("Rapport introuvable.")
    else:
        # Mode Création
        st.markdown("### Upload tes deux fichiers de la semaine")
        col1, col2 = st.columns(2)
        with col1:
            payroll_file = st.file_uploader("1. Payroll Report (Time Squared)", type=["xlsx"])
        with col2:
            appointments_file = st.file_uploader("2. Appointments / Facturation", type=["xlsx"])

        if payroll_file and appointments_file:
            with st.spinner("Analyse en cours..."):
                # 1. Lecture Payroll
                payroll_xl = pd.ExcelFile(payroll_file)
                heures_par_jour = {}
                employees_par_jour = {} # Set of names

                for sheet_name in payroll_xl.sheet_names:
                    if sheet_name[0].isdigit(): 
                        df = pd.read_excel(payroll_file, sheet_name=sheet_name, header=5)
                        if "Start date" in df.columns:
                            for _, row in df.iterrows():
                                try:
                                    date_val = row["Start date"]
                                    if pd.isna(date_val): continue
                                    
                                    if isinstance(date_val, (int, float)):
                                        date = pd.to_datetime(date_val, unit='d', origin='1899-12-30').date()
                                    else:
                                        date = pd.to_datetime(date_val).date()
                                    
                                    heures = row.get("Total hours", row.get("Length (hours & minutes)", 0))
                                    if isinstance(heures, str) and "h" in heures:
                                        h, m = heures.split("h")
                                        m = m.strip().replace("m", "")
                                        heures = int(h) + int(m)/60
                                    
                                    h_val = float(heures)
                                    if h_val > 0:
                                        heures_par_jour[date] = heures_par_jour.get(date, 0) + h_val
                                        
                                        if date not in employees_par_jour:
                                            employees_par_jour[date] = set()
                                        # Clean name (remove "1. ")
                                        emp_name = sheet_name.split('.', 1)[-1].strip() if '.' in sheet_name else sheet_name
                                        employees_par_jour[date].add(emp_name)
                                except:
                                    continue

                # 2. Lecture Appointments
                app_df = pd.read_excel(appointments_file)
                app_df = app_df[app_df["Status"] == "Confirmed"]
                app_df["Date"] = pd.to_datetime(app_df["Appointment date"], errors="coerce").dt.date
                app_df["Cost"] = pd.to_numeric(app_df["Cost"], errors="coerce").fillna(0)
                
                ca_par_jour = app_df.groupby("Date")["Cost"].sum().to_dict()
                jobs_par_jour = app_df.groupby("Date").size().to_dict()
                
                # Clients per day
                clients_par_jour = {}
                if "Customer name" in app_df.columns:
                    for _, row in app_df.iterrows():
                        d = row["Date"]
                        c_name = row["Customer name"]
                        if pd.notna(d) and pd.notna(c_name):
                            if d not in clients_par_jour:
                                clients_par_jour[d] = set()
                            clients_par_jour[d].add(str(c_name))

                # 3. Fusion
                all_dates = sorted(set(list(heures_par_jour.keys()) + list(ca_par_jour.keys())))
                resultats = []

                for date in all_dates:
                    ca = ca_par_jour.get(date, 0)
                    heures = heures_par_jour.get(date, 0)
                    jobs = jobs_par_jour.get(date, 0)
                    
                    emps_set = employees_par_jour.get(date, set())
                    clients_set = clients_par_jour.get(date, set())
                    
                    nb_employees = len(emps_set)
                    
                    mpi = ca / heures if heures > 0 else 0
                    
                    resultats.append({
                        "Date": date,
                        "CA ($)": round(ca, 2),
                        "Heures payées": round(heures, 2),
                        "MPI ($/h)": round(mpi, 2) if heures > 0 else 0,
                        "Jobs": jobs,
                        "Employees": nb_employees,
                        "Employees List": sorted(list(emps_set)),
                        "Clients List": sorted(list(clients_set)),
                        "Tier": get_tier(mpi)
                    })

                df_final = pd.DataFrame(resultats)
                if not df_final.empty:
                    start_date_obj = df_final["Date"].min()
                    end_date_obj = df_final["Date"].max()
                    
                    if st.button("💾 Sauvegarder et Partager", type="primary"):
                        df_json = df_final.copy()
                        df_json["Date"] = pd.to_datetime(df_json["Date"])
                        json_str = df_json.to_json(date_format='epoch', orient='records')
                        json_data = json.loads(json_str)
                        
                        new_id = save_report_to_supabase(start_date_obj, end_date_obj, json_data)
                        if new_id:
                            st.success("Rapport sauvegardé !")
                            st.query_params["id"] = new_id
                            st.rerun()

    # ──────────────────────
    # Affichage Single Report
    # ──────────────────────
    if df_final is not None and not df_final.empty:
        
        # Check if data is from old report (missing lists or old string format)
        if df_final["Employees List"].apply(lambda x: isinstance(x, str) and x == "-").any():
             st.warning("⚠️ Ce rapport a été créé avec une ancienne version. Veuillez ré-uploader les fichiers pour voir les détails des employés et clients.")

        # KPIs
        total_ca = df_final["CA ($)"].sum()
        total_heures = df_final["Heures payées"].sum()
        total_jobs = df_final["Jobs"].sum()
        avg_mpi = total_ca / total_heures if total_heures > 0 else 0
        
        df_final["Jobs/Emp"] = df_final.apply(lambda x: x["Jobs"] / x["Employees"] if x["Employees"] > 0 else 0, axis=1)
        avg_jobs_per_emp = df_final["Jobs/Emp"].mean()
        rev_per_job = total_ca / total_jobs if total_jobs > 0 else 0
        
        st.divider()
        
        kpi1, kpi2, kpi3, kpi4 = st.columns(4)
        kpi1.metric("MPI Moyen", f"{avg_mpi:.2f} $/h", delta_color="normal")
        kpi2.metric("CA Total", f"{total_ca:,.0f} $")
        kpi3.metric("Heures Totales", f"{total_heures:.1f} h")
        kpi4.metric("Jobs Totaux", f"{total_jobs}")

        st.caption("📊 Statistiques Avancées")
        s1, s2, s3 = st.columns(3)
        s1.metric("Jobs / Employé (Moyenne)", f"{avg_jobs_per_emp:.1f}")
        s2.metric("Revenu Moyen / Job", f"{rev_per_job:.0f} $")
        s3.metric("Employés (Max/Jour)", f"{df_final['Employees'].max()}")

        st.divider()

        # Graph
        st.subheader("📈 Évolution du MPI & Tiers")
        fig = go.Figure()
        x_min = df_final["Date"].min()
        x_max = df_final["Date"].max()
        
        fig.add_shape(type="rect", x0=x_min, x1=x_max, y0=0, y1=35, fillcolor="rgba(231, 76, 60, 0.1)", line=dict(width=0), layer="below")
        fig.add_shape(type="rect", x0=x_min, x1=x_max, y0=35, y1=47, fillcolor="rgba(46, 204, 113, 0.1)", line=dict(width=0), layer="below")
        y_max_graph = max(df_final["MPI ($/h)"].max() * 1.1, 60)
        fig.add_shape(type="rect", x0=x_min, x1=x_max, y0=47, y1=y_max_graph, fillcolor="rgba(41, 128, 185, 0.1)", line=dict(width=0), layer="below")

        fig.add_trace(go.Scatter(
            x=df_final["Date"], 
            y=df_final["MPI ($/h)"],
            mode='lines+markers',
            name='MPI',
            line=dict(color='#34495e', width=3),
            marker=dict(size=10, color=[get_tier_color(m) for m in df_final["MPI ($/h)"]], line=dict(width=2, color='white'))
        ))

        fig.update_layout(yaxis_title="MPI ($/h)", xaxis_title="Date", template="plotly_white", margin=dict(l=20, r=20, t=20, b=20), yaxis=dict(range=[0, y_max_graph]))
        st.plotly_chart(fig, use_container_width=True)

        # Tableau
        st.subheader("Détails Journaliers")
        
        df_display = df_final.copy()
        # We don't format Date as string here, we let column_config handle it for sorting
        df_display["Performance"] = df_display["MPI ($/h)"].apply(get_tier)
        
        st.dataframe(
            df_display[["Date", "Performance", "MPI ($/h)", "CA ($)", "Heures payées", "Jobs", "Employees List", "Clients List"]],
            use_container_width=True,
            column_config={
                "Date": st.column_config.DateColumn("Date", format="ddd, DD MMM YYYY"),
                "MPI ($/h)": st.column_config.NumberColumn(format="%.2f $/h"),
                "CA ($)": st.column_config.NumberColumn(format="%.2f $"),
                "Heures payées": st.column_config.NumberColumn(format="%.2f h"),
                "Employees List": st.column_config.ListColumn("Employés"),
                "Clients List": st.column_config.ListColumn("Clients"),
            }
        )

        # Export
        output = io.BytesIO()
        with pd.ExcelWriter(output, engine='xlsxwriter') as writer:
            df_final.to_excel(writer, index=False, sheet_name="MPI")
        st.download_button("📥 Télécharger le rapport Excel", output.getvalue(), "MYLE_MPI_Report.xlsx")