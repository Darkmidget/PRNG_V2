$port = New-Object System.IO.Ports.SerialPort "COM4", 115200, "None", 8, "One"
$port.ReadTimeout = 5000
try {
    $port.Open()
    $bytesToSend = [byte[]] (0x12, 0x34, 0xFF)
    $port.Write($bytesToSend, 0, $bytesToSend.Length)
    # Give it 2 seconds to respond
    Start-Sleep -Seconds 2
    if ($port.BytesToRead -gt 0) {
        $buffer = New-Object byte[] $port.BytesToRead
        $read = $port.Read($buffer, 0, $buffer.Length)
        Write-Output "SUCCESS: Received $read bytes: $([BitConverter]::ToString($buffer))"
    } else {
        Write-Output "FAILURE: No bytes received within 2 seconds."
    }
} catch {
    Write-Output "ERROR: $($_.Exception.Message)"
} finally {
    $port.Close()
}
