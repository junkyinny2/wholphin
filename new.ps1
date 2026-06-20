param(
    [string]$TargetIP = $(if ($env:ROKU_IP) { $env:ROKU_IP } else { "" })
)

# --------------------- Credentials ---------------------------------
$RokuPass = $env:ROKU_PASSWORD
if (-not $RokuPass) {
    $RokuPass = Read-Host "Enter Roku password" -AsSecureString | ConvertFrom-SecureString -AsPlainText
}
$RokuUser = $env:ROKU_USERNAME
if (-not $RokuUser) { $RokuUser = Read-Host "Enter Roku username (default: rokudev)" }
if (-not $RokuUser) { $RokuUser = "rokudev" }

# --------------------- Config --------------------------------------
$ConfigFile = Join-Path $PSScriptRoot "bsconfig.deploy.json"
if (Test-Path $ConfigFile) {
    try {
        $cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        if ($cfg.password) { $RokuPass = $cfg.password }
        if ($cfg.username) { $RokuUser  = $cfg.username  }
        Write-Host "[INFO] Loaded deployment config from $ConfigFile" -ForegroundColor Gray
    } catch {
        Write-Warning "Could not parse $ConfigFile - using fall-backs."
    }
}

# --------------------- Basic UI ------------------------------------
Write-Host ""
Write-Host "=== Wholphin Deployment ===" -ForegroundColor Yellow

if (-not $TargetIP) { $defaultIP = "192.168.1.100"; $input = Read-Host "Enter Roku IP (default: $defaultIP)"; $TargetIP = if ($input) { $input } else { $defaultIP } }
$RokuIP = $TargetIP

# --------------------------------------------------------------------
# 1/3 - Clean old build artifacts
# --------------------------------------------------------------------
Write-Host ""
Write-Host "[1/3] Cleaning old build artifacts..." -ForegroundColor Cyan

foreach ($dir in @("build","out")) {
    if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
}

# --------------------------------------------------------------------
# 1.5/3 - Transpile BrighterScript -> BrightScript
# --------------------------------------------------------------------
Write-Host ""
Write-Host "[1.5/3] Transpiling BrighterScript -> BrightScript..." -ForegroundColor Cyan

$Transpile = Join-Path $PSScriptRoot "transpile.ps1"
if (-not (Test-Path $Transpile)) {
    Write-Error "Transpiler script not found: $Transpile"
    exit 2
}
& "$Transpile"

# --------------------------------------------------------------------
# 2/3 - Build the .zip package from transpiled output
# --------------------------------------------------------------------
Write-Host ""
Write-Host "[2/3] Building package from transpiled output..." -ForegroundColor Cyan

$nodeModules = Join-Path $PSScriptRoot "node_modules"
if (-not (Test-Path $nodeModules)) {
    $fallback = Join-Path $PSScriptRoot "..\node_modules"
    if (Test-Path $fallback) { $nodeModules = $fallback }
}

$env:NODE_PATH = $nodeModules

$buildScript = Join-Path $PSScriptRoot "build.js"
if (-not (Test-Path $buildScript)) {
    Write-Error "Build script not found: $buildScript"
    exit 3
}
& node "$buildScript"
$buildExit = $LASTEXITCODE

if ($buildExit -ne 0) {
    Write-Error "Node build failed with exit code $buildExit"
    exit $buildExit
}

$zipPath = Join-Path $PSScriptRoot "out\Wholphin.zip"
if (-not (Test-Path $zipPath)) {
    Write-Error "Build completed but zip not found at: $zipPath"
    exit 4
}

$zipSizeKB = (Get-Item $zipPath).Length / 1KB
Write-Host "Build complete! Package size: $( [math]::Round($zipSizeKB,1) ) KB" -ForegroundColor Green

# --------------------------------------------------------------------
# 3/3 - Sideload to Roku
# --------------------------------------------------------------------
Write-Host ""
Write-Host "[3/3] Sideloading to Roku at $RokuIP..." -ForegroundColor Cyan

if (-not (Test-Connection -ComputerName $RokuIP -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
    Write-Warning "Roku at $RokuIP is not responding to ping. Deployment may fail."
}

$uploadUrl = "http://$RokuIP/plugin_install"

try {
    $result = & "curl.exe" -sS --user "$RokuUser`:$RokuPass" `
                --digest -F "archive=@$zipPath" -F "mysubmit=Replace" `
                $uploadUrl 2>&1
    $uploadExit = $LASTEXITCODE
} catch {
    Write-Error "curl.exe not found in PATH."
    exit 5
}

if ($uploadExit -ne 0) {
    Write-Error "Sideload failed with exit code $uploadExit"
    Write-Host $result
    exit $uploadExit
}

# --------------------------------------------------------------------
# Done
# --------------------------------------------------------------------
Write-Host ""
Write-Host "Deployment Complete! App should be launching on your Roku." -ForegroundColor Green
Write-Host "Run '.\rokudebug.ps1 $RokuIP' to open a debug console." -ForegroundColor Yellow