function getArt($artSource, $wiskessLog, $outFilePath, $noVelociraptor, $toolPath) {
    OutputMessage -msg "Get the artefacts at source: $artSource" -wiskessLog $wiskessLog
    $outDir = "$outFilePath\Artefacts"
    $collectFile = "velociraptor_collect.zip"
    if ($noVelociraptor -eq $True) {
        # Get the minimum needed
        $funCall = "{0}\tools\velociraptor-v0.6.0-windows-amd64.exe" -f $toolPath
        $funArgs = '-v artifacts collect Windows.KapeFiles.Targets --output "{0}\{1}" --args Device="{2}" --args _J=Y --args _MFT=Y --args _WBEM=Y --args _Prefetch=Y --args LogFiles=Y --args RecycleBin=Y --args WindowsTimeline=Y --args LNKFilesAndJumpLists=Y --args RegistryHivesUser=Y --args BrowserCache=Y --args PowerShellConsole=Y --args Antivirus=Y --args EventLogs=Y' -f $outDir, $collectFile, $artSource
    } else {
        $funCall = "{0}\tools\velociraptor-v0.6.0-windows-amd64.exe" -f $toolPath
        $funArgs = '-v artifacts collect Windows.KapeFiles.Targets --output "{0}\{1}" --args Device="{2}" --args KapeTriage=Y --args LogFiles=Y --args _SANS_Triage=Y --args Notepad=Y --args MemoryFiles=Y' -f $outDir, $collectFile, $artSource
    }
    FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile $collectFile -wiskessLog $wiskessLog -infoMsg "Please wait, this often takes 10-30 mins." -timeout 1200
    $funCall = '7z'
    $funArgs = 'x "{0}\{1}" -o"{2}" -aos' -f $outDir, $collectFile, $outDir
    $zip_flag = "zip_done.flag"
    FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile $zip_flag -doneFlag -wiskessLog $wiskessLog -timeout 1200
    return "$outFilePath\Artefacts\$($artSource.Replace(':',''))"
}
Export-ModuleMember -Function getArt

function chkArt($artSource, $wiskessLog, $dataSource, $noInput, $noVelociraptor) {
    # Check if the artefacts exist at the artSource, and ask the user to enter file paths not found or ignore
    OutputMessage -msg "Checking the default file paths of the artefacts, at source: $artSource" -wiskessLog $wiskessLog
    $artHash = @{
        source = "$dataSource"
        base = "$artSource"
        j_file = "$artSource"+'\$Extend\$UsnJrnl$J'
        mft = "$artSource"+'\$MFT'
        recycle_bin = "$artSource"+'\$Recycle.Bin'
        pagefile = "$artSource\pagefile.sys"
        user_dir = "$artSource\Users"
        consolehost_history = "$artSource\Users\*\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
        amcache = "$artSource\Windows\AppCompat\Programs\Amcache.hve"
        recentFileCache = "$artSource\Windows\AppCompat\Programs\RecentFileCache.bcf"
        prefetch = "$artSource\Windows\Prefetch"
        system32 = "$artSource\Windows\System32"
        system = "$artSource\Windows\System32\config\SYSTEM"
        sum = "$artSource\Windows\System32\LogFiles\Sum"
        objects = "$artSource\Windows\System32\wbem\Repository\OBJECTS.DATA"
        winevt = "$artSource\Windows\System32\winevt\Logs"
        chrome = "$artSource\Users\*\AppData\Local\Google\Chrome\User Data\Default"
        actCache = "$artSource\Users\*\AppData\Local\ConnectedDevicesPlatform\*\ActivitiesCache.db"
    }

    $artHash_Legacy = @{
        recycle_bin = "$artSource"+'\RECYCLER'
        user_dir = "$artSource\Documents and Settings"
        consolehost_history = "$artSource\Documents and Settings\*\Local Settings\Application Data\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
        objects = "$artSource\WINDOWS\system32\wbem\Repository\FS\OBJECTS.DATA"
        winevt = "$artSource\WINDOWS\system32\config"
        chrome = "$artSource\Documents and Settings\*\Local Settings\Application Data\Google\Chrome\User Data\Default"
    }

    $artHash.keys.Clone() | ForEach-Object {
        if ($(Test-Path $artHash[$_]) -eq $False) {
            $msg = 'Artefact, {0}, not found at file path: {1}' -f $_, $artHash[$_]
            OutputMessage -msg $msg -type "warn" -wiskessLog $wiskessLog

            # Write-Host "artSource: $artSource."
            # Write-Host "artHash: $($artHash[$_])."
            # Write-Host "fd_string_search: $($($artHash[$_]).Replace($artSource,''))."

            # $fd_path = ""
            # if ("" -ne $(Split-Path -Path $artHash[$_] -Extension)) {
            #     $fd_path = fd --fixed-strings -p -a -t f $($artHash[$_]).Replace("$artSource","") "$dataSource"
            # } else {
            #     $fd_path = fd --fixed-strings -p -a -t d $($artHash[$_]).Replace("$artSource","") "$dataSource"
            # }
            # if ($fd_path -ne "") {
            #     $artHash[$_] = $fd_path
            #     OutputMessage -msg "Changed path to: $fd_path"
            #     return
            # }

            $artOrigin = $artHash[$_].Replace("$artSource", "$dataSource")
            OutputMessage -msg "Checking the origin of the artefact at: $artOrigin" -wiskessLog $wiskessLog 

            if ($(Test-Path $artOrigin) -eq $False) {
                $artOriginLegacy = ""
                if ($artHash_Legacy[$_]) {
                    $artOriginLegacy = $artHash_Legacy[$_].Replace("$artSource", "$dataSource")
                    OutputMessage -msg "Checking the legacy path: $artOriginLegacy" -wiskessLog $wiskessLog 
                }
                if ($(Test-Path $artOriginLegacy) -eq $True) {
                    $artHash[$_] = $artOriginLegacy
                    $msg = '{0}' -f $artHash[$_]
                    OutputMessage -msg "Changed path to: $msg"
                } else {
                    OutputMessage -msg "File not found." -type "err" -wiskessLog $wiskessLog 
                    $repPath = getInput -msg "Enter the file path (type 'none' or press enter for default)" -noInput $noInput -wiskessLog $wiskessLog
                    if ($repPath -ne "none" -and $repPath -ne "") {
                        $artHash[$_] = $repPath
                    }
                }
            } else {
                $artHash[$_] = $artOrigin
                $msg = '{0}' -f $artHash[$_]
                OutputMessage -msg "Changed path to: $msg"
            }
        }
    }

    return $artHash
}
Export-ModuleMember -Function chkArt