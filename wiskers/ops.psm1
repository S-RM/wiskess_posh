function MakeDir($outDir, $wiskessLog) {     
    if ($(Test-Path -PathType Container -Path "$outDir") -eq $False) {
        # Create the output directory if not available
        OutputMessage -msg "File path, $outDir, does not exist, creating..." -type "info" -wiskessLog $wiskessLog
        $null = New-Item -ItemType directory -Path "$outDir" -ErrorAction SilentlyContinue
    }
}
Export-ModuleMember -Function MakeDir

function HandleProcess($process, $timeout, $wiskessLog, $stdoutSave) {
    # Give the process some CPU time, then continue operation if the CPU is less than 40-percent, otherwise give another wait before continuing
    $timeout_process = $null
    if ($process) {
        $process | Wait-Process -Timeout $timeout -ErrorAction SilentlyContinue -ErrorVariable timeout_process
    }
    if ($timeout_process) {
        $cpu_process = ($process | Get-Process).CPU
        if ($cpu_process -ge 40) {
            $msg = "Process {0} is running at greater or equal to 40 percent CPU. Waiting for another {1} secs before continuing..." -f ($process | Get-Process).ProcessName, $timeout
            OutputMessage -msg $msg -type 'warn'
            $timeout_process = $null
            $process | Wait-Process -Timeout $timeout -ErrorAction SilentlyContinue -ErrorVariable timeout_process
            if ($timeout_process) {
                if ($stdoutSave) {
                    $msg = "Process {0} is running at CPU: {1}, and I need to wait for it to complete. Waiting another {2} secs." -f ($process | Get-Process).ProcessName, ($process | Get-Process).CPU, $timeout
                    OutputMessage -msg $msg
                    $timeout_process = $null
                    $process | Wait-Process -Timeout $timeout -ErrorAction SilentlyContinue -ErrorVariable timeout_process
                    if ($timeout_process) {
                        $msg = "OK. I've waited {0} secs. Time to continue." -f $($timeout * 3)
                        OutputMessage -msg $msg
                    }
                } else {
                    $msg = "Process {0} is running at CPU: {1}, but I'll continue the other operations." -f ($process | Get-Process).ProcessName, ($process | Get-Process).CPU
                    OutputMessage -msg $msg                    
                }
            }
        }
    }
}

# Call the functions using the function caller
# optional: $doneFlag create the output file even if there were no findings to prevent running again
# optional: $ignore_exists overwrite or just ignore existance of $outFile
# optional: $noLog if the function shouldn't output to the wiskess log, or the function doesn't output unicode
function FunCaller($funCall, $funArgs, $outDir, $outFile, $infoMsg, $endMsg, [switch]$doneFlag, [switch]$ignore_exists, [switch]$noLog, [switch]$stdoutSave, $timeout, $wiskessLog) {
    # Do some logging
    "" | Out-File -Append -Encoding utf8 "$wiskessLog"
    OutputMessage -msg "Executing command: $funCall $funArgs, outDir: $outDir, outFile: $outFile" -type "info" -wiskessLog $wiskessLog
    # Do some checks and execute
    if ($infoMsg -ne $null) {
        # Output any information message prior
        OutputMessage -msg "$infoMsg" -type "warn" -wiskessLog $wiskessLog
    }
    MakeDir -outDir $outDir -wiskessLog $wiskessLog
    if ($(Test-Path -PathType Leaf "$outDir\$outFile*") -eq $False -or $ignore_exists) {
        # Note: asterisk is after $outFile. Might need to sanitize whatever is put into $funCall
        if ($funArgs) {
            $stdoutFile = "{0}wiskessstdout{1}.txt" -f $funCall, $(New-Guid)
            $erroutFile = "{0}wiskesserrout{1}.txt" -f $funCall, $(New-Guid)
            $process = Start-Process -FilePath $funCall -ArgumentList $funArgs -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutFile -RedirectStandardError $erroutFile
            if($timeout -lt 600) { $timeout = 600 }
            HandleProcess -process $process -timeout $timeout -wiskessLog $wiskessLog -stdoutSave $stdoutSave
            # Save the output and error files
            if ($stdoutSave) {
                OutputMessage -msg "Saving stdout file, $stdoutFile, as results, here: $outDir\$outFile" -wiskessLog $wiskessLog
                Copy-Item $stdoutFile "$outDir\$outFile"
            }
            $stdoutFile, $erroutFile | ForEach-Object { 
                if (!$noLog) { Get-Content $_ | Out-File -Append $wiskessLog -Encoding utf8 }
                if ($(Test-Path -PathType Leaf -Path $_) -eq $True) {
                    Remove-Item $_ -ErrorAction SilentlyContinue
                }
            }
        } else {
            OutputMessage -msg "No arguments supplied to function call $funCall. Please check and enter an argument, or empty string" -type 'err' -wiskessLog $wiskessLog
        }
        if ($doneFlag) { $null = New-Item -Path "$outDir\$outFile" -ErrorAction SilentlyContinue }
    } else {
       OutputMessage -msg "Output file exist, not overwritting. If you want to run this module again, delete this file: $outDir\$outFile" -wiskessLog $wiskessLog
    }
    if ($endMsg -ne $null) {
        # Output any end message after
        OutputMessage -msg "$endMsg" -wiskessLog $wiskessLog
    }
    OutputMessage -msg "Done - $funCall" -wiskessLog $wiskessLog
}
Export-ModuleMember -Function FunCaller

