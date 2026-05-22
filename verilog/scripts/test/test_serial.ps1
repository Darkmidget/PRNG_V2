$port = New-Object System.IO.Ports.SerialPort "COM4", 115200, "None", 8, "One"
$port.ReadTimeout = 2000
$port.DtrEnable = $true
$port.RtsEnable = $true
try {
    $port.Open()
    Write-Output "Port COM4 opened (DTR/RTS enabled)."
    $bytesToSend = [byte[]] (0x12, 0x34, 0xFF)
    $port.Write($bytesToSend, 0, $bytesToSend.Length)
    Write-Output "Sent: 0x12 0x34 0xFF"
    
    $received = New-Object System.Collections.Generic.List[byte]
    $startTime = Get-Date
    while (((Get-Date) - $startTime).TotalSeconds -lt 2 -and $received.Count -lt 2) {
        if ($port.BytesToRead -gt 0) {
            $received.Add($port.ReadByte())
        }
        Start-Sleep -Milliseconds 10
    }
    
    if ($received.Count -gt 0) {
        Write-Output "Read $($received.Count) bytes: $(($received | ForEach-Object { '0x{0:X2}' -f $_ }) -join ' ')"
    } else {
        Write-Output "No bytes received within 2 seconds."
    }
} catch {
    Write-Output "Error: $($_.Exception.Message)"
} finally {
    if ($port -and $port.IsOpen) { $port.Close() }
}
