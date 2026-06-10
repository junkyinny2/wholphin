$outFile = "D:\VibeCode\wholphin\debug_output.txt"
$j = Start-Job -ScriptBlock { param($s) & $s } -ArgumentList "D:\VibeCode\wholphin\rokudebug.ps1"
Start-Sleep -Seconds 30
$result = Receive-Job -Job $j
$result | Out-File $outFile
Stop-Job $j
Remove-Job $j -Force
Get-Content $outFile
