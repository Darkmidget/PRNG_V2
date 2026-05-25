# FPGA Deployment Script
# Usage: .\deploy.ps1
#        .\deploy.ps1 -SkipBuild     (only program)
#        .\deploy.ps1 -BuildOnly     (only build)

param(
    [switch]$SkipBuild,
    [switch]$BuildOnly,
    [switch]$Flash
)

Set-Location "$PSScriptRoot\..\.."

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  FPGA Deployment - CMOD A7" -ForegroundColor Cyan
Write-Host "  One Command Build & Program" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Setup Vivado
Write-Host ">> Setting up Vivado..." -ForegroundColor Yellow
$vivadoPaths = @(
    "C:\AMDDesignTools\2025.2\Vivado\bin",
    "C:\AMDDesignTools\2024.2\Vivado\bin",
    "C:\Xilinx\Vivado\2023.2\bin",
    "C:\Xilinx\Vivado\2023.1\bin"
)

$found = $false
foreach ($p in $vivadoPaths) {
    if (Test-Path "$p\vivado.bat") {
        $env:PATH = "$p;" + $env:PATH
        Write-Host "   + Found Vivado at: $p" -ForegroundColor Green
        $found = $true
        break
    }
}

if (-not $found) {
    Write-Host "   X Vivado not found!" -ForegroundColor Red
    exit 1
}

$v = & vivado -version 2>&1 | Select-Object -First 1
Write-Host "   i $v" -ForegroundColor Cyan

# Clean
if (-not $SkipBuild) {
    Write-Host "`n>> Cleaning..." -ForegroundColor Yellow
    Get-Process | Where-Object {$_.ProcessName -like "*vivado*"} | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    if (Test-Path "build\cmod_a7_project.runs") {
        Remove-Item "build\cmod_a7_project.runs" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "   + Cleaned" -ForegroundColor Green
    }
}

# Build
if (-not $SkipBuild) {
    Write-Host "`n>> Building (2-5 min)..." -ForegroundColor Yellow
    $start = Get-Date
    $out = & vivado -mode batch -source scripts/build_tools/build.tcl 2>&1
    $time = (Get-Date) - $start
    
    if ($LASTEXITCODE -eq 0 -and $out -match "Build completed successfully") {
        Write-Host "   + Built in $([math]::Round($time.TotalSeconds, 1))s" -ForegroundColor Green
    } else {
        Write-Host "   X Build failed!" -ForegroundColor Red
        $out | Select-Object -Last 50
        exit 1
    }
    
    if (Test-Path "build\cmod_a7_project.runs\impl_1\switch_display.bit") {
        Write-Host "   + Bitstream OK" -ForegroundColor Green
    }
}

# Program
if (-not $BuildOnly) {
    $mode = if ($Flash) { "Flash (Permanent)" } else { "SRAM (Volatile)" }
    Write-Host "`n>> Programming FPGA ($mode)..." -ForegroundColor Yellow
    $start = Get-Date
    
    $tclScript = if ($Flash) { "scripts/build_tools/flash.tcl" } else { "scripts/build_tools/program.tcl" }
    $out = & vivado -mode batch -source $tclScript 2>&1
    $time = (Get-Date) - $start
    
    if ($LASTEXITCODE -eq 0 -and $out -match "Programming completed successfully|Flash programming completed successfully") {
        Write-Host "   + Programmed in $([math]::Round($time.TotalSeconds, 1))s" -ForegroundColor Green
    } else {
        if ($out -match "No hardware target") {
            Write-Host "   X No FPGA detected!" -ForegroundColor Red
            Write-Host "     Check USB, driver, and that no other app is using FPGA"
        } else {
            Write-Host "   X Programming failed!" -ForegroundColor Red
            $out | Select-Object -Last 30
        }
        exit 1
    }
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green
Write-Host "Test: Flip switches (0-1023)" -ForegroundColor Cyan
Write-Host "      See value on 7-segment displays`n" -ForegroundColor Cyan
