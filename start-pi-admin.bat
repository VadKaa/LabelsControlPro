@echo off
setlocal

rem Start an elevated PowerShell window in this project and run the Pi agent.
set "PROJECT_DIR=%~dp0"
set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$project = '%PROJECT_DIR%';" ^
  "$quotedProject = '''' + ($project -replace '''','''''') + '''';" ^
  "$command = 'Set-Location -LiteralPath ' + $quotedProject + '; pi';" ^
  "Start-Process -FilePath 'powershell.exe' -Verb RunAs -WorkingDirectory $project -ArgumentList @('-NoExit','-NoProfile','-ExecutionPolicy','Bypass','-Command',$command)"

if errorlevel 1 (
  echo Failed to start elevated PowerShell.
  pause
)
