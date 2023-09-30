
function iocFun($artHash, $outDir, $toolPath, $iocFile, $outFilePath, $dataSource, $clawsOut, $noInput, $wiskessLog) {
    $artProps = @{
        "iocs_in_analysis" = @{
            "outFile" = "IOCs_in_Analysis_results.txt"
            "outDir" = "$outDir"
            "funCall" = "rg.exe"
            "funArgs" = '--hidden --trim -zUiFf "{2}" "{1}\Analysis"' -f $toolPath, $outFilePath, $iocFile
            "stdoutSave" = $True
        }
        "polars_enrich" = @{
            "outFile" = "enriched_indicators.xlsx"
            "outDir" = "$outDir"
            "funCall" = "py"
            "funArgs" = '{0}\tools\polars_enrich.py {1} {0}\tools' -f $toolPath, $outFilePath
        }
    }
    # ripgrep search pagefile
    $outFile = "IOCs_in_pagefile.txt"
    If ($(Test-Path "$outDir\$outFile") -eq $False) { 
        OutputMessage -msg "Search for indicators in files. Please specify a file to search and a file containing indicators." -type "info" -wiskessLog $wiskessLog
        OutputMessage -msg "Default indicator list is: $iocFile" -wiskessLog $wiskessLog
        OutputMessage -msg "This contains the following indicators:" -wiskessLog $wiskessLog
        Get-Content "$iocFile"

        # file to search
        $searchFile = "{0}" -f $artHash.pagefile
        While ($(Test-Path  -PathType Leaf -Path "$searchFile") -eq $False -and $searchFile -ne "none" -and $noInput -eq $False) {
            OutputMessage -msg "pagefile not found at default location: $searchFile. Please specify the pagefile.sys location. " -type "err" -wiskessLog $wiskessLog
            OutputMessage -msg "Hint: if there are multiple drives it might be on one of them. Check the SWAP drive." -type "info" -wiskessLog $wiskessLog
            $searchFile = getInput -msg "Please specify the pagefile.sys location, or any other file to search [type 'none' to continue]" -noInput $noInput -wiskessLog $wiskessLog
            if ("$searchFile" -eq "" -or "$searchFile" -eq $Null) { $searchFile = "{0}" -f $artHash.pagefile }
        }
        if ("$searchFile" -ne "none") { 
            $pagefile_rg = @{
                "outFile" = "$outFile"
                "outDir" = "$outDir"
                "funCall" = "rg.exe"
                "funArgs" = '--hidden --trim -aziFf "{2}" "{1}"' -f $toolPath, $searchFile, $iocFile
                "stdoutSave" = $True
            }
        } else {
            OutputMessage -msg "User chose none as the pagefile. Skipping..." -type "info" -wiskessLog $wiskessLog
        }
    }

    # Do the operations, adding the pagefile one if available
    if ($pagefile_rg) {
        $artProps.Add("pagefile_rg", $pagefile_rg)
        OutputMessage -msg "Searching $searchFile, this may take some time" -type "info" -wiskessLog $wiskessLog
    }
    Start-Parallel -artProps $artProps -toolPath $toolPath -wiskessLog $wiskessLog

    # Only run the intense system scans if specified by the clawsOut flag, which the user gives on the command line.
    if ($clawsOut) {
        $artProps = @{
            "rg-drive" = @{
                "outFile" = "rg-drive.txt"
                "outDir" = "$outDir"
                "funCall" = "rg.exe"
                "funArgs" = '--hidden --trim -aziFf "{2}" "{1}"' -f $toolPath, $dataSource, $iocFile
                "stdoutSave" = $True
                "timeout" = 2400
            }
            "thor-intense" = @{
                "outFile" = "*.csv"
                "outDir" = "$outDir\thor-intense"
                "funCall" = "{0}\tools\thor-lite\thor64-lite.exe" -f $toolPath
                "funArgs" = '-a Filescan --intense --norescontrol --nosoft --cross-platform --alldrives -p {0} -e {1}' -f $dataSource, "$outDir\thor-intense"
                "timeout" = 2400
            }
        }
        Start-Parallel -artProps $artProps -toolPath $toolPath -wiskessLog $wiskessLog
    } else {
        $artProps = @{
            "rg-drive" = @{
                "outFile" = "rg-drive-quick.txt"
                "outDir" = "$outDir"
                "funCall" = "rg.exe"
                "funArgs" = '--hidden --trim -aziFf "{2}" "{1}"' -f $toolPath, $artHash.base, $iocFile
                "stdoutSave" = $True
                "timeout" = 2400
            }
            "thor-quick" = @{
                "outFile" = "*.csv"
                "outDir" = "$outDir\thor-quick"
                "funCall" = "{0}\tools\thor-lite\thor64-lite.exe" -f $toolPath
                "funArgs" = '-a Filescan --intense --norescontrol --nosoft --cross-platform --alldrives -p {0} -e {1}' -f $artHash.base, "$outDir\thor-quick"
                "timeout" = 2400
            }
        }
        Start-Parallel -artProps $artProps -toolPath $toolPath -wiskessLog $wiskessLog
    }

    # Put all IOC findings into a filterable HTML
    
    $outFile_rg = "IOCs_summary.json"
    $funCall = "rg.exe"
	$funArgs = '-aiwFf "{1}" "{0}" --json' -f $outDir, $iocFile
    FunCaller -funCall $funCall -funArgs $funArgs -outDir $outDir -outFile $outFile_rg -wiskessLog $wiskessLog -stdoutSave $True
    $outFile = "$outDir\$($outFile_rg -Replace 'json$','html')"
    if ($(Test-Path -PathType Leaf -Path $outFile) -eq $False) {
        Get-Content "$outDir\$outFile_rg" | `
            ConvertFrom-Json | `
            Select-Object -ExpandProperty data | `
            Select-Object @{n='IOC match';e={$_.submatches.match.text}}, @{n='lines';e={$_.lines.text}}, @{n='bytes';e={$_.lines.bytes}}, @{n='path';e={$_.path.text}} | `
            Out-HtmlView -Title "Wiskess IOC Findings Summary" -Filtering -FilteringLocation Top -PagingLength 100 -ScrollCollapse -FilePath $outFile
    } else {
        OutputMessage -msg "Output file exist, not overwritting. If you want to run this module again, delete this file: $outFile"
    }

    # rg -wi -Ff C:\Users\G.Hull\Downloads\code\wiskess\iocs.txt "X:\Techappvm18\Techappvm18-Snapshot2_floss.txt" --json | jq '.data |{path: .path.text, submatches: .submatches[].match.text,bytes: .lines.bytes,lines: .lines.text}' | C:\Users\G.Hull\Downloads\code\json2csv.exe -o "X:\Techappvm18\Techappvm18-Snapshot2_floss_ioc-findings.txt"
}
Export-ModuleMember -Function iocFun