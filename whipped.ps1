<#
.SYNOPSIS
   This script will pull data from an AWS or Azure store, process it with wiskess and upload the output to a store
.DESCRIPTION
   Requirements: run setup.ps1 using PowerShell as Administrator
   
   Azure Usage:
   * Generate a SAS key from the storage where the data is stored in azure
   * Generate a SAS key to where you need the Wiskess output to be uploaded to in azure
   * Copy the file path of all the data you need processed, this needs to be the same as the path in Azure
   * Set a start and end time, which is likely the incident timeframe
   
   AWS Usage:
   * Add to your session or terminal the AWS credentials for the account where the data is stored in S3
   * Get the s3:// link to where the data source is stored
   * Create a bucket or folder in AWS S3, where you need the Wiskess output to be uploaded to in azure. Get that s3:// link too.
   * Copy the file path of all the data you need processed, this needs to be from the folder or bucket that you got the s3:// link.
   * Set a start and end time, which is likely the incident timeframe

.PARAMETER dataSourceList
    Required. The paths to the file, folder of images, collections, etc. Must be separated by comma ','
.PARAMETER local_storage
    Required. The path to where the data is temporarily downloaded to and Wiskess output is stored locally
.PARAMETER storageType
    Requried. Either 'azure' or 'aws' - based on where the data source is stored.
.PARAMETER in_link
    Required. The link that the data is stored on, i.e. https://myaccount.file.core.windows.net/myclient/?sp=rl&st=...VWjgWTY8uc%3D&sr=s
.PARAMETER out_link
    Required. The link where you need the wiskess output uploaded to, i.e. https://myaccount.file.core.windows.net/results/myclient/?sp=rcwl&st=2023-04-21T20...2FZWEA%3D&sr=s
.PARAMETER time_start
    Required. The start time from when we want to look for interesting information. Normally aligned with the incident timeframe. Caution: specifying a high number of days will cause performance issues.
.PARAMETER time_end
    Required. The end time to when we want to look for interesting information. Normally aligned with the incident timeframe. Caution: specifying a high number of days will cause performance issues.
.PARAMETER iocFile
    Optional. The paths to a file containing a list of indicators of compromise. Each indicator is on a separate line.
.PARAMETER update
    Optional. Set this flag to update the Wiskess results, such as changing the timeframe or after adding new IOCs to the list.
.PARAMETER keepEvidence
    Optional. Set this flag to keep the downloaded data on your local storage. Useful if wanting to process the data after Wiskess.
    Caution: make sure you have enough disk space for all the data source list.
.EXAMPLE
    Run with a list of data sources (needs to be the path from the azure storage), where each is separated by a comma or new line:
    .\whipped.ps1 -dataSourceList "image.vmdk, folder with collection, surge.zip, velociraptor_collection.7z" `
        -local_storage x:
        -storageType azure
        -in_link "https://myaccount.file.core.windows.net/myclient/?sp=rl&st=...VWjgWTY8uc%3D&sr=s" `
        -out_link "https://myaccount.file.core.windows.net/internal-cache/myclient/?sp=rcwl&st=2023-04-21T20...2FZWEA%3D&sr=s" `
        -time_start 2023-01-01 `
        -time_end 2023-02-01
.NOTES
    Author: Gavin Hull
    Date:   2023-08-29
#>

param (
    [Parameter(Mandatory)] [string] $dataSourceList,
    [Parameter(Mandatory)] [string] $local_storage,
    [Parameter(Mandatory)] [string] $storageType,
    [Parameter(Mandatory)] [string] $in_link,
    [Parameter(Mandatory)] [string] $out_link,
    [Parameter()] [string] $ioc_file = "$PSScriptRoot\iocs.txt",
    [Parameter(Mandatory)] [string] $time_start,
    [Parameter(Mandatory)] [string] $time_end,
    [Parameter()] [switch] $update = $False,
    [Parameter()] [switch] $keepEvidence = $False,
    [Parameter()] [string] $toolPath = $PSScriptRoot
)

