# ================================
# Roku Dev Mode Monitor — Smart Filter
# Suppresses noise, highlights diagnostics
# Usage: .\rokudebug.ps1 [RokuIP]
#   If IP is provided, connects directly.
#   If omitted, prompts with default from ROKU_IP env var or 192.168.1.100.
#
# Set ROKU_IP environment variable or pass IP as argument
# ================================

param(
    [string]$RokuIP = ""
)

$port = 8085

if ($RokuIP -eq "") {
    $defaultIP = $env:ROKU_IP
    if (-not $defaultIP) { $defaultIP = "192.168.1.100" }
    $ip = $defaultIP
} else {
    $ip = $RokuIP
}

$target = "$ip`:$port"
$logFile = Join-Path $PSScriptRoot ("roku_monitor_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

# Suppression counters
$suppressedCount = 0
$lastSuppressed = ""
$maxShow = 3  # show first N of a suppressed pattern, then collapse

Write-Host "=== Roku Dev Monitor (Smart Filter) ===" -ForegroundColor Cyan
Write-Host ("Target: {0}" -f $target)
Write-Host ("Saving full log to: {0}" -f $logFile)
Write-Host "Press Ctrl+C to stop"
Write-Host "========================`n"

# Create empty log
"" | Out-File $logFile

try {
    $client = New-Object System.Net.Sockets.TcpClient
    $client.Connect($ip, $port)

    $stream = $client.GetStream()
    $writer = New-Object System.IO.StreamWriter($stream)
    $reader = New-Object System.IO.StreamReader($stream)

    Write-Host "Connected to Roku debug console!" -ForegroundColor Green

    while ($client.Connected) {
        if ($stream.DataAvailable) {
            $line = $reader.ReadLine()

            if ($line -ne $null) {
                $ts = Get-Date -Format "HH:mm:ss.fff"
                $display = "[$ts] $line"

                # NOISE PATTERNS — suppress repetitive garbage
                $isNoise = $false
                if ($line -match "pendingShowSignIn=''") {
                    $isNoise = $true
                }

                if ($isNoise) {
                    if ($lastSuppressed -ne $line) {
                        $suppressedCount = 0
                        $lastSuppressed = $line
                    }
                    $suppressedCount++
                    if ($suppressedCount -le $maxShow) {
                        Write-Host $display -ForegroundColor DarkGray
                    } elseif ($suppressedCount -eq $maxShow + 1) {
                        Write-Host "  ... suppressing further identical lines ..." -ForegroundColor DarkGray
                    }
                } else {
                    # Flush suppression counter when new content appears
                    if ($suppressedCount -gt $maxShow) {
                        Write-Host ("  [suppressed $suppressedCount repetitions of: $lastSuppressed]") -ForegroundColor DarkGray
                    }
                    $suppressedCount = 0
                    $lastSuppressed = ""

                    # COLORIZE important diagnostics
                    if ($line -match "ButtonPressed") {
                        Write-Host $display -ForegroundColor Yellow
                    }
                    elseif ($line -match "\[Home\." -or $line -match "\[HomeRows" -or $line -match "\[HomeRow" -or $line -match "addRow") {
                        Write-Host $display -ForegroundColor Green
                    }
                    elseif ($line -match "\[LoadItemsTask") {
                        Write-Host $display -ForegroundColor Green
                    }
                    elseif ($line -match "Video" -or $line -match "playback" -or $line -match "stream") {
                        Write-Host $display -ForegroundColor Cyan
                    }
                    elseif ($line -match "ERROR|FAIL|invalid") {
                        Write-Host $display -ForegroundColor Red
                    }
                    elseif ($line -match "signin|pendingShowSignIn='[^']|AuthUser|Authenticate") {
                        Write-Host $display -ForegroundColor Magenta
                    }
                    elseif ($line -match "Home shown|Creating Home|Setting focus") {
                        Write-Host $display -ForegroundColor Cyan
                    }
                    elseif ($line -match "onRowItemSelect|rowItemSelected|itemSelected") {
                        Write-Host $display -ForegroundColor Yellow
                    }
                    else {
                        Write-Host $display
                    }
                }

                # Log everything (raw, no timestamp) to file
                $line | Out-File -FilePath $logFile -Append
            }
        }

        Start-Sleep -Milliseconds 10
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    if ($reader) { $reader.Close() }
    if ($writer) { $writer.Close() }
    if ($stream) { $stream.Close() }
    if ($client) { $client.Close() }

    Write-Host "Disconnected." -ForegroundColor Yellow
    Write-Host ("`nFull log saved to: {0}" -f $logFile) -ForegroundColor Green
    Write-Host "Share this file or paste its contents.`n" -ForegroundColor Green
}
