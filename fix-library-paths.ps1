param(
    [Parameter(Mandatory=$true)]
    [string]$StagingDir
)

$brsFiles = Get-ChildItem -Path $StagingDir -Recurse -Filter "*.brs"
$fixedCount = 0

foreach ($file in $brsFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    if ($content -match 'Library "pkg:/[^"]+\.bs"') {
        $newContent = $content -replace 'Library "pkg:/([^"]+)\.bs"', 'Library "pkg:/$1.brs"'
        Set-Content -Path $file.FullName -Value $newContent -NoNewline
        $fixedCount++
    }
}

Write-Host "[fix-library-paths] Fixed $fixedCount file(s) in $StagingDir"
