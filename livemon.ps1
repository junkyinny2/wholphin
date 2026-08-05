param([string]$RokuIP = "192.168.1.196", [int]$Seconds = 120, [string]$OutFile = "D:\VibeCode\wholphin\livemon15.txt")
$ErrorActionPreference = "Stop"
$client = New-Object System.Net.Sockets.TcpClient
$client.Connect($RokuIP, 8085)
$stream = $client.GetStream()
$reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII)
"" | Set-Content -Path $OutFile
$sw = [System.Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
    if ($stream.DataAvailable) {
        $line = $reader.ReadLine()
        if ($line -ne $null) {
            $line | Add-Content -Path $OutFile
        }
    } else {
        Start-Sleep -Milliseconds 50
    }
}
$reader.Close(); $stream.Close(); $client.Close()
Write-Host "DONE $OutFile lines=$((Get-Content $OutFile | Measure-Object -Line).Lines)"
