# PowerShell script to start the FastAPI backend server
# Run this script from the backend directory

# Navigate to backend directory (if not already there)
$backendPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $backendPath

Write-Host "Starting Health Assistant Backend Server..." -ForegroundColor Green
Write-Host ""

# Activate virtual environment
if (Test-Path "venv\Scripts\Activate.ps1") {
    Write-Host "Activating virtual environment..." -ForegroundColor Yellow
    & "venv\Scripts\Activate.ps1"
} else {
    Write-Host "Warning: Virtual environment not found. Using system Python." -ForegroundColor Yellow
}

# Check if .env file exists in parent directory
$envPath = Join-Path (Split-Path -Parent $backendPath) ".env"
if (-not (Test-Path $envPath)) {
    Write-Host "Warning: .env file not found. Please create one with GOOGLE_API_KEY." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Starting uvicorn server on http://localhost:8000" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Gray
Write-Host ""

# Start the server
uvicorn main:app --reload --host 0.0.0.0 --port 8000

