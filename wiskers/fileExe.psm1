function fileExeFun($artHash, $outDir, $toolPath, $clawsOut, $wmiParse, $wiskessLog) {
    # AppCompatCache
    $outFile = "appcompatcache.csv"
    $funCall = "{0}\Get-ZimmermanTools\AppCompatCacheParser.exe" -f $toolPath
	$funArgs = '-f "{1}" --csv "{2}" --csvf "{3}"' -f $toolPath, $artHash.system, $outDir, $outFile
    FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile $outFile -wiskessLog $wiskessLog

    # AmcacheParser
    $funCall = "{0}\Get-ZimmermanTools\AmcacheParser.exe" -f $toolPath
	$funArgs = '-f "{1}" --csv "{2}" -i' -f $toolPath, $artHash.amcache, $outDir
    FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile "*_Amcache_*" -wiskessLog $wiskessLog

    # RecentFileCacheParser
    $outFile = "RecentFileCache.csv"
    $funCall = "{0}\Get-ZimmermanTools\RecentFileCacheParser.exe" -f $toolPath
	$funArgs = '-f "{1}" --csv "{2}" --csvf "{3}"' -f $toolPath, $artHash.recentFileCache, $outDir, $outFile
    FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile $outFile     -wiskessLog $wiskessLog

    # SCCM Recently Used Apps
    $outFile = "SCCM_RecentlyUsedApplication.psv"
    $funCall = "py"
	$funArgs = '{0}\tools\CCM_RUA_Finder.py -i "{1}" -o "{2}\{3}"' -f $toolPath, $artHash.objects, $outDir, $outFile
    FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile $outFile -wiskessLog $wiskessLog

    # WMIPersistenceFinder
    $outFile = "PyWMIPersistenceFinder.txt"
    $funCall = 'py'
    $funArgs = '-3 "{0}\tools\PyWMIPersistenceFinder.py" "{1}"' -f $toolPath, $artHash.objects
    FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile $outFile -stdoutSave -wiskessLog $wiskessLog
   
    # Prefetch
    $outFile = "prefetch.csv"
    $funCall = "{0}\Get-ZimmermanTools\PECmd.exe" -f $toolPath
	$funArgs = '-d "{1}" --csv "{2}" --csvf "{3}" --vss --mp -q' -f $toolPath, $artHash.prefetch, $outDir, $outFile
    FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile $outFile -wiskessLog $wiskessLog

    # WMIPers
    $outFile = "WMI-Objects.txt"
    $funCall = 'py'
    $funArgs = '-3 "{0}\tools\WMIPers.py" "{1}"' -f $toolPath, $artHash.objects
    FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile $outFile -stdoutSave -wiskessLog $wiskessLog
    
    # SqlECmd
    $funCall = "{0}\Get-ZimmermanTools\SQLECmd\SQLECmd.exe" -f $toolPath
	$funArgs = '-f "{0}" --csv "{1}"' -f $artHash.mcafee_edrtrace, $outDir
    FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile "*_Trace_Data*.csv" -wiskessLog $wiskessLog

    if ($wmiParse) {
        # python-cim WMI Class Names, Timeline, Class Defs, Consumer Bindings
        $inDir = $artHash.objects -replace 'OBJECTS.DATA',''
        $funCall = "py"
        $outFile = "wmi_class_names.csv"
        $funArgs = '-2 {0}\tools\python-cim\auto_carve_class_names.py {1}' -f $toolPath, $inDir
        FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile $outFile -stdoutSave -wiskessLog $wiskessLog
        $outFile = "wmi_timeline.csv"
        $funArgs = '-2 {0}\tools\python-cim\timeline.py {1}' -f $toolPath, $inDir
        FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile $outFile -stdoutSave -wiskessLog $wiskessLog
        $outFile = "wmi_class_definitions.csv"
        $funArgs = '-2 {0}\tools\python-cim\auto_carve_class_definitions.py {1}' -f $toolPath, $inDir
        FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile $outFile -stdoutSave -wiskessLog $wiskessLog
        $outFile = "wmi_filtertoconsumerbindings.csv"
        $funArgs = '-2 {0}\tools\python-cim\show_filtertoconsumerbindings.py win7 {1}' -f $toolPath, $inDir
        FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile $outFile -stdoutSave -wiskessLog $wiskessLog
        # $outFile = "wmi_find_bytes.csv"
        # $funArgs = '-2 {0}\tools\python-cim\find_bytes.py {1} > "{2}\{3}"' -f $toolPath, $inDir, $outDir, $outFile
        # FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile $outFile -wiskessLog $wiskessLog
            # looping through IOCs or common : '<#','==','TVqAA','ps1','mattifestation','zMzM'
            # if find_bytes.py 
            # using the hex code of the physical: 
            #      dump_page.py
    }
}
Export-ModuleMember -Function fileExeFun