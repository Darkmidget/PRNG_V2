param([switch]$Program)

$ErrorActionPreference = "Continue"
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
cd $projectRoot

Write-Host "=== FPGA Programming Script ===" -ForegroundColor Cyan
Write-Host "Current directory: $(Get-Location)" -ForegroundColor Cyan
Write-Host ""

# Check if bitstream exists in root
if (Test-Path "ring_osc.bit") {
    Write-Host "[OK] Found ring_osc.bit in project root" -ForegroundColor Green
    $root_bitstream_size = (Get-Item "ring_osc.bit").Length
    Write-Host "  Size: $root_bitstream_size bytes"
    
    # Create directory structure if needed
    $target_dir = "build\cmod_a7_project.runs\impl_1"
    Write-Host "[*] Creating target directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $target_dir -Force -ErrorAction SilentlyContinue | Out-Null
    
    # Copy bitstream
    $target_path = $target_dir + "\ring_osc.bit"
    Write-Host "[*] Copying bitstream to: $target_path" -ForegroundColor Yellow
    Copy-Item "ring_osc.bit" $target_path -Force
    
    if (Test-Path $target_path) {
        $copied_size = (Get-Item $target_path).Length
        Write-Host "[OK] Bitstream copied successfully ($copied_size bytes)" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Failed to copy bitstream!" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[ERROR] ring_osc.bit not found in project root!" -ForegroundColor Red
    Write-Host "Please run the build first." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[*] Running deploy script..." -ForegroundColor Cyan
& ".\deploy.ps1" -SkipBuild
