# ADHIRA - Adaptive Digital Health & Intelligence Response Assistant

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python](https://img.shields.io/badge/Python-3.8+-blue.svg)](https://www.python.org/downloads/)
[![FastAPI](https://img.shields.io/badge/FastAPI-009688.svg?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![React](https://img.shields.io/badge/React-61DAFB.svg?logo=react&logoColor=black)](https://reactjs.org/)
[![Supabase](https://img.shields.io/badge/Supabase-181818.svg?logo=supabase&logoColor=white)](https://supabase.com/)

ADHIRA is an intelligent health assistant powered by Google's Gemini AI, designed to provide personalized health-related assistance and information. It combines advanced natural language processing with a user-friendly interface to deliver accurate and helpful health guidance.

## 🚀 Tech Stack

### Frontend
- **React** - A JavaScript library for building user interfaces
- **Vite** - Next Generation Frontend Tooling
- **Tailwind CSS** - A utility-first CSS framework
- **Web Speech API** - For browser-based speech recognition and synthesis
- **React Query** - Data fetching and state management

### Backend
- **FastAPI** - Modern, fast (high-performance) web framework for building APIs
- **Python 3.8+** - Core programming language
- **Google Gemini AI** - Advanced AI/ML capabilities
- **Groq** - High-performance inference engine for AI models
- **Twilio** - For SMS and voice communication

### Database & Storage
- **Supabase** - Open source Firebase alternative for database and authentication
- **PostgreSQL** - Powerful, open source object-relational database system

### DevOps & Tools
- **Docker** - Containerization
- **Git** - Version control
- **GitHub Actions** - CI/CD pipeline
- **Poetry** - Python dependency management

## 🌟 Features

- **AI-Powered Health Assistance**: Leverages Google's Gemini AI and Groq for intelligent, context-aware responses
- **Voice Interaction**: Built-in Web Speech API integration for voice commands and responses
- **Multi-channel Communication**: Twilio integration for SMS and voice call capabilities
- **Real-time Updates**: WebSocket support for live data streaming
- **Secure Authentication**: JWT-based authentication with Supabase
- **Responsive Design**: Mobile-first approach with Tailwind CSS
- **RESTful API**: Well-documented FastAPI backend

## 🚀 Quick Start

### Prerequisites

- Python 3.8+
- Node.js 16+ (for frontend)
- Docker (optional)
- Google API Key with Gemini AI access
- Supabase project
- Twilio account (for SMS/voice features)
- Groq API key

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/health-assistant-adhira.git
   cd health-assistant-adhira
   ```

2. **Set up Python environment**
   ```bash
   # Using Poetry (recommended)
   pip install poetry
   poetry install

   # Or with virtualenv
   python -m venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   pip install -r requirements.txt
   ```

3. **Set up frontend dependencies**
   ```bash
   cd frontend
   npm install
   cd ..
   ```

4. **Configure environment variables**
   - Copy `.env.example` to `.env` in both root and backend directories
   - Update with your API keys and configuration:
     ```
     # Backend .env
     GOOGLE_API_KEY=your_google_api_key
     GROQ_API_KEY=your_groq_api_key
     SUPABASE_URL=your_supabase_url
     SUPABASE_KEY=your_supabase_key
     TWILIO_ACCOUNT_SID=your_twilio_sid
     TWILIO_AUTH_TOKEN=your_twilio_token
     TWILIO_PHONE_NUMBER=your_twilio_number
     ```

### Running with Docker (Recommended)

```bash
docker-compose up --build
```

### Running Manually

1. **Start the backend server**
   ```bash
   cd backend
   uvicorn main:app --reload
   ```

2. **In a new terminal, start the frontend**
   ```bash
   cd frontend
   npm run dev
   ```

3. Open your browser and navigate to `http://localhost:5173`

## 🛠️ Project Structure

```
health-assistant-adhira/
├── backend/              # FastAPI backend
│   ├── app/             # Application code
│   │   ├── api/         # API routes
│   │   ├── core/        # Core functionality
│   │   ├── models/      # Database models
│   │   ├── services/    # Business logic
│   │   └── utils/       # Utility functions
│   ├── tests/           # Test files
│   ├── main.py          # Application entry point
│   └── requirements.txt # Python dependencies
├── frontend/            # React frontend
│   ├── public/          # Static files
│   ├── src/             # Source code
│   │   ├── components/  # React components
│   │   ├── hooks/       # Custom React hooks
│   │   ├── services/    # API services
│   │   └── styles/      # Global styles
│   └── package.json     # Frontend dependencies
├── docker/              # Docker configuration
├── .github/             # GitHub Actions workflows
└── docs/                # Documentation
```

## 🔍 API Documentation

Once the backend is running, visit:
- API Docs: `http://localhost:8000/docs`
- Redoc: `http://localhost:8000/redoc`

## 🤖 Using the AI Assistant

1. **Web Interface**:
   - Open the web app in your browser
   - Use the chat interface to type or speak your queries
   - The assistant will respond using Gemini AI and Groq

2. **Voice Commands**:
   - Click the microphone icon to activate voice input
   - Speak your health-related queries
   - The assistant will respond with voice output

3. **SMS Integration**:
   - Send an SMS to your Twilio number
   - The assistant will process your query and respond via SMS

## 📝 Environment Variables

Create a `.env` file in the backend directory with the following variables:

```env
# Google Gemini
GOOGLE_API_KEY=your_google_api_key

# Groq
GROQ_API_KEY=your_groq_api_key

# Supabase
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_key

# Twilio
TWILIO_ACCOUNT_SID=your_twilio_sid
TWILIO_AUTH_TOKEN=your_twilio_token
TWILIO_PHONE_NUMBER=your_twilio_number

# App Settings
ENVIRONMENT=development
DEBUG=True
ALLOWED_ORIGINS=http://localhost:5173,http://localhost:8000
```

## 🧪 Testing

Run the test suite:

```bash
# Backend tests
cd backend
pytest

# Frontend tests
cd frontend
npm test
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Google for the Gemini AI
- Groq for the high-performance inference
- Supabase for the backend services
- Twilio for communication APIs
- The open-source community for various libraries and tools

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request
