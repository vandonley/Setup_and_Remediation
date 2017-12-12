<#
.Synopsis
   Sets workstations and server settings to desired default settings. RDP is enabled for clients using
   Network Location Authentication by default. This can be changed with -RdpPreference
   on the command line or as the first argument. Set to "All" to allow all RDP clients
   and "Off" to disable RDP.
.DESCRIPTION
   The script is to be uploaded to your dashboard account as a user script.
   It can run both as a script check and as a scheduled task. Expects to be run
   with vitCheck-RMMDefaults.ps1
.EXAMPLE
   vitSet-DefaultWorkstationSettings All
.EXAMPLE
   vitSet-DefaultWorkstationSettings -RdpPreference Off
.EXAMPLE
   vitSet-DefaultWorkstationSettings
.OUTPUTS
   Registry settings and error file.
.EMAIL
   vdonley@visionms.net
#>


# We are only binding -logfile for MaxRM script runner.
# -RdpPreference is for networks that require RDP to be disabled or need to allow less secure access.
param (	
    # Make sure -logfile is NOT positional
	[Parameter(Position=1,Mandatory=$false)]
	[string]$RdpPreference='NLA',   

    # Make sure -logfile is NOT positional
	[Parameter(Mandatory=$false)]
	[string]$logfile
)

# Set error and warning preferences
$ErrorActionPreference = "Continue"
$WarningPreference = "Continue"

# Force output to keep MaxRM from timing out
Write-Host " "

# Create ordered dictionary for output. Start an error counter to create an alert if needed.
$Return = [ordered]@{}
$Return.Error_Count = 0

# REGION Reporting setup
try {
    # Information about the script for reporting.
    $ErrorFileName = "vitSet-DefaultMachineSettings.ps1.txt"
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
        $Return.Chocolatey_Test = (. $Choco)[0]
        $Return.Carbon_Test = 'Carbon v{0}' -f $CarbonInstallCheck.Version
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Prerequisit_Catch = $myException 
    $Return.Error_Count++ 
}
# END REGION

# Disable Remote Assistance
try {
    Set-RegistryKeyValue -Path 'hklm:\SYSTEM\CurrentControlSet\Control\Remote Assistance' -Name 'fAllowToGetHelp' -DWord '0'
    if ((Get-RegistryKeyValue -Path 'hklm:\SYSTEM\CurrentControlSet\Control\Remote Assistance' -Name 'fAllowToGetHelp') -eq '0') {
         $Return.Remote_Assistance = 'Success:  Disabled'
     }
    else {
        $Return.Remote_Assistance = 'Error:  Enabled'
        $ErrorCount = $ErrorCount + 1
    }
}
catch {
    $Return.Remote_Assistance_Catch = $_.Exception | Format-List | Out-String
    $ErrorCount = $ErrorCount + 1
}

# Region Set Remote Desktop
# Check if Windows is a Home version, checking RDP features will cause script to error out
$OSCheck = (Get-WmiObject Win32_OperatingSystem).Caption
if (($OSCheck -like '*Pro*') -or ($OSCheck -like '*Server*')) {
    try {
        # Enable RDP access, enable NLA, and enable firewall rule
        if ($RdpPreference -eq 'NLA') {
            Set-RegistryKeyValue -Path 'hklm:\SYSTEM\CurentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -DWord '0'
            (Get-WmiObject -class "Win32_TSGeneralSetting" -Namespace root\cimv2\terminalservices -Filter "TerminalName='RDP-tcp'").SetUserAuthenticationRequired(1) | Out-Null
                    if (Assert-FirewallConfigurable) {
                        $Return.Firewall_Enabled_Shadow = . Netsh advfirewall firewall set rule name="Remote Desktop - Shadow (TCP-In)" new enable=yes profile="domain,private"
                        $Return.Firewall_Enabled_UDP = . Netsh advfirewall firewall set rule name="Remote Desktop - User Mode (UDP-In)" new enable=yes profile="domain,private"
                        $Return.Firewall_Enabled_TCP = . Netsh advfirewall firewall set rule name="Remote Desktop - User Mode (TCP-In)" new enable=yes profile="domain,private"
                        $Return.Firewall_Rules = Get-FirewallRule -Name "Remote Desktop*" | Format-List | Out-String
                        if (!($Return.Firewall_Rules)) {
                            $Return.Firewall_Rules = "Error:  No RDP firewall rules found"
                            $ErrorCount = $ErrorCount + 1
                        }
                    }
            $TsEnabled = Get-RegistryKeyValue -Path 'hklm:\SYSTEM\CurentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections'
            $NlaEnbaled = (Get-WmiObject -class "Win32_TSGeneralSetting" -Namespace root\cimv2\terminalservices -Filter "TerminalName='RDP-tcp'").UserAuthenticationRequired
            if (($TsEnabled -eq '0') -and ($NlaEnbaled -eq '1')) {
                $Return.RDP_Settings = 'RDP enabled with Network Level Authentication'          
            }
            else {
                $Return.RDP_Settings = 'RDP settings failed to apply'
                $ErrorCount = $ErrorCount + 1
            }
        }
        # Enable RDP access, disable NLA, and enable firewall rule
        elseif ($RdpPreference -eq 'All') {
            Set-RegistryKeyValue -Path 'hklm:\SYSTEM\CurentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -DWord '0'
            (Get-WmiObject -class "Win32_TSGeneralSetting" -Namespace root\cimv2\terminalservices -Filter "TerminalName='RDP-tcp'").SetUserAuthenticationRequired(0) | Out-Null
                    if (Assert-FirewallConfigurable) {
                        $Return.Firewall_Enabled_Shadow = . Netsh advfirewall firewall set rule name="Remote Desktop - Shadow (TCP-In)" new enable=yes profile="domain,private"
                        $Return.Firewall_Enabled_UDP = . Netsh advfirewall firewall set rule name="Remote Desktop - User Mode (UDP-In)" new enable=yes profile="domain,private"
                        $Return.Firewall_Enabled_TCP = . Netsh advfirewall firewall set rule name="Remote Desktop - User Mode (TCP-In)" new enable=yes profile="domain,private"
                        $Return.Firewall_Rules = Get-FirewallRule -Name "Remote Desktop*" | Format-List | Out-String
                        if (!($Return.Firewall_Rules)) {
                            $Return.Firewall_Rules = "Error:  No RDP firewall rules found"
                            $ErrorCount = $ErrorCount + 1
                        }
                    }
            $TsEnabled = Get-RegistryKeyValue -Path 'hklm:\SYSTEM\CurentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections'
            $NlaEnbaled = (Get-WmiObject -class "Win32_TSGeneralSetting" -Namespace root\cimv2\terminalservices -Filter "TerminalName='RDP-tcp'").UserAuthenticationRequired
            if (($TsEnabled -eq '0') -and ($NlaEnbaled -eq '0')) {
                $Return.RDP_Settings = 'RDP enabled for all clients'          
            }
            else {
                $Return.RDP_Settings = 'RDP settings failed to apply'
                $ErrorCount = $ErrorCount + 1
            }
        }
            # Disable RDP access
        elseif ($RdpPreference -eq 'Off') {
            Set-RegistryKeyValue -Path 'hklm:\SYSTEM\CurentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -DWord '1'
            $TsEnabled = Get-RegistryKeyValue -Path 'hklm:\SYSTEM\CurentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections'
            if ($TsEnabled -eq '1') {
                $Return.RDP_Settings = 'RDP disabled'          
            }
            else {
                $Return.RDP_Settings = 'RDP settings failed to apply'
                $ErrorCount = $ErrorCount + 1
            }
        }
        # Error if passed a value not defined
        else {
            $Return.RDP_Settings = "$RDPPreference is not a valid setting. `nLeave blank or use All or Off"
            $ErrorCount = $ErrorCount + 1
        }
    }
    catch {
        $Return.RDP_Preference_Catch = $_.Exception | Format-List | Out-String
        $ErrorCount = $ErrorCount + 1
    }
}
# End Region

