# wiskess_posh
WISKESS automates the Windows evidence processing for Incident Response investigations. Powershell version.

# Description
This is the PowerShell version of WISKESS, which uses parallel processing of multiple tools 
including Hayabusa, Chainsaw, EZ-Tools, Loki, SCCM Recently Used, WMI Persistence, python-cim,
Browsing History, Hindsight, ripgrep, velociraptor, and more can be added. It includes enrichment
tools that scan the data source using your IOC list, yara rules, and open source intelligence. The
output is generated into reports of a timeline that is compatible with ingesting into visualisation 
tools including, timesketch, elastic and splunk. The results are structured into folders in CSV files
that can be opened with text editors and searched across using tools like grep. The tool produces a 
report of the system info and files that have produced results in the Analysis folder.

## Requirements: 
run setup.ps1 using PowerShell as Administrator

# Usage:
* Mount the image to a drive, i.e. using Arsenal Image Mounter. Can be skipped if using a folder of artefacts.
* Provide the file path to the artefacts. Such as the drive it has been mounted, being the drive letter it was originally located on. 
    Or the file path to the folder it was extracted/downloaded to.
* Provide the output path, where you want to store collected artefacts and the results.
* Add your indicators to a file, you can call it iocs.txt and place it in the same folder as wiskess.ps1, or 
    specify the location of your file with the flag -iocFile "path_to_your_iocs.txt"
* The script has a set of predefined locations of Windows artefacts, which it uses to pass to the right parser.
    If the artefact is not found at the default location, it will ask the user to enter the path to it.
