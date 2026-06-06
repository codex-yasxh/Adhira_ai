# Quick Start - Backend Server

## Option 1: Windows (Recommended)

Run the batch file:

```cmd
run_backend.bat
```

## Option 2: Manual Windows Commands

```cmd
# Create virtual environment (if not exists)
python -m venv venv311

# Activate virtual environment
venv311\Scripts\activate.bat

# Install dependencies
pip install -r requirements.txt

# Start server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## Option 3: Linux/Mac

```bash
# Make script executable
chmod +x run_backend.sh

# Run the script
./run_backend.sh
```

## Option 4: Manual Linux/Mac Commands

```bash
# Create virtual environment (if not exists)
python3 -m venv venv311

# Activate virtual environment
source venv311/bin/activate

# Install dependencies
pip install -r requirements.txt

# Start server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## Prerequisites

- Python 3.8+ installed
- `.env` file in parent directory with `GOOGLE_API_KEY`
- Internet connection for API calls

## Server Access

Once running, the server will be available at:

- <http://localhost:8000>
- API Documentation: <http://localhost:8000/docs>
