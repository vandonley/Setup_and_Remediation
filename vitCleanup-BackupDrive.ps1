<#
.Synopsis
   Cleanup old backups on drives. Can specify drive, file age, and Shadow Copy
   storage size as a percentage.
.DESCRIPTION
   The script is to be uploaded to your dashboard account as a user script.
   It can run both as a script check and as a scheduled task. Expects to be run
   with vitCheck-RMMDefaults.ps1
   
.EXAMPLE
   vitCleanup-BackupDrive
.EXAMPLE
   vitCleanup-BackupDrive -Drive "X:" -FileDays "30" -ShadowStorage "75%"
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
    # Drive to cleanup, if not provided will search for backup drives
    [Parameter()]
    [array]
    $Drive,

    # Delete all files older than number of days, defaults to 30
    [Parameter()]
    [int]
    $Filedays = '30',

    # Resize Shadow Copy storage to this percent to delete old backups
    [Parameter()]
    [string]
    $ShadowStorage = '75%',

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
$Return = [ordered]@{}
$Return.Error_Count = 0

# List of drives never to run this script on, in case someone enters something wrong
# or copies a backup to a data or system disk.
$IgnoreDrives = @("C:","D:","E:","F:","G:","H:","I:","J:","K:","L:")

# Backup types we are checking for, this just creates the variable, not if it is checked or not
$WindowsFileBackup = @()
$WindowsImageBackup = @()

# REGION Reporting setup
try {
    # Information about the script for reporting.
    $ErrorFileName = "vitCleanup-BackupDrive.txt"
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

# REGION Make sure script can run and find everything it needs
try {
    # Make sure Carbon module is installed
    $CarbonInstallCheck = Get-Module -ListAvailable -Name Carbon
    if (!($CarbonInstallCheck)) {
        $Return.Error_Count++
        $Return.Carbon_Test = "Unable to find Carbon module"
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
        $Return.Carbon_Test = 'Carbon v{0}' -f $CarbonInstallCheck.Version
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Prerequisit_Catch = $myException 
    $Return.Error_Count++ 
}
# END REGION

# REGION Find drives with backups
try {
    # Check if a drive was specified. If not, ignore $IgnoreDrives but check the rest
    # for backups
    if ($Drive) {
        $DriveString = [string]::Join(' ', $Drive)
        $Return.Drive_Selection = "Backup drive from command line, checking $DriveString"
    }
    else {
        $Return.Drive_Selection = "Backup drives not specified, checking for backups automatically"
        $Return.Ignoring_Drives = [string]::Join(' ', $IgnoreDrives)
        $FoundDrives = Get-PSDrive -PSProvider FileSystem | Select-Object @{name = 'Drive'; expression = {$_.Name + ':'}}
        $Return.Found_Drives = [string]::Join(' ', $FoundDrives.Drive)
        foreach ($item in $FoundDrives.Drive) {
            if (!($IgnoreDrives -like $item)) {
                $Drive += $item
            }
        }
        # Make sure there is something in $Drive at this point, error if not
        if (!($Drive)) {
            $Return.Drives_to_Check = "No potential backup drives found, error"
            $Return.Error_Count++
        }
        else {
            $Return.Drives_to_Check = [string]::Join(' ', $Drive) 
        }          
    }
    # Check $Drive for various types of backups
    # Check for Windows 7 file backups
    $Return.Windows_File_Backups = @()
    foreach ($item in $Drive) {
        # Path of Windows 7 file backups
        $FileBackupPath = $item + "\" + $env:COMPUTERNAME + "\MediaID.bin"
        if (Test-Path -Path $FileBackupPath) {
            $WindowsFileBackup += $item
            $Return.Windows_File_Backups += $FileBackupPath
        }
    }
    if (!($Return.Windows_File_Backups)) {
        $Return.Windows_File_Backups = "No Windows 7 file backups found"
    }
    # Check for Windows 7 image backups
    $Return.Windows_Image_Backups = @()
    foreach ($item in $Drive) {
        # Path of Windows 7 image backups
        $ImageBackupPath = $item + "\WindowsImageBackup\" + $env:COMPUTERNAME
        if (Test-Path -Path $ImageBackupPath) {
            $WindowsImageBackup += $item
            $Return.Windows_Image_Backups += $ImageBackupPath
        }
    }
    if (!($Return.Windows_Image_Backups)) {
        $Return.Windows_Image_Backups = "No Windows 7 image backups found"
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Backup_Path_Catch = $myException 
    $Return.Error_Count++ 
}
# END REGION

# REGION Clean-up backup drives
try {
    # Cleanup Windows 7 file backups
    if ($WindowsFileBackup) {
        # Go through list of file backup locations
        foreach ($item in $WindowsFileBackup) {
            # Build the path
            $myPath = $item + "\" + $env:COMPUTERNAME
            # Get date of files to delete if created before
            $myDays = "-" + $Filedays
            $DeleteDays = (Get-Date).AddDays($myDays)
            # Delete the files
            $Return.Removed_Backup_Files = Get-ChildItem -Path $myPath -Recurse | `
                Where-Object -Property 'LastWriteTime' -LT $DeleteDays | Remove-Item -Force | Out-String
        }
    }
    # Cleanup Windows image backups
    if ($WindowsImageBackup) {
        # If this is a server, use Diskshadow and Vssadmin
        $OSInfo = Get-WmiObject Win32_OperatingSystem | Select-Object Caption
        $OSInfo = $OSInfo.Caption
        [bool]$UseDiskshadow = $false
        if ($OSInfo -like "*Server*") {
            $UseDiskshadow = $true
            $Return.Platform_Check = "$OSInfo - Using both Vssadmin and Diskshadow"
        }
        else {
            $Return.Platform_Check = "$OSInfo - Using only Vssadmin"
        }
        # Go through the list of image backup locations
        foreach ($item in $WindowsImageBackup) {
            # Resize the maximum shadowstorage size to allow new backups to be created
            $myVSSReturn = "VSS_Resize_for_" + $item
            $Return.$myVSSReturn = . vssadmin.exe resize shadowstorage /on=$item /for=$item /maxsize=$ShadowStorage | Out-String
            # If this is a server, delete the oldest shadowcopy backup
            if ($UseDiskshadow) {
                $myDiskshadowReturn = "Diskshadow_Removal_for_" + $item
                # Create the script for Diskshadow.exe
                $myDiskshadowScript = "delete shadows oldest $item"
                $myScriptPath = $env:TEMP + "\CleanupDiskshadow.dsh"
                Out-File -FilePath $myScriptPath $myDiskshadowScript -Force
                # Delete the oldest server image backup
                $Return.$myDiskshadowReturn = . Diskshadow.exe /s $myScriptPath | Out-String 
                # Delete the script file
                Remove-Item -Path $myScriptPath -Force           
            }
        }
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Backup_Cleanup_Catch = $myException 
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