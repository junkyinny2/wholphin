# Roku Deployment PowerShell Script
param(
    [string]$RokuIP = $(if ($env:ROKU_IP) { $env:ROKU_IP } else { "" })
)

# --------------------- Credentials ---------------------------------
$RokuPass = $env:ROKU_PASSWORD
if (-not $RokuPass) { $RokuPass = "whit" }
$RokuUser = $env:ROKU_USERNAME
if (-not $RokuUser) { $RokuUser = "rokudev" }

$ConfigFile = Join-Path $PSScriptRoot "bsconfig.deploy.json"
if (Test-Path $ConfigFile) {
    try {
        $cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        if ($cfg.password) { $RokuPass = $cfg.password }
        if ($cfg.username) { $RokuUser  = $cfg.username  }
        Write-Host "[INFO] Loaded deployment config from $ConfigFile" -ForegroundColor Gray
    } catch {
        Write-Host "[WARNING] Could not parse $ConfigFile, using defaults." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Wholphin Deployment ===" -ForegroundColor Yellow

if (-not $RokuIP) { $RokuIP = "192.168.1.196" }

Write-Host ""
Write-Host "[1/3] Cleaning old build artifacts..." -ForegroundColor Cyan
if (Test-Path "build") { Remove-Item -Recurse -Force "build" }
if (Test-Path "out") { Remove-Item -Recurse -Force "out" }

Write-Host ""
Write-Host "[2/3] Building package from source..." -ForegroundColor Cyan

# Run transpile.ps1 first (strips Library directives, .bs→.brs, injects <script> tags)
$transpileScript = Join-Path $PSScriptRoot "transpile.ps1"
if (Test-Path $transpileScript) { & "$transpileScript" } else {
    Write-Host "[ERROR] transpile.ps1 not found at $transpileScript" -ForegroundColor Red
    exit 1
}

# Run build.js which reads from build/staging/ and writes to out/Wholphin.zip
$nodeModules = Join-Path $PSScriptRoot "node_modules"
$env:NODE_PATH = $nodeModules
$buildScript = Join-Path $PSScriptRoot "build.js"
if (Test-Path $buildScript) {
    & node "$buildScript"
    $buildExit = $LASTEXITCODE
    if ($buildExit -ne 0) {
        Write-Host "[ERROR] Build failed with exit code $buildExit" -ForegroundColor Red
        exit 1
    }
}

$zipPath = Join-Path $PSScriptRoot "out\Wholphin.zip"
if (-not (Test-Path $zipPath)) {
    Write-Host "[ERROR] Package not found at: $zipPath" -ForegroundColor Red
    exit 1
}

$zipSizeKB = (Get-Item $zipPath).Length / 1KB
Write-Host "Build complete! Package size: $([math]::Round($zipSizeKB,1)) KB" -ForegroundColor Green

Write-Host ""
Write-Host "[3/3] Sideloading to Roku at $RokuIP..." -ForegroundColor Cyan

$uploadUrl = "http://$RokuIP/plugin_install"
try {
    $result = & "curl.exe" -sS --user "$RokuUser`:$RokuPass" --digest -F "archive=@$zipPath" -F "mysubmit=Replace" $uploadUrl 2>&1
    $uploadExit = $LASTEXITCODE
} catch {
    Write-Host "[ERROR] curl.exe not found in PATH." -ForegroundColor Red
    exit 1
}

if ($uploadExit -ne 0) {
    Write-Host "[ERROR] Sideload failed with exit code $uploadExit" -ForegroundColor Red
    Write-Host $result
    exit 1
}

if ($result -match "Install Failure") {
    $errMsg = ($result -replace '.*<font color="red">', '') -replace '</font>.*', ''
    Write-Host "[ERROR] $errMsg" -ForegroundColor Red
    exit 1
}

Write-Host "Sideload successful!" -ForegroundColor Green
Write-Host ""
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "Run '.\rokudebug.ps1 $RokuIP' to open a debug console." -ForegroundColor Yellow
