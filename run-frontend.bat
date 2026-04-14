@echo off
cd frontend

REM Install dependencies if needed
if not exist "node_modules" (
    echo [*] Installing npm dependencies...
    call npm install
)

REM Create .env file from example if not exists
if not exist ".env" (
    copy .env.example .env
    echo [+] Created .env
)

REM Run Vite development server
echo [+] Starting React frontend on http://localhost:5173
call npm run dev

pause
