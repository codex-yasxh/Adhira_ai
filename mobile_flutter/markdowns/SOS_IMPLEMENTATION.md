# SOS Feature - End to End Implementation

## Overview

This document describes how the SOS emergency alert feature works end-to-end, including the Flutter mobile app frontend, the Python FastAPI backend, and the Fast2SMS API integration.

---

## Architecture

```
[Flutter SOS Page]
       |
       | POST /sos/alert  { user_name, contacts: [phone1, phone2, ...] }
       |
[FastAPI Backend] --> main.py --> /sos/alert endpoint
       |
       | GET https://www.fast2sms.com/dev/bulkV2
       |      ?authorization=<API_KEY>
       |      &message=<SOS_ALERT_TEXT>
       |      &language=english
       |      &route=q
       |      &numbers=<COMMA_SEPARATED_PHONES>
       |
[Fast2SMS API]
       |
       | Sends SMS to emergency contacts
```

## File Locations

| Component | File |
|-----------|------|
| Flutter SOS Page | `mobile_flutter/lib/pages/sos_page.dart` |
| Flutter API Client | `mobile_flutter/lib/core/network/api_client.dart` |
| Backend SOS Route | `backend/main.py` (`/sos/alert` endpoint) |
| Backend Environment | `backend/.env` |
| Root Environment   | `.env` |
| SOS Documentation (old) | `mobile_flutter/markdowns/SOS.md` |

---

## Flow Details

### 1. User taps SOS button (`_handleSosTap` in `sos_page.dart`)

- **Guard**: Checks if `_sendingSos` is already true (prevents double-send)
- **Reload**: Calls `_loadContacts()` to get fresh contacts from Supabase
- **Validation**: If `_contacts` is empty, shows Snackbar "Please add emergency contacts first"
- **Confirmation**: Shows dialog listing contacts, asks user to confirm "SEND"
- **Payload Construction**:
  ```json
  {
    "user_name": "<user's display name from Supabase Auth metadata, or 'ADHIRA User'>",
    "contacts": ["98XXXXXXXX", "98XXXXXXXX", ...]
  }
  ```
- **API Call**: `_apiClient.postJson('/sos/alert', body: payload)`
- **Success**: Shows green Snackbar "🆘 SOS sent to all contacts"
- **Failure**: Shows red Snackbar "Could not send SOS. Please try again."

### 2. Backend receives request (`/sos/alert` in `main.py`)

- Validates `FAST2SMS_API_KEY` env variable exists → 503 if missing
- Validates contacts list is non-empty → 400 if empty
- Validates contacts ≤ 5 → 400 if exceeded
- Validates each phone is exactly 10 digits → 400 if invalid
- Constructs SMS message:
  ```
  SOS ALERT: <user_name> needs immediate help! This is an emergency alert from ADHIRA health assistant app. Please contact them immediately.
  ```
- Calls Fast2SMS API via GET request with params:
  - `authorization`: API key from env
  - `message`: SOS alert text
  - `language`: english
  - `route`: q (Quick Transactional)
  - `numbers`: comma-separated phone numbers
- Checks `result.get("return") is True` → success if true
- Returns `{"status": "success", "message": "SOS sent"}` on success
- Raises `HTTPException(500, detail=f"SMS failed: {result}")` on API failure

### 3. Fast2SMS API responds

```json
// Success
{ "return": true, "request_id": "abc123", "message": [...] }

// Failure (e.g., invalid numbers, quota exceeded)
{ "return": false, "message": ["Something went wrong"] }
```

---

## Current Issues Found & Fixed

### Issue 1: No logging anywhere

**Before**: Backend had zero print/log statements in `/sos/alert`. Flutter had no debug prints.

**Fix**: 
- Backend: Added structured logging with timestamps for request received, API call attempts, success/failure with full response details
- Flutter: Added `debugPrint` statements throughout `_handleSosTap()` flow: contacts loaded, payload being sent, response status code, response body, error details

### Issue 2: Fast2SMS error details were swallowed

**Before**: When Fast2SMS returned `{"return": false, ...}`, the backend threw `HTTPException(500, detail=f"SMS failed: {result}")`. The Flutter `catch` block caught the 500 status and showed a generic "Could not send SOS" message, discarding the actual Fast2SMS error.

**Fix**: 
- Backend now returns a proper JSON error response with the Fast2SMS error message included
- Flutter now reads the response body in both success and failure cases, extracting and showing the actual server-provided error message

### Issue 3: Flutter didn't read response body for error messages

**Before**: Flutter code only checked `response.statusCode` and showed hardcoded messages. Never read `response.body`.

