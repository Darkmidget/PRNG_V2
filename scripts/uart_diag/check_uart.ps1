Write-Host "=== FPGA UART Diagnostic ===" -ForegroundColor Cyan
Write-Host ""

try {
    $port = New-Object System.IO.Ports.SerialPort("COM4", 115200)
    $port.ReadTimeout = 10000
    $port.Open()
    
    Write-Host "[OK] COM4 opened successfully at 115200 baud" -ForegroundColor Green
    Write-Host "Listening for 10 seconds for any data..." -ForegroundColor Cyan
    Write-Host ""
    
    $buffer = @()
    $end_time = [DateTime]::Now.AddSeconds(10)
    $bytes_read = 0
    
    while ([DateTime]::Now -lt $end_time) {
        try {
            $byte = $port.ReadByte()
            $buffer += $byte
            $bytes_read++
            
            if ($bytes_read % 100 -eq 0) {
                Write-Host "  [$bytes_read bytes received]" -ForegroundColor Green
            }
        } catch [TimeoutException] {
            # Expected
        }
    }
    
    $port.Close()
    $port.Dispose()
    
    Write-Host ""
    Write-Host "Total bytes received: $bytes_read" -ForegroundColor Cyan
    
    if ($bytes_read -gt 0) {
        Write-Host ""
        $text = [System.Text.Encoding]::ASCII.GetString($buffer)
        Write-Host "Data sample (first 200 chars):" -ForegroundColor Green
        Write-Host "$($text.Substring(0, [Math]::Min(200, $text.Length)))" -ForegroundColor White
        Write-Host ""
        Write-Host "FPGA IS TRANSMITTING!" -ForegroundColor Green
        Write-Host "Ready to collect 100k samples. Run: .\collect_robust.ps1" -ForegroundColor Cyan
    } else {
        Write-Host ""
        Write-Host "[PROBLEM] No data received at all!" -ForegroundColor Red
        Write-Host ""
        Write-Host "CHECK:" -ForegroundColor Yellow
        Write-Host "  1. Is the FPGA powered? (should have LED lights)" -ForegroundColor White
        Write-Host "  2. Is SW[0] on extension board set to RIGHT?" -ForegroundColor White
        Write-Host "  3. Try unplugging USB for 10 seconds and plugging back in" -ForegroundColor White
        Write-Host ""
        Write-Host "Then run this diagnostic again" -ForegroundColor Cyan
    }
    
} catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
}
