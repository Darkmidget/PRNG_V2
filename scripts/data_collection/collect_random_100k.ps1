# ============================================================================
# FPGA RANDOM NUMBER COLLECTOR - 100,000 Samples
# ============================================================================
# Collects random hex values from Ring Oscillator FPGA via UART (COM4)
# Saves to CSV with 100,000 rows
# ============================================================================

param(
    [string]$ComPort = "COM4",
    [int]$Baud = 115200,
    [int]$Count = 100000,
    [string]$OutputCSV = "random_data_100k.csv"
)

Write-Host ""
Write-Host "========== FPGA RANDOM DATA COLLECTOR ==========" -ForegroundColor Cyan
Write-Host "COM Port:   $ComPort @ $Baud baud" -ForegroundColor White
Write-Host "Target:     $Count samples" -ForegroundColor White
Write-Host "Output:     $OutputCSV" -ForegroundColor White
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Open serial port
Write-Host "[1/3] Opening serial connection..." -ForegroundColor Yellow
try {
    $port = New-Object System.IO.Ports.SerialPort($ComPort, $Baud, 'None', 8, 'One')
    $port.ReadTimeout = 5000
    $port.Open()
    Write-Host "[OK] Connected to $ComPort" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Cannot open $ComPort" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 2: Collect data
Write-Host "[2/3] Collecting samples (this will take ~6 seconds)..." -ForegroundColor Yellow
$data = @()
$collected = 0
$start = Get-Date

try {
    while ($collected -lt $Count) {
        try {
            $hex = ""
            $timeout = Get-Date
            
            # Read 4 hex digits
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

# Step 3: Save to CSV
Write-Host "[3/3] Saving to CSV file..." -ForegroundColor Yellow
$data | Export-Csv -Path $OutputCSV -NoTypeInformation -Encoding UTF8

# Summary
Write-Host ""
Write-Host "========== COMPLETE ==========" -ForegroundColor Green
Write-Host "Samples:     $collected (100%)" -ForegroundColor Green
Write-Host "Time:        $([math]::Round($elapsed.TotalSeconds, 2)) sec" -ForegroundColor Green
Write-Host "Rate:        $([math]::Round($collected/$elapsed.TotalSeconds, 0)) samples/sec" -ForegroundColor Green
Write-Host "File Size:   $([math]::Round((Get-Item $OutputCSV).Length/1KB, 1)) KB" -ForegroundColor Green
Write-Host "Output:      $OutputCSV" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green

Write-Host ""
Write-Host "Sample data (first 5 rows):" -ForegroundColor Cyan
$data | Select-Object -First 5 | Format-Table Index, HexValue, DecimalValue -AutoSize

Write-Host ""
Write-Host "[COMPLETE] 100,000 random numbers saved to $OutputCSV" -ForegroundColor Green
Write-Host ""
