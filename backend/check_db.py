import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from db import supabase

results = []

results.append(f"Client initialized: {supabase is not None}")

tables = ['users', 'health_metrics', 'medicines', 'reminders', 'chat_messages']

for table in tables:
    try:
        res = supabase.table(table).select('*').limit(5).execute()
        results.append(f"[OK]     {table} — {len(res.data)} rows — data: {res.data}")
    except Exception as e:
        results.append(f"[ERROR]  {table} — {type(e).__name__}: {str(e)}")

output = "\n".join(results)
print(output)

with open("db_check_result.txt", "w") as f:
    f.write(output + "\n")
