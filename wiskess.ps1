<#
.SYNOPSIS
   This script uses multiple tools including APT Hunter, Zircolite, Chainsaw, EZ-Tools, Thor, SCCM Recently Used, 
   WMI Persistence, python-cim, Browsing History, Hindsight, ripgrep, velociraptor, and more can be added.
.DESCRIPTION
   Requirements: run setup.ps1 using PowerShell as Administrator
   
   Usage:
   * Mount the image to a drive, i.e. using Arsenal Image Mounter. Can be skipped if using a folder of artefacts.
   * Provide the file path to the artefacts. Such as the drive it has been mounted, being the drive letter it was originally located on. 
        Or the file path to the folder it was extracted/downloaded to.
   * Provide the output path, where you want to store collected artefacts and the results.
   * Add your indicators to a file, you can call it iocs.txt and place it in the same folder as wiskess.ps1, or 
        specify the location of your file with the flag -iocFile "path_to_your_iocs.txt"
   * The script has a set of predefined locations of Windows artefacts, which it uses to pass to the right parser.
        If the artefact is not found at the default location, it will ask the user to enter the path to it.

   Developers:
   If wanting to add a module to run, such as an executable, you need the command line to execute, the file path 
   where the artefact is expected to be and the choice of a module type:
    * Quick
    * EventLogs
    * FileExecution
    * UserActivity
    ...
    The file path of the artefact needs to be added to the $artHash hash, located in the artefacts.psm1 module. Make sure if the path
    ends in a directory to omit the last backslash, and the path has $artSource\ as a prefix.
    i.e. to add my_new_art_source that is located at path: "$artSource\new\file\path\for\my\artefact". 
        $artHash = @{
            base = "$artSource"
            my_new_art_source = "$artSource\new\file\path\for\my\artefact"
    Then in your module, you would access the file path using $artHash.my_new_art_source
    i.e.
        $outDir = "$outFilePath\Analysis\EventLogs"
        $outFile = "my_output_file.csv"
        $funCall = 'py' 
        $funArgs = '"{0}\my_tool_path\my_script.py" --input "{1}" -output "{2}\{3}"' -f $toolPath, $artHash.my_new_art_source, $outDir, $outFile
        FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile $outFile -wiskessLog $wiskessLog


.PARAMETER dataSource
    Required. The drive letter the image is mounted on.
.PARAMETER outFilePath
    Required. Where you want to store the analysis and artefact results.
.PARAMETER time_start
    Optional. The start time from when we want to look for interesting information. Normally aligned with the incident timeframe. Caution: specifying a high number of days will cause performance issues.
.PARAMETER time_end
    Optional. The end time to when we want to look for interesting information. Normally aligned with the incident timeframe. Caution: specifying a high number of days will cause performance issues.
.PARAMETER noVelociraptor
    Optional. Flag to skip the collection using Velociraptor to speed up analysis. Can cause access control issues if set.
.PARAMETER iocFile
    Optional. The path to a file containing a list of indicators of compromise. Each indicator is on a separate line.
.PARAMETER toolPath
    Optional. The path to the directory of the wiskess.ps1 script
.PARAMETER clawsOut
    Optional. Run an intense system-wide scan for IOCs using ripgrep and thor
.PARAMETER wmiParse
    Optional. Parse the WMI artefacts using WMI-CIM. Can cause performance issues.
.PARAMETER noInput
    Optional. Skip all actions needing a user input. Useful for batch processes or benchmarking.
.EXAMPLE
    Minimum arguments required to collect artefacts from E:, with a quick triage of the last 7 days and storing results to Z:\Project file path.
    .\wiskess.ps1 -dataSource E: -outFilePath "Z:\Project" -time_start 2023-01-01 -time_end 2023-02-01
.EXAMPLE
    Don't ask for any user input, just do it. Also only collect the minimum files and only look back the past 1 day. Useful for batch processes or benchmarking.
    .\wiskess.ps1 -dataSource E: -outFilePath "Z:\Project" -time_start 2023-01-01 -time_end 2023-01-02 -noInput -noVelociraptor
.EXAMPLE
    Only collect the minimum files. Useful for saving disk space and time.
    .\wiskess.ps1 -dataSource E: -outFilePath "Z:\Project" -time_start 2023-01-01 -time_end 2023-02-01 -noVelociraptor
.EXAMPLE
    Run an intense scan of the artefacts. This includes processing of WMI with python-cim, full scans of the mounted drive using ripgrep with the iocs.txt list, and thor with all flags enabled
    .\wiskess.ps1 -dataSource E: -outFilePath "Z:\Project" -time_start 2023-01-01 -time_end 2023-02-01 -clawsOut
.EXAMPLE
    Provide a list of indicators in a file path.
    .\wiskess.ps1 -dataSource E: -outFilePath "Z:\Project" -time_start 2023-01-01 -time_end 2023-02-01 -iocFile "Z:\Project\iocs.txt"
.EXAMPLE
    Run the WMI parsing functions.
    .\wiskess.ps1 -dataSource E: -outFilePath "Z:\Project" -time_start 2023-01-01 -time_end 2023-02-01 -wmiParse
.NOTES
    Author: Gavin Hull
    Date:   2023-08-29
    TODO:   Mount the drive automatically using aim_cli, i.e. aim_cli.exe --mount --readonly --filename=D:\ISOs\base-wkstn-05-cdrive.E01 --provider=LibEwf --fakesig
    TODO:   foreach ($cmd in 'pslist','psscan','psxview','pstree','cmdscan','filescan','hivelist','userassist','autoruns','netscan','ssdt','svcscan','consoles') { & $toolPath\volatility_2.6_win64_standalone\volatility_2.6_win64_standalone.exe -f $outFilePath\memory.dmp --profile=Win2012R2x64_18340 $cmd > $outFilePath\Analysis\vol-output\$cmd.txt}
    TODO:   foreach ($cmd in 'cmdline','amcache','clipboard','iehistory','mftparser','timeliner','shellbags','shimcache') { & $toolPath\volatility_2.6_win64_standalone\volatility_2.6_win64_standalone.exe -f $outFilePath\memory.dmp --profile=Win2012R2x64_18340 $cmd > $outFilePath\Analysis\vol-output\$cmd.txt}
    TODO:   options to select modules and processors like chainsaw, hayabusa
    TODO:   generate a system info report from Registry
    TODO:   add a switch to skip wiskess' velo if it was a velo or surge collection
    TODO:   add bmc_tools
#>


Param (
    [parameter(mandatory)] [string]$dataSource,
    [parameter(mandatory)] [string]$outFilePath,
    [string]$iocFile = "$PSScriptRoot\iocs.txt",
    [parameter(mandatory)][string]$time_start = "2023-01-01",
    [parameter(mandatory)][string]$time_end = "2023-02-01",
    [switch]$noVelociraptor = $False,
    [switch]$clawsOut = $False,
    [switch]$wmiParse = $False,
    [switch]$noInput = $False,
    [switch]$collection = $False,
    [string]$toolPath = $PSScriptRoot
)

#Requires -Version 7.0
#Requires -RunAsAdministrator

# Admin only mode
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))  
{  
  $arguments = "& '" +$myinvocation.mycommand.definition + "'"
  Start-Process pwsh -Verb runAs -ArgumentList $arguments
  Break
}

