@echo off
setlocal

set "ROOT=%~dp0"

echo Starting Product Label App...
echo.

where cargo >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Rust cargo was not found in PATH.
  pause
  exit /b 1
)

where npm >nul 2>nul
if errorlevel 1 (
  echo [ERROR] npm was not found in PATH.
  pause
  exit /b 1
)

start "Product Label Backend - Rust" cmd /k "cd /d "%ROOT%backend" && cargo run"
start "Product Label Frontend - Vue" cmd /k "cd /d "%ROOT%frontend" && npm run dev -- --host 0.0.0.0"

echo Backend:  http://localhost:9000
echo Frontend: http://localhost:5173
echo.
echo Two app windows were started. Close those windows to stop servers.
echo.
timeout /t 3 >nul
start "" "http://localhost:5173"

endlocal
