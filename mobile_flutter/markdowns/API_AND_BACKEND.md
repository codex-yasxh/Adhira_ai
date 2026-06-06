# API and Backend Integration

## Scope

This document describes how the Flutter app talks to the FastAPI backend and where direct Supabase access is used.

## Files

| Purpose | File |
| --- | --- |
| API client | `mobile_flutter/lib/core/network/api_client.dart` |
| API endpoint constants | `mobile_flutter/lib/core/network/api_endpoints.dart` |
| Health assistant service | `mobile_flutter/lib/services/health_assistant_api_service.dart` |
| Backend app | `backend/main.py` |
| Supabase client backend | `backend/db.py` |

## Flutter API Client

`ApiClient` wraps simple JSON GET and POST calls with:

- `Content-Type: application/json`
- `Accept: application/json`
- request timeout support

Current base URL:

```dart
http://192.168.31.35:8000
```

This is suitable for local LAN testing but should become environment-specific before release.

## Flutter Backend Calls

| Feature | Endpoint | Caller |
| --- | --- | --- |
| Text chat | `POST /health/assistant` | `HealthAssistantApiService.sendMessage` |
| Voice mode | `POST /health/assistant` | `VoiceAssistantPage` through `HealthAssistantApiService` |
| SOS SMS | `POST /sos/alert` | `SosPage` through `ApiClient` |

## Backend Endpoints

| Endpoint | Purpose |
| --- | --- |
| `GET /health/metrics` | Fetch stored or default health metrics for a user. |
| `POST /health/update` | Upsert user health metrics. |
| `POST /health/assistant` | Build Adhira prompt and call Gemini. |
| `POST /sos/alert` | Validate contacts and send emergency SMS through Fast2SMS. |
| `POST /food/conflicts` | Compute food-medication conflicts and persist history in background. |
| `GET /food/conflicts/history` | Return recent conflict checks. |
| `GET /health/check` | Diagnostics for backend, Supabase, Google API, and environment variables. |

## Direct Supabase Usage in Flutter

Flutter directly uses Supabase for:

- Auth session management.
- Public `users` row insert/update/read.
- `health_metrics` read in profile.
- `reminders` read/write/delete.
- `emergency_contacts` read/write/delete.

## Health Assistant Prompt Context

`/health/assistant` receives:

- `query`
- `user_id`
- `history`
- optional `medicine_names`

Backend behavior:

1. Validates Google API key and query.
2. Fetches latest health metrics for `user_id`.
3. Adds medicine names as context when provided.
4. Adds recent conversation history.
5. Uses the Adhira system prompt.
6. Calls Gemini and returns response text.

## SOS Backend Flow

`/sos/alert` receives:

- `user_name`
- `contacts`

Backend validates:

- Fast2SMS API key exists.
- Contact list is not empty.
- Contact list has at most 5 numbers.
- Each phone number is exactly 10 digits.

Then it calls Fast2SMS and returns success or detailed failure.

## Current Integration Gaps

- Dashboard does not call `GET /health/metrics` or `POST /health/update` yet.
- Food conflict Flutter screen does not call backend food endpoints yet.
- API base URL is hardcoded.
- Endpoint constants only include `/health/assistant`; SOS and food endpoints are passed as raw strings.
- Error handling differs between `sendMessage`, `askHealthAssistant`, and raw `ApiClient` calls.

## Suggested Next Steps

- Add endpoint constants for all backend paths.
- Add an environment/config layer for API base URL.
- Create small repository services for metrics, reminders, emergency contacts, medicines, and food conflicts.
- Normalize error handling so user-facing messages are consistent.
- Add integration tests or mocked service tests around backend calls.

