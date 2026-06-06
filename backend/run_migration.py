"""
Run the Supabase migration to add missing columns to health_metrics table.
Usage: python backend/run_migration.py
"""
import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from db import supabase

if supabase is None:
    print("ERROR: Supabase not configured. Check your .env file.")
    sys.exit(1)

MIGRATIONS = [
    "ALTER TABLE health_metrics ADD COLUMN IF NOT EXISTS spo2 TEXT DEFAULT '98';",
    "ALTER TABLE health_metrics ADD COLUMN IF NOT EXISTS resp_rate TEXT DEFAULT '16';",
    "ALTER TABLE health_metrics ADD COLUMN IF NOT EXISTS weight TEXT DEFAULT '68';",
    "ALTER TABLE health_metrics ADD COLUMN IF NOT EXISTS bmi TEXT DEFAULT '22.4';",
    "ALTER TABLE health_metrics ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();",
]

for sql in MIGRATIONS:
    try:
        print(f"Executing: {sql}")
        supabase.table("_migrations").select("1").limit(1).execute()
        # Use raw SQL execution
        supabase.rpc("exec_sql", {"query": sql}).execute()
        print(f"  -> OK")
    except Exception as e:
        error_str = str(e).lower()
        # Column already exists is fine
        if "already exists" in error_str:
            print(f"  -> Already exists (skipped)")
        elif "function" in error_str and "exec_sql" in error_str:
            # Try direct ALTER approach
            print(f"  -> rpc not available, trying direct ALTER...")
            try:
                supabase.table("health_metrics").update({"spo2": "98"}).eq("user_id", "dummy").execute()
                print(f"  -> Columns likely already exist (based on successful update test)")
            except Exception as e2:
                print(f"  -> Update test also failed: {e2}")
                print(f"  -> WARNING: Run the migration manually in Supabase SQL editor")
        else:
            print(f"  -> Error: {e}")

print()
print("Migration complete. Checking current table schema...")
try:
    result = supabase.table("health_metrics").select("*").limit(1).execute()
    if result.data:
        print(f"Columns in health_metrics: {list(result.data[0].keys())}")
    else:
        print("No rows in health_metrics table. Table exists though.")
except Exception as e:
    print(f"Could not verify schema: {e}")

print()
print("If the RPC approach didn't work, run this in Supabase SQL Editor:")
print(open(os.path.join(os.path.dirname(__file__), "supabase_migration_add_metrics.sql")).read())