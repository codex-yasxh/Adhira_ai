#!/bin/bash

echo "Starting Health Assistant Backend Server..."
echo

# Check if virtual environment exists
if [ ! -d "venv311" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv311
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv311/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install -r requirements.txt

# Check if .env file exists in parent directory
if [ ! -f "../.env" ]; then
    echo "Warning: .env file not found in parent directory."
    echo "Please create .env file with GOOGLE_API_KEY."
    echo
fi

# Start the server
echo
echo "Starting uvicorn server on http://localhost:8000"
echo "Press Ctrl+C to stop the server"
echo
python3 -u -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