# Region set boot and recovery options
try {
    # Set boot OS list and recovery options
    $Return.BootOsTime = . bcdedit.exe /timeout 3
    if ( ! ($Return.BootOsTime -like "*successfully*")) {
        $ErrorCount = $ErrorCount +1
    }
    # Set recovery options
    $RecoveryOptions = @{AutoReboot = $True; DebugInfoType = 3; MiniDumpDirectory = '%SystemRoot%\Minidump'; WriteDebugInfo = $True; WriteToSystemLog = $True}
    $CrashBehaviour = Get-WmiObject Win32_OSRecoveryConfiguration -EnableAllPrivileges
    $Return.Crash_Behaviour = $CrashBehaviour | Set-WmiInstance -Arguments $RecoveryOptions | Format-List -Property * | Out-String  
    
    # Enable system restore for C: drive and set storage max to 10%
    Enable-ComputerRestore -Drive $env:SystemDrive
    $Return.System_Restore = . vssadmin Resize ShadowStorage /For=$env:SystemDrive /On=$env:SystemDrive /MaxSize=10%
    if (! ($Return.System_Restore -like "*Successfully*")) {
        $ErrorCount = $ErrorCount + 1
    }
}

catch {
    $Return.Recovery_Options_Catch = $_.Exception | Format-List | Out-String
    $ErrorCount = $ErrorCount + 1
}
else {
    $Return.RDP_Checks = 'Skipped RDP Settings, Home version of Windows Detected'
}
# End Region

# Region Lenovo Thermal Settings
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
    try {
        foreach ($item in $WmiThermalSettings) {
            (Get-WmiObject -class Lenovo_SetBiosSetting -namespace root\wmi).SetBiosSetting("$item,Better Thermal Performance") | Out-Null
            (Get-WmiObject -class Lenovo_SaveBiosSettings -namespace root\wmi).SaveBiosSettings("") | Out-Null
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
    }
# End Region

# Check for errors and create an error file for the dashboard if needed
$Return.Error_Count = $ErrorCount
if ($ErrorCount -eq '0') {
    Write-Host @"
Success!
Workstation settings applied successfully

Troubleshooting info below
-------------------------------------

"@
    $Return | Format-List | Out-String
	if (Test-Path $ErrorFile) {
        Remove-Item $ErrorFile
    }
    Exit 0
}
else {
    Add-Content -Path $ErrorFile -Value "`n----------------------`n "
	Add-Content -Path $ErrorFile -Value (get-date) -passthru
	Add-Content -Path $ErrorFile -Value ($Return | Format-List | Out-String)
    $Error.Clear() | Out-Null
        [string]$ErrorString = "Script Failure"
        [string]$ErrMessage = ( $Return | Format-List | Out-String )
        $Error.Add($ErrorString)
        Write-Error -Exception $ErrorString -ErrorId 1001 -Message $ErrMessage
        Exit 1001
}