Import-Module -Force "$toolPath\wiskers\validate.psm1"

$time_start = Get-ValidDate $time_start "Start time is not a valid date format: yyyy-mm-dd"
$time_end = Get-ValidDate $time_end "End time is not a valid date format: yyyy-mm-dd"

function Get-FreeDrives ($start, $end) {
    $mounted_drives = (Get-PSDrive -PSProvider FileSystem).Name
    $start..$end | ? {$_ -cnotin $mounted_drives}
}

function Start-ImageProcess ($image, $wiskess_folder, $time_start, $time_end, $ioc_file, $osf_mount) {   
    $free_drives = Get-FreeDrives 'E' 'M'
    if ($image -Match "-flat\.vmdk$" -and (Test-Path $($image -replace "-flat\.vmdk$",".vmdk"))) {
        # Make sure to use the vmdk that has the image descriptor, i.e. not '-flat.vmdk'
        $image = $image -replace "-flat\.vmdk$",".vmdk"
    } elseif ($image -Match "-flat\.vmdk$") {
        $osf_mount = $True
    }
    if ($image -Match "\.(?:vhdx|ova|vdi)$") {
        # OSFMount doesn't support these image types, so either convert or use AIM
        $osf_mount = $False
    }

    Write-Host "[+] Processing image: $image"

    if (!$osf_mount) {
        # Mount it with AIM if not supported by OSF Mount 
        & "$toolPath\tools\Arsenal-Image-Mounter-v3.9.239\aim_cli.exe" --mount --readonly --filename="$image" --fakesig --background
        $dismount = 00000
    } else {
        $osf_mount = & 'C:\Program Files\OSFMount\OSFMount.com' -a -t file -m '#:' -o ro -f "$image" -v all
        if ($osf_mount -match 'Created device\s') {
            $drive_mount_start = $(($osf_mount -match 'Created device\s') -replace 'Created device\s*\d+:\s*(\w):.*','$1')
        }
        Write-Host "[ ] Mounted image to drive: $drive_mount_start"
    }

    $done = $false
    $free_drives | % { 
        $drive_mount = "$($_):"
        if (!$done) {
            if ($(Get-PSDrive -Name $($drive_mount -replace ":$","") -ErrorAction SilentlyContinue) -and $(Test-Path -PathType Container "$($drive_mount)\Windows") ) {
                & "$toolPath\wiskess.ps1" -dataSource $drive_mount -outFilePath "$local_storage\$($wiskess_folder)" -iocFile $ioc_file -time_start $time_start -time_end $time_end -noVelociraptor -noInput
                $done = $true
            } else {
                Write-Warning "Data source $drive_mount had no Windows folder!"
            }
        }
    }
    
    if (!$osf_mount) {
        & "$toolPath\tools\Arsenal-Image-Mounter-v3.9.239\aim_cli.exe" --dismount=$dismount --force
    } else {
        $drive_mount_start.Split() | ForEach-Object {
            & 'C:\Program Files\OSFMount\OSFMount.com' -D -m "$($_):"
        }
    }
}

function Start-SurgeProcess ($surge_collection, $wiskess_folder, $time_start, $time_end, $ioc_file) {
    Write-Host "[+] Processing surge collection: $surge_collection"
    Get-ChildItem "$surge_collection" | ForEach-Object {
        $dataSource = $_.FullName
        if ($(Test-Path -PathType Container "$($dataSource)\Windows") ) {
            & "$toolPath\wiskess.ps1" -dataSource $dataSource -outFilePath "$local_storage\$($wiskess_folder)" -iocFile $ioc_file -time_start $time_start -time_end $time_end -noVelociraptor -noInput -collection
        } else {
            Write-Output "Surge folder $dataSource is not the OS drive"
        }
    }    
}

