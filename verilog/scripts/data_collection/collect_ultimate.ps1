$ComPort = "COM4"
$Count = 100000

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "FPGA DATA COLLECTION - Ultimate Version" -ForegroundColor Cyan  
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "CRITICAL: Make sure SW[0] on extension board is set to RIGHT!" -ForegroundColor Yellow
Write-Host ""

try {
    Write-Host "Connecting to $ComPort at 115200 baud..." -ForegroundColor Yellow
    $port = New-Object System.IO.Ports.SerialPort($ComPort, 115200)
    $port.ReadTimeout = 1000
    $port.Open()
    Write-Host "[OK] Connected to COM4" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Waiting for oscillator to stabilize (5 seconds)..." -ForegroundColor Cyan
    Start-Sleep -Seconds 5
    
    Write-Host "Collecting $Count samples..." -ForegroundColor Cyan
    
    $hex_values = @()
    $current_hex = ""
    $samples_collected = 0
    $start_time = Get-Date
    $no_data_time = $start_time
    $timeout_seconds = 30  # 30 second timeout total
    
    while ($samples_collected -lt $Count) {
        try {
            $byte = $port.ReadByte()
            $no_data_time = Get-Date  # Reset timeout on any data
            $char = [char]$byte
            
            if ($char -match '[0-9A-Fa-f]') {
                $current_hex += $char.ToString().ToUpper()
                if ($current_hex.Length -eq 4) {
                    $hex_values += $current_hex
                    $samples_collected++
                    $current_hex = ""
                    
                    if ($samples_collected % 10000 -eq 0) {
                        $elapsed = (Get-Date) - $start_time
                        Write-Host "[$samples_collected/$Count] $($elapsed.TotalSeconds)s" -ForegroundColor Green
                    }
                }
            }
        } catch [TimeoutException] {
            # Check if we've gotten NO data for 30 seconds
            if (((Get-Date) - $no_data_time).TotalSeconds -gt $timeout_seconds) {
                if ($samples_collected -eq 0) {
                    Write-Host ""
                    Write-Host "[TIMEOUT] No data received in $timeout_seconds seconds!" -ForegroundColor Red
                    break
                }
            }
        }
    }
    
    if ($port.IsOpen) { $port.Close() }
    $port.Dispose()
    
    $elapsed = (Get-Date) - $start_time
    
    if ($samples_collected -ge $Count) {
        Write-Host ""
        Write-Host "[SUCCESS] Collected $samples_collected samples in $($elapsed.TotalSeconds)s!" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "Creating CSV file..." -ForegroundColor Yellow
        
        $csv = @("Index,HexValue,DecimalValue,Timestamp")
        $base = Get-Date
        
        for ($i = 0; $i -lt $hex_values.Count; $i++) {
            $hex = $hex_values[$i]
            $dec = [Convert]::ToInt32($hex, 16)
            $ts = $base.AddSeconds($i / $samples_collected * $elapsed.TotalSeconds).ToString("yyyy-MM-dd HH:mm:ss.fff")
            $csv += "$($i+1),$hex,$dec,$ts"
        }
        
        $csv | Out-File "random_data_100k.csv" -Encoding UTF8 -Force
        
        $rows = (Get-Content "random_data_100k.csv" | Measure-Object -Line).Lines - 1
        Write-Host "[OK] CSV: $rows rows" -ForegroundColor Green
        Write-Host ""
        Write-Host "✓✓✓ COMPLETED ✓✓✓" -ForegroundColor Green
        Write-Host "File: random_data_100k.csv" -ForegroundColor Green
        
    } else {
        Write-Host ""
        Write-Host "[ERROR] Only collected $samples_collected/$Count samples" -ForegroundColor Red
        if ($samples_collected -eq 0) {
            Write-Host ""
            Write-Host "ACTION REQUIRED:" -ForegroundColor Yellow
            Write-Host "1. Check FPGA is powered (LED lights on)" -ForegroundColor White
            Write-Host "2. Slide SW[0] to RIGHT on extension board" -ForegroundColor White
            Write-Host "3. Run this script again" -ForegroundColor White
        }
    }
    
} catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    if ($port -and $port.IsOpen) { $port.Close() }
}
