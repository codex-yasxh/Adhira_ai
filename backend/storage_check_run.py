import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from db import supabase

out = []

# Check buckets
try:
    buckets = supabase.storage.list_buckets()
    out.append(f'Total buckets: {len(buckets)}')
    for b in buckets:
        out.append(f'  bucket: {b.name} | public: {b.public} | id: {b.id}')
    if not buckets:
        out.append('  No buckets found — avatars bucket not created yet')
except Exception as e:
    out.append(f'BUCKET LIST ERROR: {type(e).__name__}: {str(e)}')

# Try listing files in avatars bucket
try:
    files = supabase.storage.from_('avatars').list()
    out.append(f'avatars bucket accessible — {len(files)} files')
except Exception as e:
    out.append(f'avatars bucket access ERROR: {type(e).__name__}: {str(e)}')

result = '\n'.join(out)
print(result)
with open('storage_check.txt', 'w') as f:
    f.write(result + '\n')
