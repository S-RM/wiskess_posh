function regFun($artHash, $outDir, $toolPath, $wiskessLog) {
    # RECmd Batch_MC
    $outFile = "reg-System.csv"
    $funCall = "{0}\Get-ZimmermanTools\RECmd\RECmd.exe" -f $toolPath
	$funArgs = '--bn "{0}\Get-ZimmermanTools\RECmd\BatchExamples\Kroll_Batch.reb" --nl=false -d "{1}" --csv "{2}" --csvf "{3}"' -f $toolPath, $($artHash.system -Replace '\\SYSTEM$',''), $outDir, $outFile
    FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile $outFile -wiskessLog $wiskessLog

    # RECmd Batch_MC
    $outFile = "reg-User.csv"
    $funCall = "{0}\Get-ZimmermanTools\RECmd\RECmd.exe" -f $toolPath
	$funArgs = '--bn "{0}\Get-ZimmermanTools\RECmd\BatchExamples\Kroll_Batch.reb" --nl=false -d "{1}" --csv "{2}" --csvf "{3}"' -f $toolPath, $artHash.user_dir, $outDir, $outFile
    FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile $outFile -wiskessLog $wiskessLog
}
Export-ModuleMember -Function regFun