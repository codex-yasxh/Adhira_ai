# ADHIRA

## Adaptive Digital Health & Intelligence Response Assistant

ADHIRA is an AI-powered health companion designed to make healthcare guidance, health monitoring, emergency assistance, and voice interaction accessible from a single mobile experience.

Built with Flutter, FastAPI, Gemini AI, and Supabase, ADHIRA combines conversational intelligence with practical health tools such as health metric tracking, medical report analysis, SOS alerts, medication conflict detection, and voice-first interactions.

---

## Vision

Healthcare apps are often fragmented.

One app tracks health metrics.

Another stores reports.

Another handles reminders.

Another provides emergency support.

ADHIRA aims to bring these capabilities together into a single intelligent assistant that users can talk to naturally.

---

## Core Features

### AI Health Assistant

* Gemini-powered conversational health assistant
* Context-aware conversations
* Follow-up question support
* Personalized health guidance

### Voice Interaction

* Speech-to-Text (STT)
* Text-to-Text (TTT)
* Text-to-Speech (TTS)
* Dedicated Voice Mode

### Health Metrics Dashboard

Track:

* Blood Pressure
* Blood Sugar
* Heart Rate
* Sleep Hours
* Steps
* Body Temperature
* Oxygen Saturation (SpO₂)
* Respiratory Rate
* Weight
* BMI

Metrics are stored securely using Supabase.

---

### Medical Report Analysis

Upload:

* Blood reports
* Lab reports
* Prescriptions
* Medical PDFs
* Medical images

ADHIRA can:

* Extract report information
* Explain findings
* Summarize results
* Answer follow-up questions

---

### Medicine Conflict Detection

Analyze:

* Medicines
* Food interactions
* Potential conflicts

Designed to help users identify possible medication-related risks.

---

### Emergency SOS System

Built specifically for fast emergency communication.

Features:

* One-tap SOS
* Emergency contact management
* Automatic SMS alerts
* Live location sharing
* Delivery tracking
* Android-native SMS delivery

No external SMS gateway required.

---

### Smart Reminders

Manage:

* Medication reminders
* Health reminders
* Daily routines

---

## Tech Stack

### Mobile App

* Flutter
* Dart

### Backend

* FastAPI
* Python

### AI

* Google Gemini 2.5 Flash

### Database & Authentication

* Supabase
* PostgreSQL

### Location & Device Features

* Geolocator
* Native Android SMS APIs
* Speech Recognition
* Text-to-Speech

---

## Repository Structure

```text
adhira/
├── mobile_flutter/
│   ├── lib/
│   ├── android/
│   ├── ios/
│   └── pubspec.yaml
│
├── backend/
│   ├── main.py
│   ├── db.py
│   ├── requirements.txt
│   └── services/
│
├── supabase/
│   ├── migrations/
│   └── schema/
│
├── docs/
│
├── .env.example
├── .gitignore
└── README.md
```

---

## Environment Variables

Create a `.env` file using `.env.example`.

Example:

```env
GOOGLE_API_KEY=

SUPABASE_URL=
SUPABASE_KEY=

PORT=8000
ENVIRONMENT=development
```

Never commit:

* Real API Keys
* Supabase Service Keys
* Secrets
* Tokens

---

## Local Development

### Backend

```bash
cd backend

python -m venv .venv

pip install -r requirements.txt

uvicorn main:app --reload
```

Backend:

```text
http://localhost:8000
```

API Docs:

```text
http://localhost:8000/docs
```

---

### Flutter App

```bash
cd mobile_flutter

flutter pub get

flutter run
```

---

## Current Development Status

### Completed

* AI Chat Assistant
* Health Metrics
* Dashboard
* Authentication
* Speech-to-Text
* Text-to-Speech
* Voice Mode
* Medical Report Analysis
* SOS SMS Alerts
* Reminder System

### In Progress

* Speech-to-Speech (STS)
* Advanced Health Insights
* Improved Design System
* Report History
* Analytics

---

## Security

ADHIRA is intended as a health-assistance platform and should not replace professional medical advice, diagnosis, or treatment.

Users should consult qualified healthcare professionals for medical decisions.

---

## License

MIT License

---

## Built With

* Flutter
* FastAPI
* Gemini AI
* Supabase

Designed and developed as part of the ADHIRA mission to create a practical AI-powered healthcare companion.