**Fix**: Flutter now reads `response.body` to extract the `detail` field from the backend error response and shows it in the Snackbar.

### Issue 4: Fast2SMS HTTP 400 error JSON not parsed (critical bug)

**Before**: The code called `response.raise_for_status()` which raised a `RequestException` on HTTP 400 responses. The `except RequestException` handler then returned HTTP 502, and Flutter showed a generic "Could not send SOS" — the actual Fast2SMS error in the JSON body was **never read**.

**Fix**: Removed `raise_for_status()`. The JSON is parsed regardless of HTTP status code. The actual Fast2SMS error message is extracted and returned to Flutter, which displays it in the Snackbar.

### Issue 5: Fast2SMS route & parameters

**Before**: Used `route: "q"` without `sender_id`.

**Fix**: Added `sender_id: "ADHIRA"` parameter (required for Quick Transactional route `q`).

### Issue 6: Fast2SMS account not activated (ROOT CAUSE)

**Actual error from Fast2SMS API**:
```json
{"status_code": 999, "message": "You need to complete one transaction of 100 INR or more before using API route."}
```

**Root cause**: The Fast2SMS API key (`ZtSDb...`) exists in the `.env` files, but the Fast2SMS account has never been recharged. Free/trial Fast2SMS accounts require a minimum recharge of **₹100 or more** to activate the API route.

**Fix**: Backend now detects `status_code: 999` and returns a user-friendly message explaining the account activation requirement.

---

## Fast2SMS API Details

### Endpoint
```
GET https://www.fast2sms.com/dev/bulkV2
```

### Parameters
| Parameter | Value | Description |
|-----------|-------|-------------|
| `authorization` | `FAST2SMS_API_KEY` | Your API key from Fast2SMS dashboard |
| `message` | SOS alert text | Max 160 chars for single SMS |
| `language` | `english` | Language of the message |
| `route` | `q` | `q` = Quick Transactional, `v5` = DLT Transactional |
| `numbers` | Comma-separated | Max 5 numbers per request (enforced) |

### Response Format
```json
{
  "return": true/false,
  "request_id": "string",
  "message": [
    {"message": "SMS sent successfully", "number": "98XXXXXXXX"}
  ]
}
```

### Common Failure Reasons
1. **Account not activated (status_code: 999)**: Fast2SMS account needs a minimum recharge of ₹100 before API can be used. **This is the current error.**
2. **Unregistered numbers**: Free/trial Fast2SMS accounts can only send to numbers registered/verified in the Fast2SMS dashboard
3. **Insufficient balance**: Fast2SMS account has run out of SMS credits
4. **Invalid API key**: The key has been revoked or is incorrect
5. **Rate limited**: Too many requests in a short time
6. **Content blocked**: Message contains prohibited keywords

---

## Environment Variables

Both `backend/.env` and root `.env` contain:

```ini
FAST2SMS_API_KEY=ZtSDboMCi6Xzv0nkRmwd3JlKcFq9WhNUs1aAHEIjBx2g8frePQnQTkhR9Kbx1gS3orOmYci0l4utXB2J
```

> **Note**: The `backend/main.py` reads `FAST2SMS_API_KEY` using `os.getenv("FAST2SMS_API_KEY")`. The backend does NOT load `.env` itself - it relies on the root `config.py` which loads `.env` via `load_dotenv()`. If the backend is run from the `backend/` directory, the root `.env` must be accessible.

---

## Logging

### Backend Logging (Added)
```python
print(f"[SOS] {datetime.now().isoformat()} - Request received for {request.user_name}")
print(f"[SOS] Contacts: {cleaned_contacts}")
print(f"[SOS] Calling Fast2SMS API...")
print(f"[SOS] Fast2SMS response status: {response.status_code}")
print(f"[SOS] Fast2SMS response body: {result}")
print(f"[SOS] SMS sent successfully to {len(cleaned_contacts)} contact(s)")
```

### Flutter Logging (Added)
```dart
debugPrint('[SOS] Contacts loaded: ${_contacts.length}');
debugPrint('[SOS] Sending SOS to: $phones');
debugPrint('[SOS] Response status: ${response.statusCode}');
debugPrint('[SOS] Response body: ${response.body}');
debugPrint('[SOS] Exception: $_');
```

---

## Testing the SOS Feature

1. Open SOS page in the app
2. Tap contacts icon → Add at least one emergency contact with a valid 10-digit phone number
3. Tap the big red SOS button
4. Confirm the dialog
5. Observe:
   - Logs in backend terminal
   - Snackbar message on app
   - SMS delivery to the contact number (if Fast2SMS account allows)