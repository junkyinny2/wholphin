# Transpile BrighterScript (.bs) to pure BrightScript for Roku OS
param(
    [string]$SourceDir = "D:\VibeCode\wholphin",
    [string]$OutDir = "D:\VibeCode\wholphin\build\staging"
)

if (Test-Path $OutDir) { Remove-Item -Recurse -Force $OutDir }
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$files = @("manifest") +
    @(Get-ChildItem "$SourceDir\source" -Recurse -File) +
    @(Get-ChildItem "$SourceDir\components" -Recurse -File) +
    @(Get-ChildItem "$SourceDir\images" -Recurse -File) +
    @(Get-ChildItem "$SourceDir\locale" -Recurse -File) +
    @(Get-ChildItem "$SourceDir\settings" -File)

Write-Host "Transpiling project files..." -ForegroundColor Cyan
$count = 0

foreach ($file in $files) {
    $relativePath = ""
    if ($file -is [string]) {
        $relativePath = $file
        $fullPath = Join-Path $SourceDir $file
    } else {
        $relativePath = $file.FullName.Substring($SourceDir.Length + 1)
        $fullPath = $file.FullName
    }

    $targetPath = Join-Path $OutDir $relativePath
    $targetDir = Split-Path $targetPath -Parent
    if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }

    if ($fullPath -match '\.(bs|brs)$') {
        $count++
        $content = Get-Content $fullPath -Raw

        # Rename .bs -> .brs for Roku OS compatibility (keep .brs as-is)
        $targetPath = $targetPath -replace '\.bs$', '.brs'

        # 1. Remove import statements
        $content = $content -replace '(?m)^import "pkg:/[^"]*".*\r?\n', ''

        # 1b. Rename .bs → .brs in file references
        $content = $content -replace '(Library|Include)\s+"(pkg:/[^"]+)\.bs"', '$1 "$2.brs"'

        # 1c. Remove Library directives (not supported on this Roku firmware)
        $content = $content -replace '(?m)^Library\s+"pkg:/[^"]+"\s*\r?\n', ''

        # 2. Remove const declarations
        $content = $content -replace '(?m)^\s*const\s+\w+\s*=\s*.*\r?\n', ''

        # 3. Namespace handling: track and prefix functions
        # Instead of just removing, we'll use them during line processing
        # to prefix function names with the namespace path
        # (namespace lines are still removed from output)

        # 4. Remove enum/end enum blocks
        $content = $content -replace '(?ms)^\s*enum\s+\w+.*?^\s*end\s+enum\r?\n?', ''

        # 5. Remove default parameter values in function/sub definitions
        # Handles: function f(x = "default") -> function f(x)
        # Only targets lines that start with function/sub declaration
        for ($r = 0; $r -lt 5; $r++) {
            $content = $content -replace '(?m)^(\s*(?:function|sub)\s+\w+\s*\([^)]*?)\b(\w+)\s*=\s*[^,)]+([^)]*\)[^(]*$)', '${1}${2}${3}'
        }

        # 6. Convert function X() as Void -> sub X()
        $content = $content -replace '(?<=^|\s)function\s+(\w+)\s*\(([^)]*)\)\s+as\s+Void', 'sub $1($2)'

        # 6. Remove type annotations from params: (param as Type) -> (param)
        for ($i = 0; $i -lt 3; $i++) {
            $content = $content -replace '(\w+)\s+as\s+(String|Integer|Boolean|Float|Double|Object|Dynamic|Void|AssocArray|Array|Node|ro[a-zA-Z]+)(?=[,\)])', '$1'
        }

        # 7. Remove return type annotations on non-Void functions (named and anonymous)
        $content = $content -replace '(?<=\bfunction\s*(?:\w+\s*)?\([^)]*\))\s+as\s+\w+(\.\w+)*', ''

        # 8. Line-by-line processing: track namespaces, prefix functions, fix closings
        $lines = $content -split "`r`n|`n"
        $funcStack = @()               # Stack of ('sub'|'function')
        $nsStack = @()                 # Stack of namespace parts (e.g. ['api', 'albums'])
        $nsFunctions = @{}             # Set of function names defined in current namespace
        $result = @()
        
        for ($i = 0; $i -lt $lines.Length; $i++) {
            $line = $lines[$i]
            $trimmed = $line.Trim()
            
            # Track namespace entries (but don't output the namespace line)
            if ($trimmed -match '^namespace\s+(\S+)') {
                $nsName = $matches[1]
                # Split dot-notation (e.g. api.albums -> ['api', 'albums']) and reset for root-level namespace
                $segments = $nsName -split '\.'
                if ($line -match '^\s+namespace') {
                    # Indented: nested namespace, push onto existing stack
                    foreach ($seg in $segments) {
                        $nsStack += $seg
                    }
                } else {
                    # Root-level: reset stack
                    $nsStack = $segments
                }
                $nsFunctions = @{}  # Reset function tracking for new namespace
                # Don't add this line to output
                continue
            }
            
            # Track namespace exits
            if ($trimmed -match '^end\s+namespace') {
                if ($nsStack.Count -gt 0) {
                    $nsStack = $nsStack[0..($nsStack.Count-2)]
                }
                continue
            }
            
            # Function/sub declaration: prefix with namespace, track stack
            if ($trimmed -match '^(sub|function)(\s+\w+|\s*\()') {
                $funcType = $matches[1]
                $funcStack += ,$funcType
                
                # If inside a namespace, prefix the function name
                if ($nsStack.Count -gt 0 -and $trimmed -match '\s+\w+') {
                    $nsPrefix = ($nsStack -join '_') + '_'
                    # Replace the first word after sub/function with ns-prefixed version
                    $line = $line -replace "($funcType\s+)(\w+)", "`$1${nsPrefix}`$2"
                }
                
                $result += $line
            } elseif ($trimmed -match '^end\s+(sub|function)') {
                $closingType = $matches[1]
                if ($funcStack.Count -gt 0) {
                    $openingType = $funcStack[-1]
                    $funcStack = $funcStack[0..($funcStack.Count-2)]
                    if ($openingType -ne $closingType) {
                        $result += $line -replace 'end\s+(sub|function)', "end $openingType"
                    } else {
                        $result += $line
                    }
                } else {
                    $result += $line
                }
            } else {
                $result += $line
            }
        }
        $content = $result -join "`r`n"

        Set-Content -Path $targetPath -Value $content
    } elseif ($fullPath -match '\.xml$') {
        # Fix XML script references: .bs -> .brs
        $content = Get-Content $fullPath -Raw
        $content = $content -replace '\.bs"', '.brs"'
        Set-Content -Path $targetPath -Value $content
    } else {
        Copy-Item -Path $fullPath -Destination $targetPath -Force
    }
}

