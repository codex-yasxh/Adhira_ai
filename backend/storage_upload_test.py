import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from db import supabase

out = []

# Test 1 — try uploading a small test file to avatars bucket
try:
    test_bytes = b'test'
    res = supabase.storage.from_('avatar').upload(
        path='test/test.txt',
        file=test_bytes,
        file_options={'content-type': 'text/plain', 'upsert': 'true'}
    )
    out.append(f'UPLOAD OK: {res}')
except Exception as e:
    out.append(f'UPLOAD ERROR: {type(e).__name__}: {str(e)}')

# Test 2 — get public URL
try:
    url = supabase.storage.from_('avatar').get_public_url('test/test.txt')
    out.append(f'PUBLIC URL: {url}')
except Exception as e:
    out.append(f'URL ERROR: {type(e).__name__}: {str(e)}')

# Test 3 — list files
try:
    files = supabase.storage.from_('avatar').list()
    out.append(f'LIST OK: {len(files)} items')
except Exception as e:
    out.append(f'LIST ERROR: {type(e).__name__}: {str(e)}')

result = '\n'.join(out)
print(result)
with open('storage_upload_test.txt', 'w') as f:
    f.write(result + '\n')
