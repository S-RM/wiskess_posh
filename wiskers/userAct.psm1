
function userActFun($artHash, $outDir, $toolPath, $wiskessLog) {
    # SBE
    $funCall = "{0}\Get-ZimmermanTools\SBECmd.exe" -f $toolPath
	$funArgs = '-d "{1}" --csv "{2}"' -f $toolPath, $artHash.user_dir, $outDir
    FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile "*.csv" -wiskessLog $wiskessLog
    
    # JLECmd
    $funCall = "{0}\Get-ZimmermanTools\JLECmd.exe" -f $toolPath
	$funArgs = '-d "{1}" --csv "{2}" -q' -f $toolPath, $artHash.user_dir, $outDir
    FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile "*Destinations.csv" -wiskessLog $wiskessLog

    # WxTCmd
    # hindsight - uses own implementation of foreeach parallel due to loop of chrome dir
    $WxTCmd = "{0}" -f $artHash.actCache
    Get-ChildItem $WxTCmd | ForEach-Object -Parallel { 
        $outFile = "WxTCmd_ActivitiesCache"
        $funCall = "{0}\Get-ZimmermanTools\WxTCmd.exe" -f $using:toolPath
        $funArgs = ' -f "{0}" --csv "{1}\{2}"' -f $_, $using:outDir, "WxTCmd_ActivitiesCache"
        Import-Module "$using:toolPath\wiskers\ops.psm1"
        Import-Module "$using:toolPath\wiskers\printer.psm1"
        FunCaller -funCall $funCall -funArgs $funArgs -outDir $using:outDir -outFile "$outFile*" -wiskessLog $using:wiskessLog
    }
}
Export-ModuleMember -Function userActFun