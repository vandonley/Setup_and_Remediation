<#
.Synopsis
   Looks for Lenovo thermal settings and sets all options with
   "Better Thermal Performance" as an option.
.DESCRIPTION
   The script is to be uploaded to your dashboard account as a user script.
   It can run both as a script check and as a scheduled task.   
.EXAMPLE
   pccLenovo_Thermal_Settings.ps1
.OUTPUTS
   Generate output for the dashboard and modifies BIOS options.
.EMAIL
   vand@parseccomputer.com
.VERSION
   1.0
#>
param (
    # Accept -logfile for MaxRM script runner 
    [Parameter(Mandatory=$false)]
    [string]
    $logfile
)

# Set error and warning preferences
$ErrorActionPreference = "Continue"
$WarningPreference = "Continue"

# Force output to keep MaxRM from timing out
Write-Host " "

# Create hashtable for output
[hashtable]$Return = @{}

# Start an error counter so MaxRM will correctly error on failure
[int]$ErrorCount = '0'

# Hashtable and array to get settings
$WmiThermalObjects = @{}
$WmiThermalSettings = @()

# Get all the BIOS settings that include "Better Thermal Performance" as an option
$WmiThermalObjects = Get-WmiObject -class Lenovo_BiosSetting -namespace root\wmi | `
    Where-Object {$_.CurrentSetting -like "*Better Thermal Performance*"}
if ($WmiThermalObjects.Count -eq '0') {
    Write-Host "No Lenovo BIOS settings found - exiting"
    Exit 0
}

# Create a list of just the setting name
foreach ($item in $WmiThermalObjects) {
    $WmiThermalSettings += ($item.CurrentSetting).split(",")[0]
}

$Return.Settings_List = $WmiThermalSettings | Format-List | Out-String

# Set each option to "Better Thermal Performance"
try {
    foreach ($item in $WmiThermalSettings) {
        (Get-WmiObject -class Lenovo_SetBiosSetting -namespace root\wmi).SetBiosSetting("$item,Better Thermal Performance")
        (Get-WmiObject -class Lenovo_SaveBiosSettings -namespace root\wmi).SaveBiosSettings("")
    }    
}
catch {
    $CatchItem = "Settings_Catch_" + $item
    $Return.$CatchItem = $_.Exception | Format-List | Out-String
    $ErrorCount = $ErrorCount + '1'
}

$Return.BIOS_Settings = Get-WmiObject -class Lenovo_BiosSetting -namespace root\wmi | `
    Where-Object {$_.CurrentSetting.split(",",[StringSplitOptions]::RemoveEmptyEntries) -like "*Better Thermal Performance*"} | `
    Format-List CurrentSetting | Out-String


# Return output and create alert if needed
$Return.Error_Count = $ErrorCount
if ($ErrorCount -eq 0) {
Write-Output @"
 
Script Success
-
Troubleshooting info below
_______________________________
 
"@
$Return | Format-List
Exit 0
}
else {
    $Error.Clear() | Out-Null
        [string]$ErrorString = "Check Failure"
        [string]$ErrMessage = ( $Return | Format-List | Out-String )
        $Error.Add($ErrorString)
        Write-Error -Exception $ErrorString -ErrorId 1001 -Message $ErrMessage
        Exit 1001
}