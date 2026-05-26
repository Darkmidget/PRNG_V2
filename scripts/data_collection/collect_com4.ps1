param([string]$ComPort = "COM4", [int]$Count = 100000, [string]$OutputCSV = "random_data_100k.csv")

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "FPGA DATA COLLECTION (100,000 SAMPLES)" -ForegroundColor Cyan  
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Connecting to $ComPort at 115200 baud..." -ForegroundColor Yellow
Write-Host ""

$hex_values = @()
try {
    $port = New-Object System.IO.Ports.SerialPort($ComPort, 115200)
    $port.ReadTimeout = 5000
    $port.Open()
    Write-Host "[OK] Connected!" -ForegroundColor Green
    
    $start_time = Get-Date
    $current_hex = ""
    $samples_collected = 0
    
    while ($samples_collected -lt $Count) {
        try {
            $byte = $port.ReadByte()
            $char = [char]$byte
            if ($char -match '[0-9A-Fa-f]') {
                $current_hex += $char.ToString().ToUpper()
                if ($current_hex.Length -eq 4) {
                    $hex_values += $current_hex
                    $samples_collected++
                    $current_hex = ""
                    if ($samples_collected % 10000 -eq 0) {
                        $elapsed = (Get-Date) - $start_time
                        Write-Host "[$samples_collected/$Count] - Elapsed: $($elapsed.TotalSeconds)s" -ForegroundColor Cyan
                    }
                }
            }
        } catch [TimeoutException] {
            Write-Host "[WARNING] Timeout at $samples_collected samples" -ForegroundColor Yellow
            break
        }
    }
    
    $port.Close()
    $port.Dispose()
    
    $elapsed = (Get-Date) - $start_time
    Write-Host ""
    Write-Host "[SUCCESS] Collected $samples_collected samples in $($elapsed.TotalSeconds)s!" -ForegroundColor Green
    
    Write-Host "Creating CSV file..." -ForegroundColor Yellow
    $csv_lines = @("Index,HexValue,DecimalValue,Timestamp")
    $base_time = Get-Date
    
    for ($i = 0; $i -lt $hex_values.Length; $i++) {
        $hex = $hex_values[$i]
        $dec = [System.Convert]::ToInt32($hex, 16)
        $ts = $base_time.AddSeconds($i / $Count * $elapsed.TotalSeconds).ToString("yyyy-MM-dd HH:mm:ss.fff")
        $csv_lines += "$($i+1),$hex,$dec,$ts"
    }
    
    $csv_lines | Out-File $OutputCSV -Encoding UTF8 -Force
    
    $row_count = (Get-Content $OutputCSV | Measure-Object -Line).Lines - 1
    Write-Host "[OK] CSV saved: $OutputCSV ($row_count rows)" -ForegroundColor Green
    Write-Host ""
    Write-Host "COMPLETED - 100,000 random numbers collected!" -ForegroundColor Green
    
} catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
}
