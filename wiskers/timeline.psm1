function timeFun($outDir, $toolPath, $outFilePath, $timeArgs, $wiskessLog) {
    # timeline with polars library
    $outFile = "all.csv"
    $funCall = "py" -f $toolPath
	$funArgs = '{0}\tools\polars_tln.py "{1}" {2} {3}' -f $toolPath, $outFilePath, $timeArgs.time_start, $timeArgs.time_end
    FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile $outFile -wiskessLog $wiskessLog
    
    # host info report with polars
    $outFile = "Host Information.txt"
    $funCall = "py" -f $toolPath
	$funArgs = '{0}\tools\polars_hostinfo.py "{1}"' -f $toolPath, $outFilePath
    FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile $outFile -wiskessLog $wiskessLog
}
Export-ModuleMember -Function timeFun