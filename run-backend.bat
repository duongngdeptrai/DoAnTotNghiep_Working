@echo off
cd backend

REM Create virtual environment if not exists
if not exist ".venv" (
    echo [*] Creating Python virtual environment...
    python -m venv .venv
)

REM Activate virtual environment
call .venv\Scripts\activate.bat

REM Install dependencies
echo [*] Installing dependencies...
pip install -r requirements.txt

REM Create .env file from example if not exists
if not exist ".env" (
    copy .env.example .env
    echo [!] Created .env. Please edit with TELEGRAM_BOT_TOKEN and SMTP settings if needed.
    echo [!] Press any key to continue...
    pause
)

REM Run FastAPI backend
echo [+] Starting FastAPI backend on http://0.0.0.0:8000
echo [*] WebSocket available at ws://localhost:8000/ws
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

pause
