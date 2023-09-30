# Output info message
function OutputMessage($msg, $type, $wiskessLog) {
    switch($type) {
        'info' { $msg = "[*] $msg"; Write-Host $msg -ForegroundColor Magenta }
        'err' { $msg = "[!] $msg"; Write-Host $msg -ForegroundColor White -BackgroundColor DarkRed }
        'warn' { $msg = "[-] $msg"; Write-Host $msg -ForegroundColor Black -BackgroundColor Yellow }
        'good' { $msg = "[+] $msg"; Write-Host $msg -ForegroundColor White -BackgroundColor DarkGreen }
        default { $msg = "[ ] $msg"; Write-Host $msg }
    }
    if ($wiskessLog) {
        "$msg" | Out-File -Append -Encoding utf8 "$wiskessLog"
    }
}
Export-ModuleMember -Function OutputMessage

function getInput($msg, $noInput, $wiskessLog) { 
    if (!$noInput) {
        $ans = read-host -Prompt "[?] $msg"
        "$msg $ans" | Out-File -Append -Encoding utf8 "$wiskessLog"
        return $ans
    }
    return "none"
}
Export-ModuleMember -Function getInput

function genReport ($outFilePath) {
    gci -Recurse "$outFilePath\Analysis" | Where-Object {$_.Length -gt 0 -and !$_.PSIsContainer} | Select FullName,Length | Out-File -Width 10000 "$outFilePath\Analysis\Analysis-Report.txt" -Encoding utf8
}
Export-ModuleMember -Function genReport
