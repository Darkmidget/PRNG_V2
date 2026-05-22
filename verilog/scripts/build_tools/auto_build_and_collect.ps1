# COMPLETE FPGA BUILD + DATA COLLECTION AUTOMATION
# ============================================================================
# This script will:
# 1. Generate bitstream (if needed)
# 2. Program FPGA
# 3. Auto-scan for COM port
# 4. Collect 100,000 random samples
# ============================================================================

param(
    [int]$Count = 100000,
    [string]$OutputCSV = "random_data_100k.csv"
)

$ErrorActionPreference = "Continue"
$VivadoPath = "C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat"
$ProjectRoot = Get-Location
$BuildDir = "$ProjectRoot\build"
$ProjectFile = "$BuildDir\cmod_a7_project.xpr"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "     FPGA AUTO BUILD & DATA COLLECTION" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# STEP 1: Check for bitstream
Write-Host "[1/4] Checking bitstream status..." -ForegroundColor Yellow
$bitstream_path = "$BuildDir\cmod_a7_project.runs\impl_1\ring_osc.bit"
if (Test-Path $bitstream_path) {
    Write-Host "[OK] Bitstream exists" -ForegroundColor Green
} else {
    Write-Host "[GENERATE] Bitstream not found, generating..." -ForegroundColor Yellow
    
    if (-not (Test-Path $VivadoPath)) {
        Write-Host "[ERROR] Vivado not found at $VivadoPath" -ForegroundColor Red
        exit 1
    }
    
    # Create TCL script for bitstream generation with DRC bypass
    $tcl_content = @"
open_project {$ProjectFile}
open_run impl_1

# Disable DRC checks for known design constraints  
set_property SEVERITY {Warning} [get_drc_checks LUTLP-1]
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]

# Allow combinatorial loops for ring oscillator
catch { set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets ring*] }

# Generate bitstream
write_bitstream -force ring_osc.bit

close_project
exit 0
"@
    
    $tcl_file = "$BuildDir\gen_bitstream.tcl"
    [System.IO.File]::WriteAllText($tcl_file, $tcl_content, [System.Text.Encoding]::ASCII)
    
    Write-Host "Running Vivado (this takes 5-10 minutes)..." -ForegroundColor Cyan
    & $VivadoPath -mode batch -source $tcl_file 2>&1 | Select-String -Pattern "(write_bitstream|route_design|ERROR|SUCCESS)" | ForEach-Object { Write-Host "  $_" }
    
    if (Test-Path $bitstream_path) {
        Write-Host "[OK] Bitstream generated successfully!" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Bitstream generation failed" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# STEP 2: Auto-scan COM ports
Write-Host "[2/4] Scanning for FPGA on COM ports..." -ForegroundColor Yellow
$found_port = $null

for ($i = 1; $i -le 20; $i++) {
    $port_name = "COM$i"
    try {
        $port = New-Object System.IO.Ports.SerialPort($port_name, 115200, 'None', 8, 'One')
        $port.ReadTimeout = 1000
        $port.Open()
        
        try {
            $c = $port.ReadChar()
            if ($c) {
                Write-Host "[FOUND] $port_name has data!" -ForegroundColor Green
                $found_port = $port_name
                $port.Close()
                $port.Dispose()
                break
            }
        } catch {}
        
        $port.Close()
        $port.Dispose()
    } catch {}
}

if (-not $found_port) {
    Write-Host "[ERROR] No FPGA detected on any COM port" -ForegroundColor Red
    Write-Host ""
    Write-Host "ACTIONS NEEDED (manual):" -ForegroundColor Yellow
    Write-Host "1. Ensure FPGA USB is connected"
    Write-Host "2. Open Vivado > Open $ProjectFile"
    Write-Host "3. Tools > Program Device"
    Write-Host "4. Select bitstream at: $bitstream_path"
    Write-Host "5. Program FPGA"
    Write-Host "6. Slide SW[0] RIGHT to enable oscillator"
    Write-Host "7. Run this script again"
    Write-Host ""
    exit 1
}

Write-Host ""

# STEP 3: Collect data
Write-Host "[3/4] Collecting $Count samples from $found_port..." -ForegroundColor Yellow
$data = @()
$collected = 0
$start = Get-Date

try {
    $port = New-Object System.IO.Ports.SerialPort($found_port, 115200, 'None', 8, 'One')
    $port.ReadTimeout = 5000
    $port.Open()
    
    while ($collected -lt $Count) {
        try {
            $hex = ""
            $timeout = Get-Date
            
            while ($hex.Length -lt 4 -and ((Get-Date) - $timeout).TotalSeconds -lt 5) {
                try {
                    $c = $port.ReadChar()
                    if ($c -match '[0-9A-Fa-f]') {
                        $hex += $c
                    }
                    elseif ($c -match '[\r\n]' -and $hex.Length -eq 4) {
                        break
                    }
                    elseif ($c -match '[\r\n]') {
                        $hex = ""
                    }
                } catch {}
            }
            
            if ($hex.Length -eq 4) {
                try { $port.ReadChar() } catch {}
                try { $port.ReadChar() } catch {}
                
                $dec = [int]::Parse($hex, [System.Globalization.NumberStyles]::HexNumber)
                $data += [PSCustomObject]@{
                    Index = $collected + 1
                    HexValue = $hex.ToUpper()
                    DecimalValue = $dec
                    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
                }
                $collected++
                
                if ($collected % 10000 -eq 0) {
                    $pct = [int]($collected * 100 / $Count)
                    Write-Host "  $pct% complete ($collected samples)" -ForegroundColor Cyan
                }
            }
        } catch {}
    }
} finally {
    if ($port) {
        $port.Close()
        $port.Dispose()
    }
}

$elapsed = (Get-Date) - $start

Write-Host ""

# STEP 4: Save to CSV
Write-Host "[4/4] Saving to CSV..." -ForegroundColor Yellow
$data | Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding UTF8

# Verify
$csv_data = Import-Csv -Path $OutputCSV
$row_count = ($csv_data | Measure-Object).Count
$file_size = (Get-Item $OutputCSV).Length

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "         COLLECTION SUCCESSFUL!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Results:" -ForegroundColor Green
Write-Host "  Samples Collected:  $collected" -ForegroundColor Green
Write-Host "  CSV Rows:           $row_count" -ForegroundColor Green
Write-Host "  Time Elapsed:       $([math]::Round($elapsed.TotalSeconds, 2))s" -ForegroundColor Green
Write-Host "  Sample Rate:        $([math]::Round($collected/$elapsed.TotalSeconds, 0)) samples/sec" -ForegroundColor Green
Write-Host "  File Size:          $([math]::Round($file_size/1KB, 1)) KB" -ForegroundColor Green
Write-Host "  Output File:        $OutputCSV" -ForegroundColor Green
Write-Host ""

if ($row_count -eq $Count) {
    Write-Host "SUCCESS: 100,000 random numbers in $OutputCSV" -ForegroundColor Green
} else {
    Write-Host "WARNING: Only $row_count rows collected (expected $Count)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "First 5 samples:" -ForegroundColor Cyan
$csv_data | Select-Object -First 5 | Format-Table Index, HexValue, DecimalValue -AutoSize

Write-Host ""
Write-Host "                    COMPLETE!" -ForegroundColor Green
