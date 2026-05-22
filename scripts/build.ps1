#!/usr/bin/env powershell
# Simple Build and Upload Script
# Usage: .\build.ps1 [options]

param(
    [switch]$Monitor = $false,
    [switch]$Clean = $false,
    [string]$Port = "COM8"
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$pio = Join-Path $projectRoot "venv\Scripts\platformio.exe"

Set-Location $projectRoot

Write-Host ""
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "Feather M4 - Game of Life Build" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

if ($Clean) {
    Write-Host "[1] Cleaning build..." -ForegroundColor Yellow
    & $pio run -e feather_m4 --target clean | Out-Null
    Write-Host "[1] Clean [OK]" -ForegroundColor Green
}

Write-Host "[2] Building and uploading..." -ForegroundColor Yellow
& $pio run -e feather_m4 --target upload --upload-port $Port

Write-Host "[2] Upload [OK]" -ForegroundColor Green

if ($Monitor) {
    Write-Host "[3] Opening serial monitor..." -ForegroundColor Yellow
    Write-Host "    (Press Ctrl+C to exit)" -ForegroundColor Gray
    & $pio device monitor -p $Port --baud 115200
} else {
    Write-Host "[3] Monitor skipped (use -Monitor to enable)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Complete!" -ForegroundColor Green
Write-Host ""
