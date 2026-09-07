param(
    [string]$OutputDir = "dist-windows"
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Out = Join-Path $Root $OutputDir

Write-Host "Building LabelsControlPro for Windows..." -ForegroundColor Cyan

if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    throw "Rust cargo was not found in PATH. Install Rust from https://rustup.rs/"
}
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw "npm was not found in PATH. Install Node.js from https://nodejs.org/"
}

Write-Host "`n[1/4] Building frontend..." -ForegroundColor Yellow
Push-Location (Join-Path $Root "frontend")
try {
    npm ci
    npm run build
}
finally {
    Pop-Location
}

Write-Host "`n[2/4] Building backend..." -ForegroundColor Yellow
Push-Location (Join-Path $Root "backend")
try {
    cargo build --release
}
finally {
    Pop-Location
}

Write-Host "`n[3/4] Creating package folder..." -ForegroundColor Yellow
if (Test-Path $Out) {
    Remove-Item $Out -Recurse -Force
}
New-Item -ItemType Directory -Path $Out | Out-Null

Copy-Item (Join-Path $Root "backend\target\release\backend.exe") (Join-Path $Out "LabelsControlPro.exe")
Copy-Item (Join-Path $Root "frontend") (Join-Path $Out "frontend") -Recurse
Remove-Item (Join-Path $Out "frontend\node_modules") -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $Out "frontend\src") -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $Out "frontend\public") -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $Out "frontend\package*.json") -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $Out "frontend\*.ts") -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $Out "frontend\*.html") -Force -ErrorAction SilentlyContinue
Copy-Item (Join-Path $Root "scripts") (Join-Path $Out "scripts") -Recurse
Copy-Item (Join-Path $Root "printer") (Join-Path $Out "printer") -Recurse

@"
@echo off
setlocal
set "APP_ROOT=%~dp0"
set "PORT=9000"
start "" "http://localhost:9000"
"%~dp0LabelsControlPro.exe"
endlocal
"@ | Set-Content -Path (Join-Path $Out "Start-LabelsControlPro.bat") -Encoding ASCII

@"
LabelsControlPro Windows build

Run:
  Start-LabelsControlPro.bat

Open:
  http://localhost:9000

Included folders:
  frontend\dist  - web UI served by LabelsControlPro.exe
  scripts        - PowerShell/Python print scripts
  printer        - printer templates and Brother driver tools
"@ | Set-Content -Path (Join-Path $Out "README-WINDOWS.txt") -Encoding UTF8

Write-Host "`n[4/4] Done." -ForegroundColor Green
Write-Host "Package created at: $Out" -ForegroundColor Green
Write-Host "Run: $Out\Start-LabelsControlPro.bat" -ForegroundColor Green
