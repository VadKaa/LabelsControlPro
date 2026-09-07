Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RequirementsPath = Join-Path $ScriptDir "requirements-brother-ql.txt"

function Test-PythonExe {
    param([string]$PythonPath)
    if (-not $PythonPath) { return $false }
    if ($PythonPath -like "*\WindowsApps\python.exe") { return $false }
    try {
        & $PythonPath --version *> $null
        return ($LASTEXITCODE -eq 0)
    }
    catch {
        return $false
    }
}

function Find-Python {
    $commands = @("py", "python")
    foreach ($command in $commands) {
        $found = Get-Command $command -ErrorAction SilentlyContinue
        if ($found -and (Test-PythonExe -PythonPath $found.Source)) { return $found.Source }
    }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python312\python.exe"),
        (Join-Path $env:ProgramFiles "Python312\python.exe")
    )
    foreach ($candidate in $candidates) {
        if ((Test-Path -LiteralPath $candidate) -and (Test-PythonExe -PythonPath $candidate)) { return $candidate }
    }
    return $null
}

$python = Find-Python
if (-not $python) {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw "Python is not installed and winget was not found. Install Python 3.12 manually from https://www.python.org/downloads/windows/ then run this script again."
    }

    Write-Output "Installing Python 3.12 with winget..."
    winget install --id Python.Python.3.12 -e --source winget --accept-package-agreements --accept-source-agreements
    $python = Find-Python
    if (-not $python) { throw "Python install finished, but python.exe was not found. Open a new terminal and run this script again." }
}

Write-Output "Using Python: $python"
& $python --version
if ($LASTEXITCODE -ne 0) { throw "Python failed to run." }
& $python -m pip install -r $RequirementsPath
if ($LASTEXITCODE -ne 0) { throw "pip install failed." }
Write-Output "[OK] Brother QL raster dependencies installed."
