<#
.Synopsis
   Change backup drive letter to Z: for MOB
.DESCRIPTION
   The script is to be uploaded to your dashboard account as a user script.
   It can run both as a script check and as a scheduled task. Expects to be run
   with vitCheck-RMMDefaults.ps1
.EXAMPLE
   vitChange-BackupDrive
.EXAMPLE
   vitChange-BackupDrive -Drive 'X' -NewDrive 'Z'
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
    [string]
    $Drive = 'X',

    # Resize Shadow Copy storage to this percent to delete old backups
    [Parameter()]
    [string]
    $NewDrive = 'Z',

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
    $ErrorFileName = "vitChange-BackupDrive.txt"
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

# REGION Change the drive letter
try {
    # Format the drive letters for WMI
    $Drive = $Drive + ":"
    $NewDrive = $NewDrive + ":"
    # Check to see if the drive exists
    $myDrive = Get-WmiObject -Class win32_volume -Filter "DriveLetter = `'$Drive`'"
    # If the drive exists, change the drive letter
    if ($myDrive) {
        $Return.Drive_Found = $myDrive
        $Return.Drive_Changed = Set-WmiInstance -input $myDrive -Arguments @{DriveLetter="$NewDrive"; Label="Backup SpeedVault"}
    }
    # If it doesn't exist, report but don't error
    else {
        $Return.Drive_Found = "Drive $Drive not found"
        }      
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Drive_Change_Catch = $myException 
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