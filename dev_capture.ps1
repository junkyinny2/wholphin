param([string]$RokuIP = "192.168.1.196", [int]$Seconds = 14, [string]$OutFile = "D:\VibeCode\wholphin\livemon63.txt")
$ErrorActionPreference = "Stop"
"" | Set-Content -Path $OutFile
$c = New-Object System.Net.Sockets.TcpClient
$c.Connect($RokuIP, 8085)
$s = $c.GetStream()
$r = New-Object System.IO.StreamReader($s, [System.Text.Encoding]::ASCII)
$deadline = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $deadline) {
    while ($s.DataAvailable) {
        $l = $r.ReadLine()
        if ($null -ne $l) {
            $ts = Get-Date -Format "HH:mm:ss"
            "[$ts] T| $l" | Add-Content -Path $OutFile
        }
    }
    Start-Sleep -Milliseconds 40
}
$r.Close(); $s.Close(); $c.Close()
Write-Host "captured to $OutFile"
