# Auth and Profile

## Scope

This document covers sign-in, sign-up, splash routing, profile display, profile editing, and sign-out in the Flutter app.

## Files

| Purpose | File |
| --- | --- |
| Supabase initialization | `mobile_flutter/lib/main.dart` |
| Splash/session routing | `mobile_flutter/lib/app/app.dart` |
| Auth service | `mobile_flutter/lib/services/auth_service.dart` |
| Login screen | `mobile_flutter/lib/pages/login_page.dart` |
| Register screen | `mobile_flutter/lib/pages/register_page.dart` |
| Profile screen | `mobile_flutter/lib/pages/profile_page.dart` |

## Startup Flow

1. `main.dart` calls `WidgetsFlutterBinding.ensureInitialized()`.
2. Supabase is initialized with the project URL and anon key.
3. `NotificationService.instance.init()` prepares local notifications.
4. `AdhiraApp` shows `_SplashScreen`.
5. Splash waits for a minimum duration and attempts `refreshSession()`.
6. Existing session routes to `/home`; missing session routes to `/login`.

## Login Flow

1. User enters email and password.
2. `LoginPage._signIn()` validates the form.
3. `AuthService.signIn()` calls `Supabase.auth.signInWithPassword`.
4. On success, the app navigates to `/home`.
5. Auth errors are shown with a red floating SnackBar.

## Register Flow

1. User enters name, email, and password.
2. `RegisterPage._signUp()` validates the form.
3. `AuthService.signUp()` creates a Supabase auth user.
4. A public `users` row is inserted with:
   - `id`
   - `name`
   - `email`
5. On success, the app navigates to `/home`.

## Profile Flow

`ProfilePage` loads:

- `users.name`
- `users.email`
- `users.created_at`
- `health_metrics.*`

The screen displays avatar initial, name, email, member date, health profile values, and a sign-out button.

## Profile Editing

Only the display name is editable.

Save flow:

1. User taps edit.
2. Name field becomes editable.
3. Save updates `users.name` for the current user ID.
4. Local state updates after the Supabase update succeeds.

## Sign Out

`ProfilePage._signOut()` calls `AuthService.signOut()` and clears navigation back to `/login`.

## Current Limits

- User metadata and public `users` name can drift. SOS reads auth metadata first, while profile reads public `users`.
- Profile health metrics are read-only.
- Avatar URL is selected but not displayed.
- Registration assumes the `users` insert succeeds after auth sign-up.

## Suggested Next Steps

- Keep display name source consistent across auth metadata and public `users`.
- Add profile avatar display/upload if `avatar_url` is intended.
- Add graceful rollback or repair path if auth sign-up succeeds but public `users` insert fails.
- Add a profile refresh after dashboard metrics are saved to the backend.

