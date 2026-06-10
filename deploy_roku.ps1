# Roku Deployment PowerShell Script
# Builds and deploys Wholphin to your Roku device.
#
# !!! WARNING: The Living Room Roku IP is 192.168.1.196. DO NOT CHANGE IT !!!

$RokuPass = "whit"
$RokuUser = "rokudev"
$ConfigFile = Join-Path $PSScriptRoot "bsconfig.deploy.json"
$Config = $null

if (Test-Path $ConfigFile) {
    try {
        $Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        if ($Config.password) { $RokuPass = $Config.password }
        if ($Config.username) { $RokuUser = $Config.username }
        Write-Host "[INFO] Loaded deployment config from $ConfigFile" -ForegroundColor Gray
    } catch {
        Write-Host "[WARNING] Could not parse $ConfigFile. Using fallbacks." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Wholphin Deployment ===" -ForegroundColor Yellow

# !!! DO NOT CHANGE: Living Room Roku = 192.168.1.196 !!!
$defaultIP = "192.168.1.196"
$RokuIP = if ($args.Length -gt 0) { $args[0] } else { $defaultIP }

Write-Host ""
Write-Host "[1/3] Cleaning old build artifacts..." -ForegroundColor Cyan
if (Test-Path "build") { Remove-Item -Recurse -Force "build" }
if (Test-Path "out") { Remove-Item -Recurse -Force "out" }

Write-Host ""
Write-Host "[1.5/3] Transpiling BrighterScript to BrightScript..." -ForegroundColor Cyan
& "$PSScriptRoot\transpile.ps1"

Write-Host ""
Write-Host "[2/3] Building package from transpiled output..." -ForegroundColor Cyan

$nodeModules = Join-Path $PSScriptRoot "node_modules"
if (-not (Test-Path $nodeModules)) {
    $nodeModules = Join-Path $PSScriptRoot "..\node_modules"
}
$env:NODE_PATH = $nodeModules
node "$PSScriptRoot\build.js"
$buildExit = $LASTEXITCODE

$zipPath = "out\Wholphin.zip"
if (-not (Test-Path $zipPath)) {
    Write-Host "[ERROR] Build completed but zip not found at: $zipPath" -ForegroundColor Red
    exit 1
}

$zipSize = (Get-Item $zipPath).Length / 1KB
Write-Host "Build complete! Package size: $([math]::Round($zipSize, 1)) KB" -ForegroundColor Green

Write-Host ""
Write-Host "[3/3] Sideloading to Roku at $RokuIP..." -ForegroundColor Cyan

if (-not (Test-Connection -ComputerName $RokuIP -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
    Write-Host "[WARNING] Roku at $RokuIP is not responding to ping. Deployment may fail." -ForegroundColor Yellow
}

$uploadUrl = "http://$RokuIP/plugin_install"
$result = & "curl.exe" -sS --user "$RokuUser`:$RokuPass" --digest -F "archive=@$zipPath" -F "mysubmit=Replace" $uploadUrl 2>&1
$uploadExit = $LASTEXITCODE

if ($uploadExit -ne 0) {
    Write-Host "[ERROR] Sideload failed with exit code $uploadExit" -ForegroundColor Red
    Write-Host $result
    exit 1
}

Write-Host ""
Write-Host "Deployment Complete! App should be launching on your Roku." -ForegroundColor Green
Write-Host "Run '.\rokudebug.ps1 $RokuIP' to open a debug console." -ForegroundColor Yellow
