# Adhira Mobile Flutter - Project Overview

## Purpose

Adhira is an Android-first Flutter health assistant app. It combines a conversational AI companion, health metric tracking, medicine reminders, food-medication conflict checks, profile management, and emergency SOS flows.

The Flutter app is the main mobile client. It talks to:

- Supabase for authentication and user-owned data.
- FastAPI backend for AI chat, health metric API helpers, SOS SMS, and optional food conflict history.
- Device services for speech recognition, text-to-speech, notifications, dialer/SMS intents, and Android alarms.

## Main Entry Points

| Area | File |
| --- | --- |
| Flutter app start | `mobile_flutter/lib/main.dart` |
| App shell and splash routing | `mobile_flutter/lib/app/app.dart` |
| Bottom navigation tabs | `Dashboard`, `Medicines`, `Chat`, `Reminders`, `SOS` |
| Backend | `backend/main.py` |
| API client | `mobile_flutter/lib/core/network/api_client.dart` |
| API paths | `mobile_flutter/lib/core/network/api_endpoints.dart` |
| Supabase migrations | `supabase/migrations/`, `backend/*.sql` |

## Current Mobile Screens

| Screen | Status | Notes |
| --- | --- | --- |
| Login | Implemented | Supabase email/password sign-in. |
| Register | Implemented | Creates Supabase auth user and inserts profile row in `users`. |
| Dashboard | Implemented UI | Local editable metrics and health-aware radar scoring. Backend writes are not wired from this screen yet. |
| Medicines | Implemented UI | In-memory medicine list with add/delete and shared medicine names for chat/conflict checks. |
| Food Conflict | Implemented local detection | Uses local rules from Flutter page. Backend also has `/food/conflicts`, but the current Flutter page does not call it. |
| Chat | Implemented | Sends query, user ID, recent history, and medicine names to backend Gemini endpoint. |
| Voice Mode | Implemented | Speech-to-text query input, backend chat call, and TTS reply playback. |
| Reminders | Implemented | Loads/saves reminders in Supabase and schedules local Android notifications. |
| SOS | Implemented | Manages emergency contacts in Supabase, sends SOS through backend Fast2SMS, then falls back to native SMS launcher. |
| Profile | Implemented | Reads `users` and `health_metrics`, edits name, signs out. |

## Data Flow Summary

### Auth

`main.dart` initializes Supabase. The splash screen refreshes the current session and routes to `/home` or `/login`.

Registration:

1. `AuthService.signUp` creates a Supabase auth user.
2. A row is inserted into public `users` with `id`, `name`, and `email`.
3. App navigates to the main shell.

Login:

1. `AuthService.signIn` calls Supabase email/password auth.
2. App navigates to the main shell.

### Chat and Voice

1. Chat or voice mode collects user text.
2. Flutter builds recent history and gets `currentUser.id`.
3. `HealthAssistantApiService.sendMessage` posts to `/health/assistant`.
4. Backend fetches latest health metrics, appends medicine names if provided, builds the Adhira prompt, and calls Gemini.
5. Flutter displays or speaks the reply.

### Reminders

1. `RemindersPage` loads rows from Supabase `reminders`.
2. Enabled reminders are scheduled through `NotificationService`.
3. Toggling updates local notification state and syncs enabled status to Supabase.
4. Tapping a notification routes the app to the Reminders tab.

### SOS

1. `SosPage` loads `emergency_contacts` for the current user.
2. User confirms SOS.
3. Flutter posts `user_name` and contact phone numbers to `/sos/alert`.
4. Backend validates the request and calls Fast2SMS.
5. If backend SMS fails, Flutter falls back to the native SMS app.

## Backend Endpoints Used or Available

| Endpoint | Current Role |
| --- | --- |
| `GET /health/metrics` | Fetch default or stored health metrics. |
| `POST /health/update` | Upsert health metrics. Not currently wired from Flutter dashboard. |
| `POST /health/assistant` | Main Gemini health companion endpoint used by chat and voice mode. |
| `POST /sos/alert` | Sends emergency SMS through Fast2SMS. |
| `POST /food/conflicts` | Backend food conflict checker and optional persistence. Not currently used by Flutter food page. |
| `GET /food/conflicts/history` | Returns last 10 food conflict checks. Not currently used by Flutter. |
| `GET /health/check` | Backend diagnostics. |

## Important Configuration

- `ApiClient.baseUrl` is hardcoded to `http://192.168.31.35:8000`.
- Supabase URL and anon key are hardcoded in `mobile_flutter/lib/main.dart`.
- Backend requires environment variables for Google Gemini, Supabase, and Fast2SMS.
- Notification timezone is set to `Asia/Kolkata`.

## Current Gaps

- Dashboard metric edits update only local Flutter state; they do not call `/health/update`.
- Dashboard tile status/trend text does not recalculate after metric edits.
- Medicines are in-memory only and reset when the app restarts.
- Food conflict screen uses local rules only, while backend conflict endpoints are separate.
- `ApiClient.baseUrl` should move to build-time config or environment-specific setup.
- Supabase credentials should be reviewed before public release.
- Chat history is in-memory only; persistent chat storage is not wired.
- Reminder schema compatibility is handled with fallback column names, which suggests the database schema should be normalized.

## Recommended Next Work

1. Wire dashboard save to `POST /health/update`.
2. Persist medicines in Supabase and load them on app start.
3. Switch food conflict detection to backend `/food/conflicts` so history can be saved.
4. Move API base URL and Supabase config out of hardcoded source.
5. Add focused widget/service tests around chat, reminders, SOS validation, and dashboard metric updates.
6. Update `mobile_flutter/README.md` from the default Flutter template to project-specific setup instructions.

