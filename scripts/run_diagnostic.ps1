param(
    [switch]$Monitor = $false
)

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$mainFile = "src\main.cpp"
$mainBackup = "src\main.cpp.prod"
$diagnosticFile = "src\diagnostic_test.cpp"

Write-Host "FEATHER M4 DIAGNOSTIC TEST BUILD" -ForegroundColor Cyan
Write-Host ""

# Step 1: Backup production main.cpp
Write-Host "Step 1: Backing up production code..." -ForegroundColor Yellow
if (Test-Path $mainFile) {
    Copy-Item $mainFile $mainBackup -Force
    Write-Host "  OK: Backed up $mainFile to $mainBackup" -ForegroundColor Green
}
else {
    Write-Host "  ERROR: $mainFile not found!" -ForegroundColor Red
    exit 1
}

# Step 2: Copy diagnostic as main.cpp
Write-Host "Step 2: Installing diagnostic as main.cpp..." -ForegroundColor Yellow
if (Test-Path $diagnosticFile) {
    Copy-Item $diagnosticFile $mainFile -Force
    Write-Host "  OK: Copied $diagnosticFile to $mainFile" -ForegroundColor Green
}
else {
    Write-Host "  ERROR: $diagnosticFile not found!" -ForegroundColor Red
    exit 1
}

# Step 3: Clean and build
Write-Host "Step 3: Building diagnostic firmware..." -ForegroundColor Yellow
Write-Host ""

venv\Scripts\platformio.exe run -e feather_m4 --target clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "Clean failed!" -ForegroundColor Red
    Copy-Item $mainBackup $mainFile -Force
    exit 1
}

venv\Scripts\platformio.exe run -e feather_m4 --target upload --upload-port COM8
if ($LASTEXITCODE -ne 0) {
    Write-Host "Build/Upload FAILED!" -ForegroundColor Red
    Copy-Item $mainBackup $mainFile -Force
    exit 1
}

Write-Host ""
Write-Host "  OK: Diagnostic firmware uploaded" -ForegroundColor Green

# Step 4: Monitor serial output
if ($Monitor) {
    Write-Host ""
    Write-Host "Step 4: Monitoring serial output..." -ForegroundColor Yellow
    Write-Host "Press Ctrl+C to stop" -ForegroundColor Cyan
    Write-Host ""
    
    venv\Scripts\platformio.exe device monitor -p COM8 --baud 115200
}

# Step 5: Restore production code
Write-Host ""
Write-Host "Step 5: Restoring production code..." -ForegroundColor Yellow
Copy-Item $mainBackup $mainFile -Force
Write-Host "  OK: Restored production code" -ForegroundColor Green

Write-Host ""
Write-Host "DIAGNOSTIC TEST COMPLETE" -ForegroundColor Cyan
Write-Host ""
