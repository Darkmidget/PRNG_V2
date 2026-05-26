# FPGA Data Collection - 100,000 Samples
# ============================================================================
# Run this AFTER programming the FPGA with ring_osc.bit
# The script will auto-scan COM ports and collect data
# ============================================================================

param(
    [int]$Count = 100000,
    [string]$OutputCSV = "random_data_100k.csv"
)

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "      FPGA DATA COLLECTION (100,000 SAMPLES)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Auto-scan COM ports
Write-Host "Scanning for FPGA on COM ports..." -ForegroundColor Yellow
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
                Write-Host "[FOUND] $port_name sends data!" -ForegroundColor Green
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
    Write-Host "[ERROR] No FPGA detected!" -ForegroundColor Red
    Write-Host ""
    Write-Host "REQUIRED ACTIONS:" -ForegroundColor Yellow
    Write-Host "1. Open Vivado"
    Write-Host "2. Open Tools > Program Device"
    Write-Host "3. Select: ring_osc.bit (in current folder)"
    Write-Host "4. Click Program"
    Write-Host "5. Slide SW[0] RIGHT on extension board"
    Write-Host "6. Run this script again"
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "[COLLECTING] Starting data collection from $found_port..." -ForegroundColor Green
Write-Host ""

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
                    Write-Host "  $pct% ($collected / $Count samples)" -ForegroundColor Cyan
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

# Save to CSV
Write-Host ""
Write-Host "[SAVING] Writing $($data.Count) samples to CSV..." -ForegroundColor Yellow
$data | Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding UTF8

# Verify
$csv_data = Import-Csv -Path $OutputCSV
$row_count = ($csv_data | Measure-Object).Count
$file_size = (Get-Item $OutputCSV).Length

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "            COLLECTION COMPLETE!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Statistics:" -ForegroundColor Green
Write-Host "  Total Samples:      $collected" -ForegroundColor Green
Write-Host "  CSV Rows:           $row_count" -ForegroundColor Green
Write-Host "  Time Elapsed:       $([math]::Round($elapsed.TotalSeconds, 2)) seconds" -ForegroundColor Green
Write-Host "  Sample Rate:        $([math]::Round($collected/$elapsed.TotalSeconds, 0)) samples/sec" -ForegroundColor Green
Write-Host "  File Size:          $([math]::Round($file_size/1KB, 1)) KB" -ForegroundColor Green
Write-Host "  Output File:        $OutputCSV" -ForegroundColor Green
Write-Host ""

if ($row_count -eq $Count) {
    Write-Host "SUCCESS!" -ForegroundColor Green
    Write-Host "100,000 random numbers successfully collected in $OutputCSV" -ForegroundColor Green
} else {
    Write-Host "WARNING: Only $row_count rows (expected $Count)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "First 10 samples:" -ForegroundColor Cyan
$csv_data | Select-Object -First 10 | Format-Table Index, HexValue, DecimalValue -AutoSize

Write-Host ""
