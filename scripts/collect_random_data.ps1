# FPGA Random Number Data Collection Script
# Collects 100,000 random numbers from FPGA via UART (COM4) and saves to CSV

param(
    [string]$ComPort = "COM4",
    [int]$BaudRate = 115200,
    [int]$SampleCount = 100000,
    [string]$OutputFile = "random_data_100k.csv"
)

# Create serial port connection
$port = New-Object System.IO.Ports.SerialPort
$port.PortName = $ComPort
$port.BaudRate = $BaudRate
$port.Parity = [System.IO.Ports.Parity]::None
$port.DataBits = 8
$port.StopBits = [System.IO.Ports.StopBits]::One
$port.ReadTimeout = 1000

try {
    Write-Host "Opening serial connection on $ComPort at $BaudRate baud..." -ForegroundColor Cyan
    $port.Open()
    Write-Host "Connected!" -ForegroundColor Green
    
    # Initialize CSV file
    $csvPath = Join-Path (Get-Location) $OutputFile
    $null = "Sample_Number,Hex_Value,Timestamp" | Out-File -FilePath $csvPath -Encoding UTF8
    
    Write-Host "Starting data collection: $(Get-Date)"
    Write-Host "Target: $SampleCount samples to $csvPath" -ForegroundColor Yellow
    
    $samples = @()
    $sampleIdx = 0
    $startTime = Get-Date
    $lineBuffer = ""
    
    # Collection loop
    while ($sampleIdx -lt $SampleCount) {
        try {
            # Read one character at a time
            $char = $port.ReadChar()
            $lineBuffer += [char]$char
            
            # Check for complete line (ends with \r\n)
            if ($lineBuffer.EndsWith("`r`n")) {
                # Extract hex value (remove CR/LF)
                $hexValue = $lineBuffer.Trim()
                
                # Validate hex format (should be 4 hex characters)
                if ($hexValue -match '^[0-9A-F]{4}$') {
                    $sampleIdx++
                    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
                    
                    # Append to CSV
                    "$sampleIdx,$hexValue,$timestamp" | Add-Content -Path $csvPath -Encoding UTF8
                    
                    # Progress indicator
                    if ($sampleIdx % 10000 -eq 0) {
                        $elapsedTime = (Get-Date) - $startTime
                        $rate = $sampleIdx / $elapsedTime.TotalSeconds
                        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Collected: $sampleIdx / $SampleCount samples (Rate: $([math]::Round($rate, 1)) samples/sec)" -ForegroundColor Cyan
                    }
                }
                $lineBuffer = ""
            }
        }
        catch {
            # Timeout waiting for data - continue
            continue
        }
    }
    
    $totalTime = (Get-Date) - $startTime
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "✓ Data Collection Complete!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "Samples collected: $SampleCount" -ForegroundColor Green
    Write-Host "Total time: $([math]::Round($totalTime.TotalSeconds, 2)) seconds" -ForegroundColor Green
    Write-Host "Average rate: $([math]::Round($SampleCount / $totalTime.TotalSeconds, 1)) samples/sec" -ForegroundColor Green
    Write-Host "Output file: $csvPath" -ForegroundColor Green
    Write-Host "File size: $([math]::Round((Get-Item $csvPath).Length / 1MB, 2)) MB" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
finally {
    if ($port.IsOpen) {
        $port.Close()
        Write-Host "Serial connection closed." -ForegroundColor Yellow
    }
}
