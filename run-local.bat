@echo off
setlocal

set "ROOT=%~dp0"

echo Starting LabelsControlPro as one local Windows app...
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

echo Building frontend...
cd /d "%ROOT%frontend"
call npm run build
if errorlevel 1 (
  echo [ERROR] Frontend build failed.
  pause
  exit /b 1
)

set "APP_ROOT=%ROOT%"
set "STATIC_DIR=%ROOT%frontend\dist"
set "SCRIPTS_DIR=%ROOT%scripts"
set "PRINTER_DIR=%ROOT%printer"
set "TEMPLATES_DIR=%ROOT%printer\Templates"
set "PORT=9000"

echo.
echo App: http://localhost:9000
echo.
echo Starting backend and opening browser...
timeout /t 2 >nul
start "" "http://localhost:9000"

cd /d "%ROOT%backend"
cargo run

endlocal
