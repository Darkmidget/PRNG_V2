# Auto-scan COM ports and collect 100,000 samples
# ============================================================================

param(
    [int]$Count = 100000,
    [string]$OutputCSV = "random_data_100k.csv"
)

Write-Host ""
Write-Host "============= AUTO-SCAN COM PORTS =============" -ForegroundColor Cyan
Write-Host "Looking for FPGA on available COM ports..."
Write-Host ""

$found = $false
$working_port = $null

# Try ports 1-20
for ($i = 1; $i -le 20; $i++) {
    $port_name = "COM$i"
    Write-Host "Testing $port_name..." -NoNewline
    
    try {
        $port = New-Object System.IO.Ports.SerialPort($port_name, 115200, 'None', 8, 'One')
        $port.ReadTimeout = 2000
        $port.Open()
        
        # Try to read a character
        $test_char = $null
        try {
            $test_char = $port.ReadChar()
        } catch {}
        
        $port.Close()
        $port.Dispose()
        
        if ($test_char) {
            Write-Host " [FOUND DATA!]" -ForegroundColor Green
            $working_port = $port_name
            $found = $true
            break
        } else {
            Write-Host " [OPEN but no data]" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " [closed]" -ForegroundColor Gray
    }
}

Write-Host ""

if (-not $found) {
    Write-Host "[ERROR] No FPGA response on any COM port!" -ForegroundColor Red
    Write-Host ""
    Write-Host "TROUBLESHOOTING:" -ForegroundColor Yellow
    Write-Host "1. Confirm FPGA USB cable is connected"
    Write-Host "2. Check Device Manager > Ports (COM & LPT)"
    Write-Host "3. Ensure FPGA is programmed with ring_osc.bit"
    Write-Host "4. Verify SW[0] is slid RIGHT (oscillator enabled)"
    Write-Host "5. Check LED[0] and LED[1] are lit/blinking"
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "========== COLLECTING FROM $working_port ==========" -ForegroundColor Green
Write-Host "Collecting $Count samples... (takes ~6 seconds)"
Write-Host ""

$data = @()
$collected = 0
$start = Get-Date

try {
    $port = New-Object System.IO.Ports.SerialPort($working_port, 115200, 'None', 8, 'One')
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
                    Write-Host "  $pct% ($collected/$Count)" -ForegroundColor Cyan
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
Write-Host "======== SAVING TO CSV ========" -ForegroundColor Green
$data | Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding UTF8

# Verify
$csv_data = Import-Csv -Path $OutputCSV
$row_count = ($csv_data | Measure-Object).Count

Write-Host ""
Write-Host "========== SUCCESS ==========" -ForegroundColor Green
Write-Host "Samples:     $collected" -ForegroundColor Green
Write-Host "CSV Rows:    $row_count" -ForegroundColor Green
Write-Host "Time:        $([math]::Round($elapsed.TotalSeconds, 2))s" -ForegroundColor Green
Write-Host "Rate:        $([math]::Round($collected/$elapsed.TotalSeconds, 0)) samples/sec" -ForegroundColor Green
Write-Host "Output:      $OutputCSV" -ForegroundColor Green
Write-Host "File Size:   $([math]::Round((Get-Item $OutputCSV).Length/1KB, 1)) KB" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green
Write-Host ""

if ($row_count -eq $Count) {
    Write-Host "COMPLETE: 100,000 random numbers collected!" -ForegroundColor Green
} else {
    Write-Host "WARNING: Only $row_count rows (expected $Count)" -ForegroundColor Yellow
}
