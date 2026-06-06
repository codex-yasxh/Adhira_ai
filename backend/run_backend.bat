@echo off
echo Starting Health Assistant Backend Server...
echo.

REM Check if virtual environment exists
if not exist "venv311\Scripts\activate.bat" (
    echo Creating virtual environment...
    python -m venv venv311
)

REM Activate virtual environment
echo Activating virtual environment...
call venv311\Scripts\activate.bat

REM Install dependencies
echo Installing dependencies...
pip install -r requirements.txt

REM Check if .env file exists in parent directory
if not exist "..\.env" (
    echo Warning: .env file not found in parent directory.
    echo Please create .env file with GOOGLE_API_KEY.
    echo.
)

REM Start the server
echo.
echo Starting uvicorn server on http://localhost:8000
echo Press Ctrl+C to stop the server
echo.
python -u -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
