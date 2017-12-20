<#
.Synopsis
Removes Bitdefender AV and cleans up left over files and registry keys
.DESCRIPTION
The script is to be uploaded to your dashboard account as a user script.
Intended to be used with RMM folder checks for error reporting.
.EXAMPLE
.\vitRemove-Bitdefender.ps1
.EXAMPLE
 .\vitRemove-Bitdefender.ps1
.OUTPUTS
Error file and output to dashboard
.NOTES
Designed to be used with Solar Winds RMM
.EMAIL
vdonley@visionms.net
.VERSION
1.0
#>


# Must accept -logfile to make Script Runner happy.
param (	
 # Make sure -logfile is NOT positional
 [Parameter(Mandatory=$false)]
 [string]$logfile
)

# Set error and warning preferences
$ErrorActionPreference = "Continue"
$WarningPreference = "Continue"

# Force output to keep RMM from timing out
Write-Host " "

# Create hashtable for output. Make it stay in order and start an error counter to create an alert if needed. Divide by 1 to force integer
$Return = [ordered]@{}
$Return.Error_Count = 0

# REGION Reporting setup
try {
    # Information about the script for reporting.
    $ErrorFileName = "vitRemove-Bitdefender.txt"
    # File name for ScriptRunnter
    $Return.RMM_Script_Name = $MyInvocation.MyCommand.Name
    # Check to see if the RMM Error Folder exists. Put the Error file in %TEMP% if it doesn't.
    $myErrorPath = $env:RMMErrorFolder
    if ($myErrorPath) {
        $Return.Error_File = $env:RMMErrorFolder + "\" + $ErrorFileName
    }
    else {
        $Return.Error_File = $env:TEMP + "\" + $ErrorFileName
    }
    if ($env:RMMFolder) {
        $Return.Staging_Folder = $env:RMMFolder + '\Staging'
    }
    else {
        $Return.Staging_Folder = $env:TEMP
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.File_Information_Catch = $myException 
    $Return.Error_Count++ 
}
# END REGION

# REGION Make sure script can run and find everything it needs
try {
    # Get the path to Chocolatey and Chocolatey package list then parse the list
$Choco = $env:ChocolateyInstall + "\bin\choco.exe"
$ChocoList = (. $Choco list -lo)
$ChocoApps = @()
foreach ($item in $ChocoList) {
    $myitem = $item.Split(' ')
    $ChocoApps += $myitem[0]
}
if (!($ChocoApps)) {
    $Return.Error_Count++
    $Return.Chocolatey_Test = "Unable to find Chocolatey or create list of installed packages"
}
# Make sure 7zip is installed
if (!($ChocoApps -like "7zip.install")) {
    $Return.Error_Count++
    $Return.'7zip_Test' = "Unable to find 7zip Chocolatey package"
}
if ($Return.Error_Count -ge '1') {
    Write-Output @"
    
Script Failure!
Troubleshooting info below
_______________________________

"@
    $Return | Format-List | Out-String
    Add-Content -Path $Return.Error_File -Value "`n----------------------`n "
    Add-Content -Path $Return.Error_File -Value (get-date) -passthru
    Add-Content -Path $Return.Error_File -Value "`n "
    Add-Content -Path $Return.Error_File -Value ( $Return | Format-List | Out-String )
    Exit 1001
}
else {
    # Return success
    $Return.Chocolatey_Test = (. $Choco)[0]
    $Return.'7zip_Test' = (. $Choco list -lo -r 7zip.install) | Out-String
}
}
catch {
$myException = $_.Exception | Format-List | Out-String
$Return.Prerequisite_Catch = $myException 
$Return.Error_Count++ 
}
# END REGION

#REGION Remove Bitdefender
try {
    # Start a Webclient
    $WebClient = (New-Object System.Net.WebClient)
    # URL to uninstall tool
    $BDLink = 'https://download.bitdefender.com/business/BEST/Tools/Uninstall_Tool.exe'
    # Staging folder
    $StagingFile = $Return.Staging_Folder + '\Uninstall_Tool.exe'
    # Working folder to extract too
    $WorkingFolder = $Return.Staging_Folder + '\BDUninstall'
    # Uninstall tool file to run after extraction
    $WorkingFile = $WorkingFolder + '\UninstallTool.exe'
    # Download Bitdefender to the staging folder
    $WebClient.DownloadFile($BDLink,$StagingFile)
    # Extract and run the tool if it downloaded successfully
    if (Test-Path -Path $StagingFile) {
        $Return.Download_Result = 'Uninstall tool downloaded successfully'
        $Return.Decompress_Result = (. 7z.exe x $StagingFile -o"$WorkingFolder" -y) | Out-String
        $Return.Bitdefender_Removal = (. $WorkingFile /silent /force:Endpoint Security by Bitdefender) | Out-String
    }
    else {
        $Return.Error_Count++
        $Return.Download_Result = 'Failed to download uninstall tool'
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Bitdefender_Removal_Catch = $myException 
    $Return.Error_Count++     
}
#END REGION

# REGION Output results and create an alert if needed
if ($Return.Error_Count -eq 0) {
    Write-Output @"
    
Script Success!
Troubleshooting info below
_______________________________
   
"@
    $Return | Format-List | Out-String
    if (Test-Path $Return.Error_File) {
        Remove-Item $Return.Error_File
    }
    Exit 0
    }
else {
    Write-Output @"
    
Script Failure!
Troubleshooting info below
_______________________________

"@
    $Return | Format-List | Out-String
    Add-Content -Path $Return.Error_File -Value "`n----------------------`n "
	Add-Content -Path $Return.Error_File -Value (get-date) -passthru
	Add-Content -Path $Return.Error_File -Value "`n "
	Add-Content -Path $Return.Error_File -Value ( $Return | Format-List | Out-String )
    Exit 1001
}
# END REGION