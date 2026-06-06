import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from db import supabase

out = []

# Test 1 — signup
try:
    res = supabase.auth.sign_up({
        'email': 'testuser99@adhira.com',
        'password': 'Test123456!'
    })
    out.append(f'SIGNUP OK — user id: {res.user.id if res.user else None}')
    out.append(f'  session: {res.session is not None}')
    out.append(f'  user email confirmed: {res.user.email_confirmed_at if res.user else None}')
except Exception as e:
    out.append(f'SIGNUP ERROR — {type(e).__name__}: {str(e)}')

# Test 2 — signin
try:
    res2 = supabase.auth.sign_in_with_password({
        'email': 'testuser99@adhira.com',
        'password': 'Test123456!'
    })
    out.append(f'SIGNIN OK — user id: {res2.user.id if res2.user else None}')
except Exception as e:
    out.append(f'SIGNIN ERROR — {type(e).__name__}: {str(e)}')

# Test 3 — insert into users table
try:
    uid = supabase.auth.sign_in_with_password({
        'email': 'testuser99@adhira.com',
        'password': 'Test123456!'
    }).user.id
    ins = supabase.from_('users').insert({
        'id': uid,
        'name': 'Test User',
        'email': 'testuser99@adhira.com'
    }).execute()
    out.append(f'USERS INSERT OK — {ins.data}')
except Exception as e:
    out.append(f'USERS INSERT ERROR — {type(e).__name__}: {str(e)}')

result = '\n'.join(out)
print(result)
with open('auth_result.txt', 'w') as f:
    f.write(result + '\n')
