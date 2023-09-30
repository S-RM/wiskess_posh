
function quickFun($artSource, $artHash, $outFilePath, $toolPath, $lookbackDays, $wiskessLog) {
    # PowerShell PSReadLine\ConsoleHost_history
    $outDir = "$outFilePath\Analysis\PSReadLine"
    $hist = "{0}" -f $artHash.consolehost_history
    MakeDir -outDir $outDir -wiskessLog $wiskessLog
    Get-ChildItem $hist | ForEach-Object { 
        $fn = $($_ -Replace '.*Users\\([^\\]+).+','$1_ConsoleHost_history.txt'); 
        Get-Content $_ | Out-File -FilePath "$outDir\$fn" 
    }
    
    # TODO: Find binaries or scripts in the usual suspect locations: \temp, \windows\temp, %AppData%\Local\Temp, \Users\*\, unsigned DLL in System32
}
Export-ModuleMember -Function quickFun