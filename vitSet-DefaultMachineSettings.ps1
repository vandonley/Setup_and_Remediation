<#
.Synopsis
   Sets workstations and server settings to desired default settings.
   - Set number of threads to use for Managed Online Backup
   - Set boot and recovery options
.DESCRIPTION
   The script is to be uploaded to your dashboard account as a user script.
   It can run both as a script check and as a scheduled task. Expects to be run
   with vitCheck-RMMDefaults.ps1
.EXAMPLE
   .\vitSet-DefaultWorkstationSettings
.EXAMPLE
    .\vitSet-DefaultWorkstationSettings -BackupThreads 10
.OUTPUTS
   Registry settings, INI files, and error file.
.NOTES
   Designed to be used with Solar Winds RMM
.EMAIL
   vdonley@visionms.net
.VERSION
   1.0
#>


# Must accept -logfile to make Script Runner happy.
param (	
    # Number of backup threads for Managed Online Backup
    [Parameter(Mandatory=$false)]
    [int]$BackupThreads = 10,

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
    $ErrorFileName = "vitDefaultMachineSettings.txt"
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
    $Return.Prerequisite_Catch = $myException 
    $Return.Error_Count++ 
}
# END REGION

# REGION Set Lenovo thermal options to prevent overheating
try { 
    # Hashtable and array to get settings
    $WmiThermalObjects = @{}
    $WmiThermalSettings = @()
    # Get all the BIOS settings that include "Better Thermal Performance" as an option
    if ((Get-WmiObject -Class Lenovo_BiosSetting -List -Namespace 'root\wmi') -ne $null) {
        $WmiThermalObjects = Get-WmiObject -class Lenovo_BiosSetting -Namespace 'root\wmi' | `
            Where-Object {$_.CurrentSetting -like "*Better Thermal Performance*"}
    }
    else {
        $WmiThermalObjects = @()
    }
    # Stop if there are no Lenovo power options, update if they exist
    if ($WmiThermalObjects.Count -eq '0') {
        $Return.Lenovo_BIOS_Present = "No Lenovo BIOS settings found"
        }
    else {
        $Return.Lenovo_BIOS_Present = "Lenovo BIOS found - updating"
        # Create a list of just the setting name
        foreach ($item in $WmiThermalObjects) {
            $WmiThermalSettings += ($item.CurrentSetting).split(",")[0]
        }
        $Return.Settings_List = $WmiThermalSettings | Format-List | Out-String
        # Set each option to "Better Thermal Performance"
        foreach ($item in $WmiThermalSettings) {
                (Get-WmiObject -class Lenovo_SetBiosSetting -namespace root\wmi).SetBiosSetting("$item,Better Thermal Performance") | Out-Null
                (Get-WmiObject -class Lenovo_SaveBiosSettings -namespace root\wmi).SaveBiosSettings("") | Out-Null
        }
        $Return.Lenovo_Thermal_Settings = Get-WmiObject -class Lenovo_BiosSetting -namespace root\wmi | `
            Where-Object {$_.CurrentSetting.split(",",[StringSplitOptions]::RemoveEmptyEntries) -like "*Better Thermal Performance*"} | `
            Format-List CurrentSetting | Out-String    
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Lenovo_Thermal_Settings_Catch = $myException 
    $Return.Error_Count++ 
}
#END REGION

# REGION Set the number of threads to use if Managed Online Backup is being used
try {
    # Get the Managed Online Backup service information
    $MobService = Get-ServiceConfiguration -Name "Backup Service Controller"
    if ($MobService) {
        $Return.Managed_Online_Backup = 'Service found - Checking settings'
        # Get the path to the settings file
        $MobPath = Split-Path $MobService.Path.Replace('"',"") -Parent
        $MobIni = $MobPath + "\config.ini"
        # If the INI file exists, check if the entry already exists
        if (Test-Path -Path $MobIni) {
            $Return.MOB_Settings_File = $MobIni
            # Check the INI file for the setting
            $MobIniCheck = Split-Ini -Path $MobIni
            $MobSettingCheck = ($MobIniCheck | Where-Object { ($_.Section -eq 'General') -and ($_.Name -eq 'SynchronizationThreadCount') }).Value
            if (!($MobSettingCheck -eq $BackupThreads)) {
                $Return.Backup_Threads = "Changing threads to $BackupThreads"
                $Return.Error_Count++
                # Stop the service
                Stop-Service -Name 'Backup Service Controller' | Out-Null
                # Change the setting
                Set-IniEntry -Path $MobIni -Section 'General' -Name 'SynchronizationThreadCount' -Value $BackupThreads
                # Start the service
                Start-Service -Name 'Backup Service Controller'
            }
            else {
                # Backup threads are correct, no change needed
                $Return.Backup_Threads = "Backup threads:  $BackupThreads"
            }
        }
        else {
            # The service exists but the INI file cannot be found
            $Return.Error_Count++
            $Return.MOB_Settings_File = "Error - MOB INI file could not be found at $MobIni"
        }
    }
    else {
        # Service not found, no need to check the settings
        $Return.Managed_Online_Backup = 'Service not found - Skipping settings check'
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Managed_Online_Backukp_Settings_Catch = $myException 
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