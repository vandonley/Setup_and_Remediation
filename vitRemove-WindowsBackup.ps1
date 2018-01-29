<#
.Synopsis
   Remove Windows 7 Backup folders and tasks
.DESCRIPTION
   The script is to be uploaded to your dashboard account as a user script.
   It can run both as a script check and as a scheduled task. Expects to be run
   with vitCheck-RMMDefaults.ps1
.EXAMPLE
   vitRemove-WindowsBackup
.EXAMPLE
   vitRemove-WindowsBackup -Drive 'Z'
.OUTPUTS
   Error file if needed and removes files
.EMAIL
   vdonley@visionms.net
.VERSION
   1.0
#>
<#
 Others optional but must accept -logfile from MaxRM.
#>  
param (	
    # Drive to cleanup, defaults to 'Z'
    [Parameter()]
    [string]
    $Drive = 'Z',

	# Make sure -logfile is NOT positional
	[Parameter(Mandatory=$false)]
	[string]$logfile
)

# Set error and warning preferences
$ErrorActionPreference = "Continue"
$WarningPreference = "Continue"

# Force output to keep RMM from timing out
Write-Host ' '

# Create hashtable for output. Make it stay in order and start
# an error counter to create an alert if needed.
$Return = @{}
$Return.Error_Count = 0

# REGION Reporting setup
try {
    # Information about the script for reporting.
    $ErrorFileName = "vitRemove-WindowsBackup.txt"
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
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.File_Information_Catch = $myException 
    $Return.Error_Count++ 
}
# END REGION

# REGION Remove backup folders
try {
    # Folders to look for
    $FileBackups = $Drive + ':\' + $Env:COMPUTERNAME
    $ImageBackups = $Drive + ':\WindowsImageBackup'
    # Check to see if the files folder exist, then delete
    if (Test-Path -Path $FileBackups) {
        Remove-Item -Path $FileBackups -Recurse -Force
        # If the folder no longer exists, report success
        if (!(Test-Path -Path $FileBackups)) {
            $Return.Backup_Files = "Successfully removed $FileBackups"
        }
        # If the files folder still exists, error
        else {
            $Return.Backup_Files = "Failed to remove $FileBackups"
            $Return.Error_Count++
        }
    }
    # If the files folder does not exist, report but don't error
    else {
        $Return.Backup_Files = "No backup files found at $FileBackups"
    }
    # Check to see if the image folder exist, then delete
    if (Test-Path -Path $ImageBackups) {
        Remove-Item -Path $ImageBackups -Recurse -Force
        # If the image folder no longer exists, report success
        if (!(Test-Path -Path $ImageBackups)) {
            $Return.Backup_Images = "Successfully removed $ImageBackups"
        }
        else {
            $Return.Backup_Images = "Failed to remove $ImageBackups"
            $Return.Error_Count++
        }
    }
    # If the image folder does not exist, report but don't error
    else {
        $Return.Backup_Images = "No backup files found at $ImageBackups"
    }       
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Backups_Removed_Catch = $myException 
    $Return.Error_Count++ 
}
# END REGION

# REGION Resize VSS to free disk space
try {
    # Format drive letter for VSS command
    $myDrive = $Drive + ':'
    # Resize ShadowStorage to 400mb to delete ShadowCopies
    $Return.VSS_Resize = . vssadmin.exe resize shadowstorage /on=$myDrive /for=$myDrive /maxsize=400mb
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.VSS_Resized_Catch = $myException 
    $Return.Error_Count++ 
}
# END REGION

# REGION Remove backup scheduled tasks
try {
    # Try to delete the scheduled tasks and capture the output, no errors unless it causes a catch
    # Capture output as a string with stderr redirected to stdout then add to $Return so it looks prettier
    [string]$BackupTask = . schtasks /Delete /TN "Microsoft\Windows\WindowsBackup\AutomaticBackup" /f 2>&1
    [string]$MonitorTask = . schtasks /Delete /TN "Microsoft\Windows\WindowsBackup\Windows Backup Monitor" /f 2>&1
    $Return.Backup_Task = $BackupTask
    $Return.Monitor_Task = $MonitorTask
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Task_Removal_Catch = $myException 
    $Return.Error_Count++ 
}
# END REGION

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