# After transpiling, add <script> tags to MainScene.xml for all source .brs files
# (each component needs its own scope, so other components only get the source
#  files they actually need — added below on a per-component basis)
$mainSceneXml = Join-Path $OutDir "components\MainScene.xml"
if (Test-Path $mainSceneXml) {
    $xmlContent = Get-Content $mainSceneXml -Raw
    $xmlContent = $xmlContent -replace '<script[^>]*/>\s*', ''
    $sourceFiles = Get-ChildItem "$OutDir\source" -Recurse -Include *.brs | Sort-Object Name
    $scriptTags = @()
    foreach ($sf in $sourceFiles) {
        $relativePath = "pkg:/source/$($sf.Name)"
        if ($sf.DirectoryName -ne (Join-Path $OutDir "source")) {
            $subDir = $sf.DirectoryName.Substring((Join-Path $OutDir "source").Length + 1)
            $relativePath = "pkg:/source/$subDir/$($sf.Name)"
        }
        $scriptTags += "<script type=`"text/brightscript`" uri=`"$relativePath`" />"
    }
    $xmlContent = $xmlContent -replace '(</component>)', "$($scriptTags -join "`r`n        ")`r`n        `$1"
    Set-Content -Path $mainSceneXml -Value $xmlContent
    Write-Host "Added $($sourceFiles.Count) script references to MainScene.xml" -ForegroundColor Cyan
}