function Start-VeloProcess ($velo_collection, $wiskess_folder, $time_start, $time_end, $ioc_file) {
    Write-Host "[+] Processing velociraptor collection: $velo_collection"
    New-Item -ItemType Directory "$velo_collection\files"
    Get-ChildItem "$velo_collection\*\*\*" | ForEach-Object {
        Copy-Item $_ -Destination "$velo_collection\files" -Recurse -ErrorAction SilentlyContinue
        Remove-Item -Force -Recurse $_ 
    }
    & "$toolPath\wiskess.ps1" -dataSource "$velo_collection\files" -outFilePath "$local_storage\$($wiskess_folder)" -iocFile $ioc_file -time_start $time_start -time_end $time_end -noVelociraptor -noInput -collection
}

# TODO: List the datasourcelist to get size of largest file 

# Storage type must be aws or azure, storageType is used to select the method of data transfer
if ($storageType -match "aws") {
    $storageType = "aws"
} elseif ($storageType -match "azure") {
    $storageType = "azure"
} else {
    Write-Error "Storage type must be either aws or azure"
    Start-Sleep -Seconds 2
    exit
}

function Find-Uploaded($out_URL) {
    Write-Host "[ ] Checking if already done $out_URL"
    $uploaded = $False
    if ($storageType -match "aws") {
        $size = $(aws s3 ls $out_URL --summarize --recursive) -match "Total Size" -replace ".*Total Size:\s*"
        $uploaded = [int]$size[0] -gt 50
    } elseif ($storageType -match "azure") {
        $out_dest = & "$toolPath\tools\azcopy\azcopy.exe" list "$out_URL"
        $uploaded = $out_dest.Length -gt 50
    }
    return $uploaded
}

