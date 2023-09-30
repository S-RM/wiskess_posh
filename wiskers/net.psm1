function netFun($artHash, $outDir, $toolPath, $wiskessLog) {
    # SrumECmd
    $funCall = "{0}\Get-ZimmermanTools\SrumECmd.exe" -f $toolPath
	$funArgs = '-d "{1}" --csv "{2}"' -f $toolPath, $artHash.system32, $outDir
    FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile "*SrumECmd*.csv" -wiskessLog $wiskessLog

    # Browsing History
    $outFile = "BrowsingHistory.csv"
    $funCall = "{0}\tools\BrowsingHistoryView.exe" -f $toolPath
	$funArgs = '/historysource 3 /historysourcefolder "{1}" /visittimefiltertype 1 /showTimeInGMT 1 /scomma "{2}\{3}"' -f $toolPath, $artHash.user_dir, $outDir, $outFile
    FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile $outFile -wiskessLog $wiskessLog
    
    # hindsight - uses own implementation of foreeach parallel due to loop of chrome dir
    $chrome = "{0}" -f $artHash.chrome
    Get-ChildItem $chrome | ForEach-Object -Parallel { 
        $outFile = $($_ -Replace '.*Users\\([^\\]+).*','Hindsight_$1_ChromeHist')
        $funCall = "{0}\tools\hindsight.exe" -f $using:toolPath
        $funArgs = ' -i "{0}" -l "{1}\hindsight.log" -o "{1}\{2}"' -f $_, $using:outDir, $outFile
        Import-Module "$using:toolPath\wiskers\ops.psm1"
        Import-Module "$using:toolPath\wiskers\printer.psm1"
        FunCaller -funCall $funCall -funArgs $funArgs -outDir $using:outDir -outFile "$outFile*" -wiskessLog $using:wiskessLog
    }

    # SumECmd
    $outFile = "*SumECmd*.csv"
    $sum = $artHash.sum
    If($(Test-Path -PathType Container -Path "$sum") -eq $True -and $(Test-Path -Path "$outDir\$outFile") -eq $False) {
        if ($sum.length -le 32) {
            # the path of sum is on the main drive, copy the files to avoid permissions
            MakeDir -outDir "$outDir\SumArtefacts" -wiskessLog $wiskessLog
            Copy-Item -Path "$sum" -Filter "*.mdb" -Destination "$outDir\SumArtefacts" -Recurse
            $sum = "$outDir\SumArtefacts"
        }
        esentutl.exe /r svc /i /s "$sum" /l "$sum"
        Get-ChildItem -Filter "*.mdb" "$sum" | % {esentutl.exe /p $_.FullName /f $_.FullName /o}
        if ($(Test-Path -PathType Container "$outDir\SumArtefacts")) {
            # Remove the Sum artefacts after processing
            Remove-Item -Force -Recurse "$outDir\SumArtefacts"
        }
    }
    $funCall = "{0}\Get-ZimmermanTools\SumECmd.exe" -f $toolPath
    $funArgs = '-d "{0}" --csv "{1}"' -f $sum, $outDir
    FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile $outFile -wiskessLog $wiskessLog

    # SqlECmd
    $funCall = "{0}\Get-ZimmermanTools\SQLECmd\SQLECmd.exe" -f $toolPath
	$funArgs = '-f "{0}" --csv "{1}"' -f $artHash.mcafee_nflow, $outDir
    FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile "*netflow*.csv" -wiskessLog $wiskessLog

    # TODO: bmc_tools
}
Export-ModuleMember -Function netFun