# Add source script tags to specific component XMLs that need cross-component function access.
# Inject shared library script tags into all component XMLs (every component needs misc.brs and session.brs).
$commonScripts = @(
    'pkg:/source/utils/misc.brs'
    'pkg:/source/utils/session.brs'
)
$libInjections = @{
    'AudioPlayerView.xml' = @(
        'pkg:/source/api/sdk.brs'
        'pkg:/source/api/baserequest.brs'
        'pkg:/source/api/Image.brs'
        'pkg:/source/api/Items.brs'
    )
    'VideoPlayerView.xml' = @(
        'pkg:/source/api/sdk.brs'
        'pkg:/source/api/baserequest.brs'
        'pkg:/source/api/Image.brs'
        'pkg:/source/api/Items.brs'
    )
    'WholphinSidebar.xml' = @(
        'pkg:/source/ShowScenes.brs'
        'pkg:/source/MainEventHandlers.brs'
        'pkg:/source/api/userauth.brs'
    )
}
# Inject common scripts into EVERY component XML that has a script tag
$allCompXmls = Get-ChildItem "$OutDir\components" -Recurse -Include "*.xml"
foreach ($compXml in $allCompXmls) {
    $xmlContent = Get-Content $compXml.FullName -Raw
    if ($xmlContent -match '<script type="text/brightscript"') {
        $tagsToAdd = @()
        foreach ($uri in $commonScripts) {
            if (-not $xmlContent.Contains($uri)) { $tagsToAdd += $uri }
        }
        if ($tagsToAdd.Count -gt 0) {
            $tagBlock = ""
            foreach ($uri in $tagsToAdd) { $tagBlock += "  <script type=""text/brightscript"" uri=""$uri"" />`r`n" }
            $xmlContent = $xmlContent -replace '(</component>)', "$tagBlock`$1"
            Set-Content -Path $compXml.FullName -Value $xmlContent
            Write-Host "Injected common scripts into $($compXml.Name)" -ForegroundColor Cyan
        }
    }
}
# Inject per-component extra scripts
foreach ($xmlName in $libInjections.Keys) {
    $compXml = Get-ChildItem "$OutDir\components" -Recurse -Include $xmlName | Select-Object -First 1
    if ($compXml -and (Test-Path $compXml)) {
        $xmlContent = Get-Content $compXml.FullName -Raw
        $ref = $libInjections[$xmlName][0]
        if (-not $xmlContent.Contains($ref)) {
            $tagBlock = ""
            foreach ($uri in $libInjections[$xmlName]) { $tagBlock += "  <script type=""text/brightscript"" uri=""$uri"" />`r`n" }
            $xmlContent = $xmlContent -replace '(</component>)', "$tagBlock`$1"
            Set-Content -Path $compXml.FullName -Value $xmlContent
            Write-Host "Injected library script tags into $xmlName" -ForegroundColor Cyan
        }
    }
}

# Post-processing: dynamically collect namespace paths from original source
# and replace namespace-qualified calls with underscored equivalents
$allNsFiles = Get-ChildItem $SourceDir -Recurse -Include *.bs,*.brs
$nsPathSet = @{}
foreach ($nsFile in $allNsFiles) {
    $nsLines = Get-Content $nsFile.FullName
    $nsStack = @()
    foreach ($nsLine in $nsLines) {
        if ($nsLine -match '^namespace\s+(\S+)') {
            $segments = $matches[1] -split '\.'
            $nsStack = $segments
            $nsPathSet[($nsStack -join '.')] = $true
        } elseif ($nsLine -match '^\s+namespace\s+(\S+)') {
            $segments = $matches[1] -split '\.'
            foreach ($seg in $segments) {
                $nsStack += $seg
                $nsPathSet[($nsStack -join '.')] = $true
            }
        } elseif ($nsLine -match '^\s*end\s+namespace') {
            if ($nsStack.Count -gt 0) {
                $nsStack = $nsStack[0..($nsStack.Count-2)]
            }
        }
    }
}
$knownNamespaces = $nsPathSet.Keys | Sort-Object Length -Descending
Write-Host "Found $($knownNamespaces.Count) namespace paths for call-site rewriting" -ForegroundColor DarkYellow

Get-ChildItem "$OutDir" -Recurse -Include *.brs | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $changed = $false
    foreach ($ns in $knownNamespaces) {
        $nsUnderscored = $ns -replace '\.', '_'
        $pattern = [regex]::Escape($ns) + '\.(\w+)\s*\('
        $replacement = $nsUnderscored + '_' + '$1('
        if ($content -match $pattern) {
            $content = $content -replace $pattern, $replacement
            $changed = $true
        }
    }
    if ($changed) {
        Set-Content -Path $_.FullName -Value $content
    }
}

Write-Host "Transpile complete! ($count BS files processed)" -ForegroundColor Green
