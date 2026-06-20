# <#
#    setup.ps1 – apply fixes, hard‑code server, rebuild & redeploy the Wholphin channel
#    ---------------------------------------------------------------
#    Prerequisites (already present in the repo):
#      • powershell (v5+)
#      • node (for `node build.js`)
#      • curl.exe (for the ECP upload)
      # • A Roku device in Developer Mode on your network
# #>

# -------------------------------------------------
# 1️⃣  Path constants – adjust only if your folder layout is different
# -------------------------------------------------
$repoRoot   = "D:\VibeCode\wholphin"
$srcMain    = Join-Path $repoRoot "source\Main.bs"
$homeScreen = Join-Path $repoRoot "components\HomeScreen.brs"
$manifest   = Join-Path $repoRoot "manifest"

# -------------------------------------------------
# 2️⃣  Remove the duplicate `finishLoading()` definition
# -------------------------------------------------
Write-Host "Removing duplicate finishLoading()…" -ForegroundColor Cyan
$hsContent = Get-Content $homeScreen -Raw

# Find the first and second occurrence of the sub name
$firstPos  = $hsContent.IndexOf("sub finishLoading()")
$secondPos = $hsContent.IndexOf("sub finishLoading()", $firstPos + 1)

if ($secondPos -gt 0) {
    # Locate the matching `end sub` for the second occurrence
    $endSecond = $hsContent.IndexOf("end sub", $secondPos)
    if ($endSecond -gt $secondPos) {
        # Remove the entire second block (including its `end sub`)
        $hsNew = $hsContent.Substring(0, $secondPos) +
                 $hsContent.Substring($endSecond + "end sub".Length)
        Set-Content -Path $homeScreen -Value $hsNew -Encoding UTF8
        Write-Host "  → duplicate removed" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Could not locate the end of the second finishLoading()" -ForegroundColor Yellow
    }
} else {
    Write-Host "  👍 No duplicate found (maybe already fixed)" -ForegroundColor Green
}

# -------------------------------------------------
# 3️⃣  Make navigation‑rail items focusable
# -------------------------------------------------
Write-Host "Adding focusable flags to side‑rail navigation…" -ForegroundColor Cyan
$navOld = @'
navGroup = m.top.findNode("navItemsGroup")
for i = 0 to items.Count() - 1
    item = items[i]
    g = CreateObject("roSGNode", "Group")
    g.translation = [0, i * 72]
    l = CreateObject("roSGNode", "Label")
    l.text = item.label
    l.font = "font:SmallSystemFont"
    l.color = "0x999999FF"
    l.width = 140
    l.height = 72
    l.horizAlign = "left"
    l.vertAlign = "center"
    l.translation = [12, 0]
    g.appendChild(l)
    navGroup.appendChild(g)
end for
'@

$navNew = @'
navGroup = m.top.findNode("navItemsGroup")
navGroup.focusable = true
for i = 0 to items.Count() - 1
    item = items[i]
    g = CreateObject("roSGNode", "Group")
    g.focusable = true
    g.translation = [0, i * 72]
    l = CreateObject("roSGNode", "Label")
    l.text = item.label
    l.font = "font:SmallSystemFont"
    l.color = "0x999999FF"
    l.width = 140
    l.height = 72
    l.horizAlign = "left"
    l.vertAlign = "center"
    l.translation = [12, 0]
    g.appendChild(l)
    navGroup.appendChild(g)
end for
'@

(Get-Content $homeScreen) |
    ForEach-Object {
        if ($_ -match [regex]::Escape($navOld.Trim())) { $navNew } else { $_ }
    } |
    Set-Content $homeScreen -Encoding UTF8

# -------------------------------------------------
# 4️⃣  Replace the empty onKeyEvent with a simple focus switcher
# -------------------------------------------------
Write-Host "Installing a minimal onKeyEvent handler…" -ForegroundColor Cyan
$oldKeyHandler = @'
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    return false
end function
'@

$newKeyHandler = @'
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "left" then
        navGroup = m.top.findNode("navItemsGroup")
        if navGroup <> invalid then navGroup.setFocus(true)
        return true
    else if key = "right" then
        if m.homeRows <> invalid then m.homeRows.setFocus(true)
        return true
    end if

    return false
end function
'@

(Get-Content $homeScreen) |
    ForEach-Object {
        if ($_ -match [regex]::Escape($oldKeyHandler.Trim())) { $newKeyHandler } else { $_ }
    } |
    Set-Content $homeScreen -Encoding UTF8

# -------------------------------------------------
# 5️⃣  Hard‑code the Jellyfin server URL (replace the clear‑setting line)
# -------------------------------------------------
Write-Host "Hard‑coding the server URL…" -ForegroundColor Cyan
$clearLine = '    set_setting("server", "")'
$serverUrl = $env:JELLYFIN_SERVER_URL
if (-not $serverUrl) { $serverUrl = Read-Host "Enter Jellyfin server URL (e.g. http://192.168.1.100:8096)" }
$hardLine  = "    set_setting(""server"",""$serverUrl"")"

(Get-Content $srcMain) |
    ForEach-Object { if ($_ -eq $clearLine) { $hardLine } else { $_ } } |
    Set-Content $srcMain -Encoding UTF8

# -------------------------------------------------
# 6️⃣  Bump the manifest build_version (so Roku treats it as a new channel)
# -------------------------------------------------
Write-Host "Bumping build_version in manifest…" -ForegroundColor Cyan
(Get-Content $manifest) |
    ForEach-Object {
        if ($_ -match '^build_version\s*=\s*\d+$') {
            $num = [int]($_ -replace '[^\d]', '')
            "build_version=$($num+1)"
        } else { $_ }
    } |
    Set-Content $manifest -Encoding UTF8

# -------------------------------------------------
# 7️⃣  Re‑transpile, rebuild, and deploy
# -------------------------------------------------
Push-Location $repoRoot

Write-Host "\nCleaning old build artifacts…" -ForegroundColor Cyan
if (Test-Path "build") { Remove-Item -Recurse -Force "build" }
if (Test-Path "out")  { Remove-Item -Recurse -Force "out"  }

Write-Host "Transpiling the BrightScript sources…" -ForegroundColor Cyan
& powershell -ExecutionPolicy Bypass -File .\transpile.ps1

Write-Host "Creating the channel zip (node build.js)…" -ForegroundColor Cyan
node build.js

$rokuIP   = $env:ROKU_IP
if (-not $rokuIP)   { $rokuIP   = Read-Host "Enter Roku IP (e.g. 192.168.1.100)" }
$rokuUser = $env:ROKU_USERNAME
if (-not $rokuUser) { $rokuUser = Read-Host "Enter Roku username" }
$rokuPass = $env:ROKU_PASSWORD
if (-not $rokuPass) { $rokuPass = Read-Host "Enter Roku password" -AsSecureString | ConvertFrom-SecureString -AsPlainText }

Write-Host "\nDeploying to Roku $rokuIP…" -ForegroundColor Cyan
curl.exe --digest -u "${rokuUser}:${rokuPass}" `
    -X POST "http://$rokuIP/plugin_install" `
    -F "archive=@./out/Wholphin.zip" `
    -F "mysubmit=Replace" `
    --max-time 120 -s -w "HTTP %{http_code}`n"

Pop-Location

Write-Host "\nAll done! The Roku should now launch straight to the Home screen for the \"Me\" profile, and left/right will move focus between the navigation rail and the content rows." -ForegroundColor Green