# Globals
$timestamp = Get-Date -UFormat "%d%B%Y-%H%M%S"
$wiskessLog = "$outFilePath\wiskess-$timestamp.log"
$logo = "
'##:::::'##:'####::'######::'##:::'##:'########::'######:::'######::
 ##:'##: ##:. ##::'##... ##: ##::'##:: ##.....::'##... ##:'##... ##:
 ##: ##: ##:: ##:: ##:::..:: ##:'##::: ##::::::: ##:::..:: ##:::..::
 ##: ##: ##:: ##::. ######:: #####:::: ######:::. ######::. ######::
 ##: ##: ##:: ##:::..... ##: ##. ##::: ##...:::::..... ##::..... ##:
 ##: ##: ##:: ##::'##::: ##: ##:. ##:: ##:::::::'##::: ##:'##::: ##:
. ###. ###::'####:. ######:: ##::. ##: ########:. ######::. ######::
:...::...:::....:::......:::..::::..::........:::......::::......:::
by Gavin Hull
version: 2023-08-29"

# Modules
Get-ChildItem $toolPath\wiskers\*.psm1 | ForEach-Object { Import-Module $_ -Force }

function Start-MainWiskess {
    $start = Get-Date
    # Make file structure
    MakeDir -outDir "$outFilePath" -wiskessLog $wiskessLog
    MakeDir -outDir "$outFilePath\Analysis" -wiskessLog $wiskessLog
    MakeDir -outDir "$outFilePath\Artefacts" -wiskessLog $wiskessLog

    OutputMessage -msg "Starting wiskess at: $start" -type "info" -wiskessLog $wiskessLog
    OutputMessage -msg $logo -wiskessLog $wiskessLog

    # Check args - run in global namespace
    if ($dataSource -notmatch "[a-z]:") {
        OutputMessage -msg "Something wrong with your drive mount or origin. Next time make sure to add the letter and colon, e.g. c:" -type "warn" -wiskessLog $wiskessLog
        $dataSource = $dataSource -replace '^([a-z])(?!:)', '$1:'
        OutputMessage -msg "Corrected to dataSource: $dataSource" -wiskessLog $wiskessLog
    }
    # remove trailing slash, if any
    if ($dataSource -match "\\$") {
        $dataSource = $dataSource -replace "\\+$",""
        OutputMessage -msg "Corrected the dataSource so it doesn't have a backslash at the end $dataSource"
    }
    # Check and set the timeframe
    $time_start = Get-ValidDate $time_start "Start time is not a valid date format: yyyy-mm-dd"
    $time_end = Get-ValidDate $time_end "End time is not a valid date format: yyyy-mm-dd"
    $timeArgs = @{
        'time_start' = $time_start
        'time_end' = $time_end
    }
    $lookbackDays = $(New-TimeSpan -Start $timeArgs.time_start -End $timeArgs.time_end).days

    OutputMessage -msg "Outputting log to $wiskessLog" -type "info" -wiskessLog $wiskessLog

    if ($collection -eq $False) {
        $artSource = getArt -artSource $dataSource -wiskessLog $wiskessLog -outFilePath $outFilePath -noVelociraptor $noVelociraptor -toolPath $toolPath
    } else {
        $artSource = $dataSource
    }
    $artHash = chkArt -artSource $artSource -wiskessLog $wiskessLog -dataSource $dataSource -noInput $noInput -noVelociraptor $noVelociraptor
    
    runFunctions -artSource "$artSource" -artHash $artHash -outFilePath $outFilePath -toolPath $toolPath -lookbackDays $lookbackDays -iocFile $iocFile -dataSource $dataSource -clawsOut $clawsOut -wmiParse $wmiParse -noInput $noInput -timeArgs $timeArgs -wiskessLog $wiskessLog
    genReport -outFilePath $outFilePath
    if (!$clawsOut) {
        OutputMessage -msg "Quick triage only! Make sure to add the flag -clawsOut for a deep dive and more results." -type "warn" -wiskessLog $wiskessLog
    }
    OutputMessage -msg "wiskess completed. Check the output log for any errors: $wiskessLog" -type "good" -wiskessLog $wiskessLog

    Clear-TmpFiles

    $stop = Get-Date
    OutputMessage -msg "Finished wiskess at: $stop. Duration: $(New-TimeSpan -Start $start -End $stop)" -type "info" -wiskessLog $wiskessLog
}

# TODO: to mount using aim_cli.exe -- Arsenal-Image-Mounter-v3.9.226\aim_cli.exe --mount=removable --readonly --filename=2020JimmyWilson.E01 --provider=DiscUtils
Start-MainWiskess
