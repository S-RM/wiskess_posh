function eventLogFun($artHash, $outDir, $toolPath, $clawsOut, $wiskessLog) {
    if ($(Get-ChildItem $($artHash.winevt) -filter "*.evt").Length -gt 0) {
        # For legacy Windows, if there are any event logs with the extension .evt: Copy and convert any with wevtutil
        $eventlog_art_folder = $outDir -replace "Analysis\\EventLogs","Artefacts\EventLogs_legacy"
        mkdir "$eventlog_art_folder"
        OutputMessage -msg "Copying $($artHash.winevt) to $eventlog_art_folder"
        # Robocopy.exe "$($artHash.winevt)" "$eventlog_art_folder" *.evt* /R:0 /W:0 /mt:32 /XF Archive-Security* 
        Get-ChildItem "$($artHash.winevt)" -filter "*.evt" | ForEach-Object { 
            OutputMessage -msg "Converting legacy EVT log $_"
            wevtutil epl "$_" "$eventlog_art_folder\$($_.Name)x" /lf:true 
        }
        if ($(Get-ChildItem $($eventlog_art_folder) -filter "*.evtx").Length -gt 0) {
            $artHash.winevt = $eventlog_art_folder
        }
    }
    $artProps = @{
        "hayabusa" = @{   
            "outFile" = "hayabusa.csv"
            "outDir" = "$outDir"
            "funCall" = '{0}\hayabusa\hayabusa.exe' -f $toolPath
            "funArgs" = 'csv-timeline -d "{1}" -o "{2}\{3}" -H "{2}\{4}" -p timesketch-verbose --ISO-8601' -f $toolPath, $artHash.winevt, "$outDir", "hayabusa.csv", "hayabusa.html"
            "timeout" = 1200
        }
        "evtxcmd" = @{
            "outFile" = "EvtxECmd-All.csv"
            "outDir" = "$outDir"
            "funCall" = "{0}\Get-ZimmermanTools\EvtxECmd\EvtxECmd.exe" -f $toolPath
            "funArgs" = '-d "{1}" --csv "{2}" --csvf "{3}"' -f $toolPath, $artHash.winevt, $outDir, "EvtxECmd-All.csv"
        }
    }
    Start-Parallel -artProps $artProps -toolPath $toolPath -wiskessLog $wiskessLog

    $artProps = @{
        "hayabusa" = @{   
            "outFile" = "hayabusa.json"
            "outDir" = "$outDir"
            "funCall" = '{0}\hayabusa\hayabusa.exe' -f $toolPath
            "funArgs" = 'json-timeline -L -d "{1}" -o "{2}\{3}" -p timesketch-verbose --ISO-8601' -f $toolPath, $artHash.winevt, "$outDir", "hayabusa.json"
            "timeout" = 1200
        }
    }
    Start-Parallel -artProps $artProps -toolPath $toolPath -wiskessLog $wiskessLog

    if ($clawsOut) {
        $artProps = @{
            "chainsaw_evtx" = @{
                "outFile" = "*.csv"
                "outDir" = "$outDir\chainsaw"
                "funCall" = "{0}\chainsaw\target\release\chainsaw.exe" -f $toolPath
                "funArgs" = 'hunt "{1}" -s "{0}\sigma" -r "{0}\tools\chainsaw\rules" --mapping "{0}\tools\chainsaw\mappings\sigma-event-logs-all.yml" --csv -o "{2}" --full --skip-errors' -f $toolPath, $artHash.winevt, "$outDir\chainsaw"
                "timeout" = 1200
            }
        }
        Start-Parallel -artProps $artProps -toolPath $toolPath -wiskessLog $wiskessLog
    }
}
Export-ModuleMember -Function eventLogFun