function Get-VMDKDescriptor ($dataS, $in_link) {
    if ($storageType -match "azure") {
        # Not needed as using osfmount
        $vmdk_stub = $("$dataS" -Replace "(?:-flat\.vmdk|\.vmdk)$","")
        $vmdk_files = $(& "$toolPath\tools\azcopy\azcopy.exe" list "$in_link" | `
            Select-String "($vmdk_stub[^;]+)").Matches.Value
        $vmdk_files | ForEach-Object {
            # Download the files
            Write-Host "[+] Downloading $dataS"
            $file_in_link = '{0}{1}{2}' -f $in_link.Split("?")[0],"/$($dataS)?",$in_link.Split("?")[1]
            Write-Host "[+] running azcopy.exe copy $file_in_link $local_storage\ --recursive"
            & "$toolPath\tools\azcopy\azcopy.exe" copy "$file_in_link" $local_storage\ --recursive    
        }
    }
}

function Copy-CloudTransfer ($src, $dst) {
    Write-Host "[ ] Copying data from $src to $dst"
    if ($storageType -match "aws") {
        if ($src -match "[^\\]*\.\w{2,3}$") {
            Write-Host "[ ] Data is a file"
            aws s3 cp "$src" "$dst"
        } else {
            Write-Host "[ ] Data is a folder"
            aws s3 cp "$src" "$dst" --recursive
        }
    } elseif ($storageType -match "azure") {
        & "$toolPath\tools\azcopy\azcopy.exe" copy "$src" "$dst" --recursive
    }
}

function Sync-CloudTransfer ($src, $dst, $folder) {
    Write-Host "[ ] Syncing data from $src to $dst"
    if ($storageType -match "aws") {
        aws s3 sync "$src" "$dst/$folder"
    } elseif ($storageType -match "azure") {
        & "$toolPath\tools\azcopy\azcopy.exe" copy "$src" "$dst" --recursive --overwrite=ifSourceNewer
    }
}

function Set-UrlLinks ($dataS, $wiskess_folder) {
    if ($storageType -match "aws") {
        $out_URL = '{0}/{1}' -f $($out_link -replace "/*$",""),$wiskess_folder
        $in_URL = '{0}/{1}' -f $($in_link -replace "/*$",""),$dataS
    } elseif ($storageType -match "azure") {
        $out_URL = '{0}{1}{2}' -f $out_link.Split("?")[0],"/$($wiskess_folder)?",$out_link.Split("?")[1]
        $in_URL = '{0}{1}{2}' -f $in_link.Split("?")[0],"/$($dataS)?",$in_link.Split("?")[1]
    }
    return $out_URL, $in_URL
}

$ds_type = $dataSourceList.Split(",").Trim().GetType().Name
if ($ds_type -match "Object") {
    $split_char = ","
} else {
    $split_char = [Environment]::NewLine
}

$dataSourceList.Split($split_char).Trim() | ForEach-Object {
    if ($image_folder -Match "_files\.zip$") {
        $image_folder = $($_ -Replace "_files\.zip$","")
    } else {
        $image_folder = $($_ -Replace "\.\w+$","")
    }
    $wiskess_folder = "$($image_folder)-Wiskess"
    $out_URL, $in_URL = Set-UrlLinks $_ $wiskess_folder
    
    $uploaded = Find-Uploaded $out_URL
    if (($uploaded -eq $False -or $update -eq $True) -and $_ -ne "") {
        Write-Host "---------------- Get Data ----------------"
        if ($(Test-Path "$local_storage\$_") -eq $true) {
            Write-Warning "File $local_storage\$_ exists, remove it if wanting to download again."
        } else {
            if ($_ -match "\.vmdk$") {
                Get-VMDKDescriptor $_ $in_link
            } else {
                # Download the image
                Write-Host "[+] Downloading $_"
                Copy-CloudTransfer $in_URL "$local_storage\"
            }
            Write-Host "Downloaded files: $(Get-ChildItem -recurse -Depth 3 $local_storage\$_)"
        }

        # Get the type of downloaded file
        $image_archive = ""
        $image_disk = ""
        if ($(Test-Path -PathType Container "$local_storage\$_")) {
            # Download is a folder, look for embedded zips
            $image_archive = $(Get-ChildItem -recurse "$local_storage\$_" | Where-Object { $_.Name -match "(?:\.zip|\.7z)$" }).FullName
            $image_disk = $(Get-ChildItem -recurse -Depth 3 "$local_storage\$_" | Where-Object { $_.Length -gt 1000000000 -and $_.Name -match "\.(?:vmdk|vdi|EX01|vhd|vhdx|E01|raw)$" }).FullName
        } elseif ($_ -match "(?:\.zip|\.7z)$") {
            # Download is a zip, check for embedded zips
            $image_archive = $(Get-ChildItem "$local_storage\$_").FullName
        } 
        if ($(Test-Path -Type Container "$local_storage\$($image_folder)-extracted") -eq $true -and $(Get-ChildItem "$local_storage\$($image_folder)-extracted" | Measure-Object -Property Length -sum).sum -gt 1000000000) {
            Write-Warning "Folder $local_storage\$($image_folder)-extracted exists delete it if wanting to extract again."
        } elseif ($image_archive) {
            # Extracting the zip to folder
            7z x $image_archive -o"$local_storage\$($image_folder)-extracted" -aos
            $image_archive_embedded = $(Get-ChildItem -recurse -Depth 1 "$local_storage\$($image_folder)-extracted" | Where-Object { $_.Name -match "(?:\.zip|\.7z)$" }).FullName
            if ($image_archive_embedded) {
                # Extract the embedded archive
                7z x $image_archive_embedded -o"$local_storage\$($image_folder)-extracted" -aos
            }
        } elseif ($image_disk) {
            New-Item -ItemType Directory "$local_storage\$($image_folder)-extracted" -ErrorAction SilentlyContinue
            Move-Item "$local_storage\$_\*" "$local_storage\$($image_folder)-extracted"
        } else {
            # It is a file, so move to extracted folder
            New-Item -ItemType Directory "$local_storage\$($image_folder)-extracted" -ErrorAction SilentlyContinue
            if ($_ -match "\.vmdk$") {
                $vmdk_stub = $("$_" -Replace "(?:-flat\.vmdk|\.vmdk)$","")
                Get-ChildItem -File $local_storage\ `
                    | Where-Object { $_.Name -Match "$vmdk_stub" } `
                    | ForEach-Object {
                        Move-Item "$_" "$local_storage\$($image_folder)-extracted"
                    }
            } else {
                Move-Item "$local_storage\$_" "$local_storage\$($image_folder)-extracted"
            }
        }

        if ($update -eq $True) {
            Write-Host "---------------- Update Data ----------------"
            if ($uploaded -eq $False) {
                # Download the wiskess folder
                Copy-CloudTransfer $out_URL "$local_storage\"
            }
            if ($(Test-Path -Path "$local_storage\$($wiskess_folder)")) {
                # Remove the Artefacts folder
                Get-ChildItem -Recurse "$local_storage\$($wiskess_folder)\Artefacts" | Remove-Item -Recurse -Force
                # Remove the empty Analysis files
                Get-ChildItem -Recurse "$local_storage\$($wiskess_folder)" | Where-Object {$_.Length -eq 0} | Remove-Item
                # Remove the Timeline folder
                Get-ChildItem -Recurse "$local_storage\$($wiskess_folder)\Analysis\Timeline" | Remove-Item -Recurse -Force
                # Remove the IOC summary and Analysis Report
                Get-ChildItem -Recurse "$local_storage\$($wiskess_folder)" | Where-Object {$_.Name -Match "Analysis-Report\.txt|IOCs_summary|IOCs_in_Analysis"} | Remove-Item
            }

        }
        
        Write-Host "---------------- Process Data ----------------"
        # Get the name of the disk image based on extension and size being >1GB
        $image = (Get-ChildItem -Recurse -Depth 3 "$local_storage\$($image_folder)-extracted" | Where-Object {$_.Length -gt 1000000000 -and $_.Name -Match "vmdk|vdi|EX01|vhd|vhdx|E01|raw"}).FullName
        $surge_collection = (Get-ChildItem -Recurse -Depth 3 "$local_storage\$($image_folder)-extracted" | Where-Object {$_.Name -match "^files$"}).FullName
        $velo_collection = (Get-ChildItem -Recurse -Depth 3 "$local_storage\$($image_folder)-extracted" | Where-Object {$_.Name -match "^uploads$"}).FullName
        if ($image) {
            Start-ImageProcess -image $image -wiskess_folder $wiskess_folder -time_start $time_start -time_end $time_end -ioc_file $ioc_file -osf_mount $True
        } elseif ("$surge_collection") {
            Start-SurgeProcess -surge_collection $surge_collection -wiskess_folder $wiskess_folder -time_start $time_start -time_end $time_end -ioc_file $ioc_file
        } elseif ("$velo_collection") {
            Start-VeloProcess -velo_collection $velo_collection -wiskess_folder $wiskess_folder -time_start $time_start -time_end $time_end -ioc_file $ioc_file
        } else {
            Write-Error "Unable to identify the type of data downloaded."
            Write-Host "Extracted depth 4: $(Get-ChildItem -Recurse -Depth 4 $local_storage\$($image_folder)-extracted)"
            Write-Host "Image download $(Get-ChildItem -Recurse -Depth 4 $local_storage\$image_folder)"
        }

        Write-Host "---------------- Upload Data ----------------"
        if ($(Test-Path -PathType Container "$local_storage\$($wiskess_folder)")) {
            Sync-CloudTransfer "$local_storage\$($wiskess_folder)" "$out_link" "$wiskess_folder"
        }
        if ($keepEvidence -eq $False) {
            Write-Host "[ ] Cleaning up data source files..."
            Remove-Item -Force -Recurse $local_storage\$_
            Get-ChildItem "$local_storage\$($image_folder)-extracted" | Remove-Item -Force -Recurse
            Remove-Item -Force -Recurse "$local_storage\$($image_folder)-extracted"
        }
    } else {
        Write-Warning "The wiskess output exists on $storageType $out_URL. Remove this if wanting to rerun the pipeline. Or add the flag -update"
    }
    Write-Host "[+] Done $_"
    Write-Host "------------------------========================================================------------------------"
    Write-Host ""
}
