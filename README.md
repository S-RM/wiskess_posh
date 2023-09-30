# wiskess_posh
WISKESS automates the Windows evidence processing for Incident Response investigations. Powershell version.

This is the PowerShell version of WISKESS, which uses parallel processing of multiple tools including Hayabusa, Chainsaw, EZ-Tools, Loki, SCCM Recently Used, WMI Persistence, python-cim, Browsing History, Hindsight, ripgrep, velociraptor, and more can be added. 

It includes enrichment tools that scan the data source using your IOC list, yara rules, and open source intelligence. 

The results are structured into folders in CSV files that can be opened with text editors and searched across using tools like grep. The tool produces a report of the system info and files that have produced results in the Analysis folder.

The output is generated into reports of a timeline that is compatible with ingesting into visualisation tools including, timesketch, elastic and splunk.

# Whipped by WISKESS
This script will pull data from an AWS or Azure store, process it with wiskess and upload the output to a store.

## Usage
This can be used to process Windows data sources stored on either an Azure or AWS S3 cloud account. It can also be used to process data from a network share or local drive.

### Azure Usage:
* Generate a SAS key from the storage where the data is stored in azure
* Generate a SAS key to where you need the Wiskess output to be uploaded to in azure
* Copy the file path of all the data you need processed, this needs to be the same as the path in Azure
* Set a start and end time, which is likely the incident timeframe

### AWS Usage:
* Add to your session or terminal the AWS credentials for the account where the data is stored in S3
* Get the s3:// link to where the data source is stored
* Create a bucket or folder in AWS S3, where you need the Wiskess output to be uploaded to in azure. Get that s3:// link too.        
* Copy the file path of all the data you need processed, this needs to be from the folder or bucket that you got the s3:// link.     
* Set a start and end time, which is likely the incident timeframe

# WISKESS Core
This is the PowerShell version of WISKESS, which uses parallel processing of multiple processors, enriches the data and creates reports.

## Requirements
run `setup.ps1` using PowerShell as Administrator

# Usage
* Mount the image to a drive, i.e. using Arsenal Image Mounter. Can be skipped if using a folder of artefacts.
* Provide the file path to the artefacts. Such as the drive it has been mounted, being the drive letter it was originally located on. Or the file path to the folder it was extracted/downloaded to.
* Provide the output path, where you want to store collected artefacts and the results.
* Add your indicators to a file, you can call it iocs.txt and place it in the same folder as wiskess.ps1, or specify the location of your file with the flag -iocFile "path_to_your_iocs.txt"
* The script has a set of predefined locations of Windows artefacts, which it uses to pass to the right parser. If the artefact is not found at the default location, it will ask the user to enter the path to it.

## Parameters
    -dataSource <String>
        Required. The drive letter the image is mounted on.

    -outFilePath <String>
        Required. Where you want to store the analysis and artefact results.

    -iocFile <String>
        Optional. The path to a file containing a list of indicators of compromise. Each indicator is on a separate line.

    -time_start <String>
        Optional. The start time from when we want to look for interesting information. Normally aligned with the incident timeframe.    
        Caution: specifying a high number of days will cause performance issues.

    -time_end <String>
        Optional. The end time to when we want to look for interesting information. Normally aligned with the incident timeframe.        
        Caution: specifying a high number of days will cause performance issues.

    -noVelociraptor [<SwitchParameter>]
        Optional. Flag to skip the collection using Velociraptor to speed up analysis. Can cause access control issues if set.

    -clawsOut [<SwitchParameter>]
        Optional. Run an intense system-wide scan for IOCs using ripgrep and thor

    -wmiParse [<SwitchParameter>]
        Optional. Parse the WMI artefacts using WMI-CIM. Can cause performance issues.

    -noInput [<SwitchParameter>]
        Optional. Skip all actions needing a user input. Useful for batch processes or benchmarking.

    -collection [<SwitchParameter>]

    -toolPath <String>
        Optional. The path to the directory of the wiskess.ps1 script

# Syntax
```
wiskess.ps1 [-dataSource] <String> [-outFilePath] <String> [[-iocFile] <String>] [-time_start] <String>  
    [-time_end] <String> [-noVelociraptor] [-clawsOut] [-wmiParse] [-noInput] [-collection] [[-toolPath] <String>]
```
