import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from db import supabase

try:
    res = supabase.from_('users').select('id, name, email, avatar_url, created_at').limit(1).execute()
    result = f'COLUMNS OK — avatar_url exists\nrows: {res.data}'
except Exception as e:
    result = f'ERROR: {type(e).__name__}: {str(e)}'

print(result)
with open('users_schema_check.txt', 'w') as f:
    f.write(result + '\n')
