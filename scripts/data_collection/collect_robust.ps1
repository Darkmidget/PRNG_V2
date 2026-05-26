$ComPort = "COM4"
$Count = 100000
$OutputCSV = "random_data_100k.csv"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "FPGA DATA COLLECTION - robust version" -ForegroundColor Cyan  
Write-Host "============================================" -ForegroundColor Cyan

# Try with different settings
$configs = @(
    @{BaudRate=115200; Parity='None'; DataBits=8; StopBits='One'},
    @{BaudRate=9600; Parity='None'; DataBits=8; StopBits='One'},
    @{BaudRate=57600; Parity='None'; DataBits=8; StopBits='One'}
)

$port = $null
foreach ($config in $configs) {
    Write-Host "Trying $($config.BaudRate) baud..." -ForegroundColor Yellow
    try {
        $port = New-Object System.IO.Ports.SerialPort($ComPort, $config.BaudRate, $config.Parity, $config.DataBits, $config.StopBits)
        $port.ReadTimeout = 5000
        $port.Open()
        Write-Host "[OK] Connected at $($config.BaudRate)!" -ForegroundColor Green
        break
    } catch {
        Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($port) { $port.Dispose() }
    }
}

if (-not $port -or -not $port.IsOpen) {
    Write-Host ""
    Write-Host "[CRITICAL] Cannot open any COM port!" -ForegroundColor Red
    Write-Host ""
    Write-Host "The FPGA may not be responding. Possible causes:" -ForegroundColor Yellow
    Write-Host "  1. Bitstream not actually running (reprog needed)" -ForegroundColor White
    Write-Host "  2. USB cable disconnected" -ForegroundColor White
    Write-Host "  3. FPGA not powered" -ForegroundColor White
    Write-Host "  4. Extension board switch SW[0] not set to RIGHT" -ForegroundColor White
    Write-Host ""
    Write-Host "Please verify FPGA and try again" -ForegroundColor Cyan
    exit 1
}

Write-Host ""
Write-Host "Collecting $Count samples..." -ForegroundColor Cyan

$hex_values = @()
$start_time = Get-Date
$current_hex = ""
$samples_collected = 0

try {
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
                        Write-Host "[$samples_collected/$Count] Time: $($elapsed.TotalSeconds)s" -ForegroundColor Cyan
                    }
                }
            }
        } catch [TimeoutException] {
            Write-Host "[WARNING] Timeout at $samples_collected" -ForegroundColor Yellow
            break
        }
    }
    
    if ($port.IsOpen) { $port.Close() }
    $port.Dispose()
    
    $elapsed = (Get-Date) - $start_time
    
    if ($samples_collected -ge $Count) {
        Write-Host ""
        Write-Host "[SUCCESS] Collected $samples_collected samples!" -ForegroundColor Green
        
        Write-Host "Creating CSV..." -ForegroundColor Cyan
        $csv = @("Index,HexValue,DecimalValue,Timestamp")
        $base = Get-Date
        
        for ($i = 0; $i -lt $hex_values.Count; $i++) {
            $hex = $hex_values[$i]
            $dec = [Convert]::ToInt32($hex, 16)
            $ts = $base.AddSeconds($i / $samples_collected * $elapsed.TotalSeconds).ToString("yyyy-MM-dd HH:mm:ss.fff")
            $csv += "$($i+1),$hex,$dec,$ts"
        }
        
        $csv | Out-File $OutputCSV -Encoding UTF8 -Force
        $rows = (Get-Content $OutputCSV | Measure-Object -Line).Lines - 1
        
        Write-Host "[OK] CSV created: $rows rows" -ForegroundColor Green
        Write-Host ""
        Write-Host "COMPLETED - 100,000 random numbers in $OutputCSV" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "[ERROR] Only collected $samples_collected/$Count samples" -ForegroundColor Red
    }
    
} finally {
    if ($port -and $port.IsOpen) { $port.Close() }
    if ($port) { $port.Dispose() }
}
