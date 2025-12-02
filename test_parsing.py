import pandas as pd

payroll_file = "Payroll_report_11-03-2025_to_11-08-2025.xlsx"
appointments_file = "Appointments (22).xlsx"

print("--- Testing Payroll Parsing ---")
try:
    payroll_xl = pd.ExcelFile(payroll_file)
    employees_par_jour = {}
    for sheet_name in payroll_xl.sheet_names:
        if sheet_name[0].isdigit():
            print(f"Processing sheet: {sheet_name}")
            df = pd.read_excel(payroll_file, sheet_name=sheet_name, header=5)
            if "Start date" in df.columns:
                for _, row in df.iterrows():
                    date_val = row["Start date"]
                    if pd.isna(date_val): continue
                    
                    if isinstance(date_val, (int, float)):
                        date = pd.to_datetime(date_val, unit='d', origin='1899-12-30').date()
                    else:
                        date = pd.to_datetime(date_val).date()
                    
                    emp_name = sheet_name.split('.', 1)[-1].strip() if '.' in sheet_name else sheet_name
                    if date not in employees_par_jour:
                        employees_par_jour[date] = set()
                    employees_par_jour[date].add(emp_name)
    
    print("Employees found per day:")
    for d, emps in employees_par_jour.items():
        print(f"{d}: {emps}")

except Exception as e:
    print(f"Error parsing payroll: {e}")

print("\n--- Testing Appointments Parsing ---")
try:
    app_df = pd.read_excel(appointments_file)
    clients_par_jour = {}
    if "Customer name" in app_df.columns:
        print("Column 'Customer name' found.")
        app_df["Date"] = pd.to_datetime(app_df["Appointment date"], errors="coerce").dt.date
        for _, row in app_df.iterrows():
            d = row["Date"]
            c_name = row["Customer name"]
            if pd.notna(d) and pd.notna(c_name):
                if d not in clients_par_jour:
                    clients_par_jour[d] = set()
                clients_par_jour[d].add(str(c_name))
    else:
        print("Column 'Customer name' NOT found.")

    print("Clients found per day (first 3 days):")
    for d in sorted(clients_par_jour.keys())[:3]:
        print(f"{d}: {clients_par_jour[d]}")

except Exception as e:
    print(f"Error parsing appointments: {e}")
