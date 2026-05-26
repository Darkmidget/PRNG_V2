$port = New-Object System.IO.Ports.SerialPort "COM4", 115200, "None", 8, "One"
$port.ReadTimeout = 5000
$port.WriteTimeout = 2000
try {
    $port.Open()
    $port.DiscardInBuffer()
    $port.DiscardOutBuffer()
    $bytesToSend = [byte[]] (0x12, 0x34, 0xFF)
    $port.Write($bytesToSend, 0, $bytesToSend.Length)
    Start-Sleep -Milliseconds 500
    if ($port.BytesToRead -gt 0) {
        $buffer = New-Object byte[] $port.BytesToRead
        $read = $port.Read($buffer, 0, $buffer.Length)
        Write-Output "SUCCESS: Received $read bytes: $([BitConverter]::ToString($buffer))"
    } else {
        Write-Output "FAILURE: No bytes available to read after 500ms"
    }
} catch {
    Write-Output "ERROR: $($_.Exception.Message)"
} finally {
    $port.Close()
}
