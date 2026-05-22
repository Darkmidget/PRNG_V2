# FPGA Random Data Collection Script
# Collects 100,000 random 16-bit values from Ring Oscillator FPGA via UART
# Output: CSV file with timestamp and hex values

param(
    [string]$ComPort = $null,
    [int]$BaudRate = 115200,
    [int]$SampleCount = 100000
)

function Get-AvailablePorts {
    $ports = [System.IO.Ports.SerialPort]::GetPortNames()
    return $ports
}

function Find-FPGAPort {
    Write-Host "Scanning for available COM ports..."
    $ports = Get-AvailablePorts
    
    if ($ports.Count -eq 0) {
        Write-Error "No COM ports found. Check FPGA USB connection."
        exit 1
    }
    
    Write-Host "Available ports: $($ports -join ', ')"
    
    if ($ports.Count -eq 1) {
        $selectedPort = $ports[0]
        Write-Host "Using port: $selectedPort"
        return $selectedPort
    }
    
    # Prompt user if multiple ports
    Write-Host "`nMultiple ports detected. Enter COM port (e.g., COM3):"
    $selectedPort = Read-Host
    
    if ($selectedPort -notin $ports) {
        Write-Error "Port $selectedPort not found."
        exit 1
    }
    
    return $selectedPort
}

function Open-SerialConnection {
    param([string]$Port, [int]$Baud)
    
    $serial = New-Object System.IO.Ports.SerialPort
    $serial.PortName = $Port
    $serial.BaudRate = $Baud
    $serial.Parity = "None"
    $serial.DataBits = 8
    $serial.StopBits = 1
    $serial.Handshake = "None"
    $serial.ReadTimeout = 5000
    
    try {
        $serial.Open()
        Write-Host "Connected to $Port at $Baud baud"
        return $serial
    } catch {
        Write-Error "Failed to open $Port : $_"
        exit 1
    }
}

# Main Script
Write-Host "================================"
Write-Host "FPGA Random Data Collector"
Write-Host "Target: 100,000 samples @ 115200 baud"
Write-Host "================================`n"

# Determine COM port
if ($null -eq $ComPort) {
    $ComPort = Find-FPGAPort
} else {
    Write-Host "Using specified port: $ComPort"
}

# Open serial connection
$serial = Open-SerialConnection -Port $ComPort -Baud $BaudRate

# Prepare output file
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputFile = "fpga_random_samples_$timestamp.csv"
$csvPath = Join-Path (Get-Location) $outputFile

# Initialize CSV
"Timestamp,Sample_Number,Hex_Value,Raw_Line" | Out-File -FilePath $csvPath -Encoding ASCII

Write-Host "Output file: $outputFile`n"
Write-Host "Starting data collection..."
Write-Host "Enable oscillator: Slide SW[0] to RIGHT on the FPGA board`n"

$sampleCount = 0
$lineBuffer = ""
$startTime = Get-Date
$lastDisplayTime = $startTime

# Read data loop
try {
    while ($sampleCount -lt $SampleCount) {
        
        # Read one character at a time to handle line buffering
        $char = $serial.ReadChar()
        $lineBuffer += [char]$char
        
        # Check for line terminator (LF = `n)
        if ($char -eq "`n") {
            $line = $lineBuffer.Trim()
            $lineBuffer = ""
            
            # Parse the line - expecting "XXXX" format (4 hex chars)
            if ($line.Length -ge 4 -and $line -match '^[0-9A-Fa-f]{4}') {
                $sampleCount++
                $hexValue = $line.Substring(0, 4)
                $currentTime = Get-Date
                $timeStr = $currentTime.ToString("yyyy-MM-dd HH:mm:ss.fff")
                
                # Write to CSV
                "$timeStr,$sampleCount,$hexValue,$line" | Out-File -FilePath $csvPath -Append -Encoding ASCII
                
                # Progress display (every 10,000 samples or every 30 seconds)
                if (($sampleCount % 10000 -eq 0) -or (($currentTime - $lastDisplayTime).TotalSeconds -ge 30)) {
                    $elapsed = ($currentTime - $startTime).TotalSeconds
                    $rate = $sampleCount / $elapsed
                    $remaining = ($SampleCount - $sampleCount) / $rate
                    Write-Host "[$(Get-Date -Format HH:mm:ss)] Samples: $sampleCount / $SampleCount | Rate: $([math]::Round($rate, 0)) samples/sec | ETA: $([math]::Round($remaining, 1)) sec"
                    $lastDisplayTime = $currentTime
                }
            }
        }
    }
} catch {
    Write-Error "Error during data collection: $_"
} finally {
    $serial.Close()
    Write-Host "`n[COMPLETE]"
}

$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds
$rate = $sampleCount / $duration

Write-Host "`n================================"
Write-Host "Data Collection Complete!"
Write-Host "================================"
Write-Host "Total Samples: $sampleCount"
Write-Host "Collection Time: $([math]::Round($duration, 2)) seconds"
Write-Host "Sample Rate: $([math]::Round($rate, 0)) samples/sec"
Write-Host "Output File: $outputFile"
Write-Host "Output Location: $csvPath"
Write-Host "================================`n"

# Verify CSV
$csvLines = (Get-Content $csvPath | Measure-Object -Line).Lines
Write-Host "CSV Lines: $csvLines (including header)"
Write-Host "First 5 rows:"
Get-Content $csvPath | Select-Object -First 6