function Start-Parallel($artProps, $toolPath, $wiskessLog) {
    $tempDir = "$toolPath\temp_out"
    MakeDir -outDir "$tempDir"
    $artProps.keys.Clone() | ForEach-Object -Parallel {
        $artProp = $using:artProps
        $tempFn = "{0}\{1}.txt" -f $using:tempDir, $(New-Guid)
        Import-Module "$using:toolPath\wiskers\ops.psm1"
        Import-Module "$using:toolPath\wiskers\printer.psm1"
        if ($artProp.$_.stdoutSave -eq $True) {
            FunCaller -funCall $artProp.$_.funCall -funArgs $artProp.$_.funArgs -outDir $artProp.$_.outDir -outFile $artProp.$_.outFile -wiskessLog "$tempFn" -stdoutSave $artProp.$_.stdoutSave -timeout $artProp.$_.timeout
        } else {
            FunCaller -funCall $artProp.$_.funCall -funArgs $artProp.$_.funArgs -outDir $artProp.$_.outDir -outFile $artProp.$_.outFile -wiskessLog "$tempFn" -timeout $artProp.$_.timeout
        }
    }
    Get-ChildItem "$tempDir" | ForEach-Object { Get-Content $_ | Out-File -Append "$wiskessLog" }
    Remove-Item -Force -Recurse -Path "$tempDir" -ErrorAction SilentlyContinue
}
Export-ModuleMember -Function Start-Parallel

# Remove the temporary files, in case any weren't done during processing
function Clear-TmpFiles {
    "wiskesserrout", "wiskessstdout" | ForEach-Object {
        Get-ChildItem -Recurse -Filter "*$_*.txt" | Remove-Item
    }
}
Export-ModuleMember -Function Clear-TmpFiles

function runFunctions($artSource, $artHash, $outFilePath, $toolPath, $lookbackDays, $iocFile, $dataSource, $clawsOut, $wmiParse, $noInput, $timeArgs, $wiskessLog) {
    # Quick Triage
    quickFun -artSource $artSource -artHash $artHash -outFilePath $outFilePath -toolPath $toolPath -lookbackDays $lookbackDays -wiskessLog $wiskessLog
    # FileExecution
    fileExeFun -artHash $artHash -outDir "$outFilePath\Analysis\FileExecution" -toolPath $toolPath -clawsOut $clawsOut -wmiParse $wmiParse -wiskessLog $wiskessLog
    # User Activity
    userActFun -artHash $artHash -outDir "$outFilePath\Analysis\UserActivity" -toolPath $toolPath -wiskessLog $wiskessLog
    # Network
    netFun -artHash $artHash -outDir "$outFilePath\Analysis\Network" -toolPath $toolPath -wiskessLog $wiskessLog
    # Registry
    regFun -artHash $artHash -outDir "$outFilePath\Analysis\Registry" -toolPath $toolPath -wiskessLog $wiskessLog
    # FileSystem
    fileFun -artHash $artHash -outDir "$outFilePath\Analysis\FileSystem" -toolPath $toolPath -wiskessLog $wiskessLog
    # Event Logs
    eventLogFun -artHash $artHash -outDir "$outFilePath\Analysis\EventLogs" -toolPath $toolPath -clawsOut $clawsOut -wiskessLog $wiskessLog

    # Timeline
    timeFun -outDir "$outFilePath\Analysis\Timeline" -toolPath $toolPath -outFilePath $outFilePath -timeArgs $timeArgs -wiskessLog $wiskessLog

    # IOC search
    if ($(Test-Path -PathType Leaf -Path "$iocFile") -eq $True) {
        iocFun -artHash $artHash -outDir "$outFilePath\Analysis\FindingsIOCs" -toolPath $toolPath -iocFile $iocFile -outFilePath $outFilePath -dataSource $dataSource -clawsOut $clawsOut -noInput $noInput -wiskessLog $wiskessLog
    } else {
        OutputMessage -msg "No ioc file found. Please add IOCs to the file and run again." -type 'warn' -wiskessLog $wiskessLog
    }
    
}
Export-ModuleMember -Function runFunctions
