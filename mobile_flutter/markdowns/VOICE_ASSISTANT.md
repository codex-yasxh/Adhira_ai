# Voice Assistant

## Scope

Voice Mode provides a full-screen conversational voice experience using speech-to-text, the backend health assistant endpoint, and text-to-speech playback.

## Files

| Purpose | File |
| --- | --- |
| Voice screen | `mobile_flutter/lib/pages/voice_assistant_page.dart` |
| Chat entry point | `mobile_flutter/lib/pages/chat_page.dart` |
| API service | `mobile_flutter/lib/services/health_assistant_api_service.dart` |
| Backend endpoint | `backend/main.py` (`/health/assistant`) |

## Entry Point

Voice Mode opens from the chat input through `VoiceAssistantPage`.

## State Machine

The voice screen uses `_VoiceState`:

- `idle`
- `listening`
- `thinking`
- `speaking`

Each state drives the orb color, waveform animation, and user interaction behavior.

## Flow

1. User taps the orb.
2. App starts speech recognition.
3. Partial transcript updates on screen.
4. After a short pause, the transcript is sent to `/health/assistant`.
5. Backend returns Adhira's response.
6. App speaks the response with `flutter_tts`.
7. On completion, the state returns to idle.

## Conversation Memory

Voice Mode keeps an in-memory `_history` list.

- User and assistant turns are appended after every reply.
- The list is trimmed after it grows past 12 items.
- History is sent to the same backend chat endpoint used by text chat.

## Current Limits

- Voice history is not shared with the main chat screen.
- Voice history is not persisted.
- If speech recognition captures an unintended partial phrase, the debounce can send it automatically.
- No medicine names are currently passed from Voice Mode, unlike text chat.
- STT/TTS availability depends on device support and permissions.

## Suggested Next Steps

- Share conversation state between text chat and voice mode.
- Pass `MedicineStore.instance.names` to voice API calls.
- Add an explicit confirm/send control for users who want more control than debounce.
- Persist voice/chat history if long-term memory is desired.
- Add clearer permission recovery UI when STT is unavailable.

