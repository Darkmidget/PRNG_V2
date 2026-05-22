Write-Host "=== FPGA UART Diagnostic Tool ===" -ForegroundColor Cyan
Write-Host ""

# List all available COM ports
Write-Host "[*] Scanning available COM ports..." -ForegroundColor Yellow
$ports = [System.IO.Ports.SerialPort]::GetPortNames()

if ($ports.Count -eq 0) {
    Write-Host "[!] WARNING: No COM ports found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "TROUBLESHOOTING:" -ForegroundColor Yellow
    Write-Host "1. UNPLUG the FPGA USB cable" -ForegroundColor White
    Write-Host "2. Wait 5 seconds" -ForegroundColor White
    Write-Host "3. PLUG the USB cable back in" -ForegroundColor White
    Write-Host "4. Wait 10 seconds for USB enumeration" -ForegroundColor White
    Write-Host "5. Run this script again" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "[OK] Found COM ports: $($ports -join ', ')" -ForegroundColor Green
    Write-Host ""
    
    # Try each port
    foreach ($port_name in $ports) {
        Write-Host "[*] Testing $port_name at 115200 baud..." -ForegroundColor Yellow
        
        try {
            $port = New-Object System.IO.Ports.SerialPort($port_name, 115200, 'None', 8, 'One')
            $port.ReadTimeout = 2000
            $port.Open()
            
            Write-Host "   Listening for data (2 second timeout)..." -ForegroundColor Cyan
            
            $data = ""
            $timeout_time = [DateTime]::Now.AddSeconds(2)
            
            while([DateTime]::Now -lt $timeout_time) {
                try {
                    $byte = $port.ReadByte()
                    $data += [char]$byte
                    if ($data.Length -ge 20) { break }
                } catch {}
            }
            
            $port.Close()
            $port.Dispose()
            
            if ($data.Length -gt 0) {
                Write-Host "   [FOUND DATA!] Received: $($data -replace '[\r\n]', ' ')" -ForegroundColor Green
            } else {
                Write-Host "   No data received" -ForegroundColor Gray
            }
        } catch {
            Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Cyan
Write-Host "- If data was found: Run '.\collect_100k_final.ps1'" -ForegroundColor White
Write-Host "- If no data: Check switch SW[0] is slid RIGHT on the extension board" -ForegroundColor White
Write-Host "- Still no data: Unplug/replug USB and wait 10 seconds, then try again" -ForegroundColor White
