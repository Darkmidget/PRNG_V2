$port = New-Object System.IO.Ports.SerialPort "COM4", 115200, "None", 8, "One"
$port.ReadTimeout = 2000
try {
    $port.Open()
    if ($port.BytesToRead -gt 0) {
        $oldData = New-Object byte[] $port.BytesToRead
        $port.Read($oldData, 0, $oldData.Length)
        Write-Output "Clearing old data from buffer: $([BitConverter]::ToString($oldData))"
    }
    $bytesToSend = [byte[]] (0x12, 0x34, 0xFF)
    $port.Write($bytesToSend, 0, $bytesToSend.Length)
    Write-Output "Sent 0x12 0x34 0xFF"
    
    $received = New-Object System.Collections.Generic.List[byte]
    $startTime = [DateTime]::Now
    while (([DateTime]::Now - $startTime).TotalSeconds -lt 2 -and $received.Count -lt 2) {
        if ($port.BytesToRead -gt 0) {
            $received.Add($port.ReadByte())
        }
        [System.Threading.Thread]::Sleep(10)
    }
    
    if ($received.Count -gt 0) {
        Write-Output "RESULT: Read $($received.Count) bytes: $(($received | ForEach-Object { '0x{0:X2}' -f $_ }) -join ' ')"
    } else {
        Write-Output "RESULT: Timed out. No bytes received."
    }
} catch {
    Write-Output "ERROR: $($_.Exception.Message)"
} finally {
    if ($port.IsOpen) { $port.Close() }
}
