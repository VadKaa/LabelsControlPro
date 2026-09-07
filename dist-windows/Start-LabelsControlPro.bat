@echo off
setlocal
set "APP_ROOT=%~dp0"
set "PORT=9000"
start "" "http://localhost:9000"
"%~dp0LabelsControlPro.exe"
endlocal
