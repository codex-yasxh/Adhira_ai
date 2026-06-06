# Adhira Chat Feature - Implementation Status

## 🎯 Overview

Adhira is a warm, motherly health companion AI that engages in contextual conversations. The chat feature integrates user health metrics with conversation history to provide personalized, context-aware responses.

---

## ✅ Implemented Phases

### Phase 1: Basic Chat Pipe (Complete)

**Goal:** Prove the backend ↔ frontend pipe works.

- User types message → sent to backend API
- Backend calls Gemini API with user query
- Response displayed in chat with typing indicator
- **Files:** `chat_page.dart`, `health_assistant_api_service.dart`

**Result:** Plain Gemini responses, no context yet.

---

### Phase 2: Health Context Integration (Complete)

**Goal:** Include user's health metrics in conversation context.

- Backend fetches latest health metrics from Supabase (blood pressure, heart rate, sleep, etc.)
- Health data injected into prompt as background context
- Adhira references metrics when relevant
- **Files:** `backend/main.py` (updated `/health/assistant` endpoint)

**Result:** Adhira acknowledges health data but doesn't force it unnecessarily.

---

### Phase 3: Chat Memory with Conversation Priority (Complete)

**Goal:** Give Adhira conversation memory so she understands context.

- Flutter app builds history from last 6 messages in conversation
- History sent to backend in API request
- Backend includes prior conversation in Gemini prompt
- **Priority Rule:** Always trust what user says in conversation > stored metrics
- **Example:** User says "my heart rate is high" → Adhira listens to you, not just the DB

**Files:**

- `chat_page.dart` - Builds history before API call
- `health_assistant_api_service.dart` - Accepts and sends history
- `backend/main.py` - Includes history in prompt

**Result:** Full conversational context. Adhira remembers what you said and addresses your concerns.

---

## 🏗️ Architecture

```
User Types Message
        ↓
chat_page.dart (_handleSend)
  ├─ Extract last 6 messages as history
  ├─ Get Supabase user ID
  └─ Call sendMessage(query, userId, history)
        ↓
health_assistant_api_service.dart
  └─ POST to /health/assistant with:
       {query, user_id, history}
        ↓
backend/main.py (/health/assistant)
  ├─ Extract query, user_id, history from request
  ├─ Fetch health metrics for user_id (if provided)
  ├─ Build context: "Health: bp=140/90, hr=85, ..."
  ├─ Include history: "user: ...\nassistant: ..."
  ├─ Build full_prompt = ADHIRA_PROMPT + history + context + "User: " + query
  └─ Send to Gemini API
        ↓
Gemini API (gemini-2.5-flash)
  └─ Generate response respecting ADHIRA_PROMPT rules
        ↓
Response returned to Flutter
  └─ Display in chat with typing indicator
```

---

## 📋 ADHIRA_PROMPT (Current)

```
You are Adhira, a warm motherly health companion.
Rules: Max 2 sentences. No diagnosis. No bullet points. Be caring but concise.
Priority: Always trust what the user says in conversation over stored health metrics.
Metrics are background context only — if user reports a symptom, address that symptom directly.
```

---

## 🔄 Data Flow Example

**User:** "my heart rate has been high lately"

Backend builds:

```
ADHIRA_PROMPT
Prior conversation: [empty]
Health: blood_pressure=140/90, blood_sugar=110, heart_rate=85, sleep_hours=6.5, ...
User: my heart rate has been high lately
```

**Adhira:** "Oh dear, I understand you're feeling your heart rate has been high lately. It's always a good idea to chat with your doctor when you notice changes like that."

---

## 🚀 Upcoming Plans

### Phase 4: Context Window Management

- Implement smart pruning of old messages (currently takes last 6)
- Add conversation summarization for long chats
- Optimize token usage for API efficiency

### Phase 5: Health Action Triggers

- Detect when user mentions concerning symptoms
- Surface relevant health tips or reminders
- Integration with health tracking (set reminders, log metrics)

### Phase 6: Persistent Chat History

- Save conversations to Supabase
- Retrieve previous chats
- Build long-term user health insights

### Phase 7: Voice Integration

- Voice input for queries
- Adhira's voice responses (TTS)

---

## 📁 Key Files

| File                                             | Purpose                                          |
| ------------------------------------------------ | ------------------------------------------------ |
| `lib/pages/chat_page.dart`                       | Chat UI, message display, history building       |
| `lib/services/health_assistant_api_service.dart` | API calls to backend                             |
| `backend/main.py`                                | `/health/assistant` endpoint, Gemini integration |
| `backend/db.py`                                  | Supabase client initialization                   |

---

## 🛠️ Testing

**Current Quota:** Gemini API free tier (20 requests/day)

- Resets daily at UTC midnight
- For unlimited testing, upgrade to paid plan

**Test Scenario:**

```
1. User: "my heart rate has been high lately"
   Adhira: [acknowledges concern]

2. User: "what should I do about it?"
   Adhira: [references heart rate from message 1, gives advice]
```

---

## 📝 Notes

- Health metrics are "background context only" — conversation takes priority
- No diagnosis or medical advice; always recommend consulting doctor
- Max 2 sentences keeps responses concise and caring
- History limited to last 5-6 items to avoid token bloat
- Supabase handles user auth, metrics storage, and chat history persistence

---

**Last Updated:** June 4, 2026  
**Status:** Phase 3 Complete ✓  
**Next:** Phase 4 (Context Management)
