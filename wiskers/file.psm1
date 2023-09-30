function fileFun($artHash, $outDir, $toolPath, $wiskessLog) {
    # MFTECmd for $MFT and $J; RBCmd; LECmd
    $artProps = @{
        "mft" = @{
            "outFile" = "mft.csv"
            "outDir" = $outDir
            "funCall" = "{0}\Get-ZimmermanTools\MFTECmd.exe" -f $toolPath
            "funArgs" = '-f "{0}" --csv "{1}" --csvf "{2}" --vss --dedupe' -f $artHash.mft, $outDir, "mft.csv"
        }
        "usn" = @{
            "outFile" = "usnjrnl-j-file.csv"
            "outDir" = $outDir
            "funCall" = "{0}\Get-ZimmermanTools\MFTECmd.exe" -f $toolPath
            "funArgs" = '-f "{0}" --csv "{1}" --csvf "{2}" --vss --dedupe' -f $artHash.j_file, $outDir, "usnjrnl-j-file.csv"
        }
        "rbcmd" = @{
            "outFile" = "*RBCmd_Output.csv"
            "outDir" = $outDir
            "funCall" = "{0}\Get-ZimmermanTools\RBCmd.exe" -f $toolPath
            "funArgs" = '-d "{0}" --csv "{1}" -q' -f $artHash.recycle_bin, $outDir
        }
        "lnk" = @{
            "outFile" = "lnk-files.csv"
            "outDir" = $outDir
            "funCall" = "{0}\Get-ZimmermanTools\LECmd.exe" -f $toolPath
            "funArgs" = '-d "{1}" --csv "{2}" --csvf "{3}" -q' -f $toolPath, $artHash.user_dir, $outDir, "lnk-files.csv"
        }
    }
    Start-Parallel -artProps $artProps -toolPath $toolPath -wiskessLog $wiskessLog

    # TODO: page-brute

    # TODO: INDX_Finder.py then INDX_Parser.py
}
Export-ModuleMember -Function fileFun