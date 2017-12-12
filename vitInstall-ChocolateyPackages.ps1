<#
.Synopsis
   Installs software silently on servers and workstations using Chocolatey.
.DESCRIPTION
   The script is to be uploaded to your dashboard account as a user script.
   It can run both as a script check and as a scheduled task. You list package 
   names as parameter to script. Chocolatey will update packages that are 
   already installed. Intended to be used with vit-Check-RMMDefaults for error
   tracking and reporting. Requires Carbon module.
   
   Warning: If you later omit a package name it will NOT be uninstalled!
.EXAMPLE
   vitInstall-ChocolateyPackages notepadplusplus adobereader
.EXAMPLE
   vitInstall-ChocolateyPackages dropbox googlechrome
.EXAMPLE
   vitInstall-ChocolateyPackages google-chrome-x64
.OUTPUTS
   Installed applications and text log
.NOTES
   Based on script created by Hugo Klemmstad
.LINK
   http://klemmestad.com/2015/01/15/install-and-update-software-with-maxfocus-and-chocolatey/
.LINK
   https://chocolatey.org
.LINK
   https://chocolatey.org/packages
.EMAIL
   vdonley@visionms.net
.VERSION
   1.0
#>


# We are only binding -logfile. Leave the rest unbound.
param (	
	# Make sure -logfile is NOT positional
	[Parameter(Mandatory=$false)]
	[string]$logfile,
	
	# Capture entire parameterlist, save -logfile, as Packages
	[Parameter(Position=0,ValueFromRemainingArguments=$true)]
	[array]$Packages
)

# Set error and warning preferences
$ErrorActionPreference = "Continue"
$WarningPreference = "Continue"

# Force output to keep MaxRM from timing out
Write-Host ' '

# Array of desktop shortcuts to look for
[array]$IconCleanup = @(
	'Acrobat Reader DC.lnk',
    'BCUninstaller.lnk',
    'Boxstarter Shell.lnk'
)

# Create hashtable for output. Make it stay in order and start an error counter to create an alert if needed.
$Return = [ordered]@{}
$Return.Error_Count = 0

# REGION Reporting setup
try {
    # Information about the script for reporting.
    $ErrorFileName = "vitInstall-ChocolateyPackages.txt"
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
    # Make sure Carbon module is installed
    $CarbonInstallCheck = Get-Module -ListAvailable -Name Carbon
    if (!($CarbonInstallCheck)) {
        $Return.Error_Count++
        $Return.Carbon_Test = "Unable to find Carbon module"
    }
    # Make sure we have a package list
    if (!($Packages)) {
        $Return.Error_Count++
        $Return.Packages_Test = "No packages listed, unable to run"
    }
    # Get the path to the RMM INI file and its contents if packages are listed there
    $RMMAgent = Get-ServiceConfiguration -name 'Advanced Monitoring Agent'
    $RMMPath = Split-Path $RMMAgent.Path.Replace('"',"") -Parent
    $RMMIni = $RMMPath + "\settings.ini"
    $RMMSettings = Split-Ini -Path $RMMIni
    if (!($RMMSettings)) {
        $Return.Error_Count++
        $Return.Agent_Error = "Unable to find the RMM settings.ini file"
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
    $Return.Prerequisite_Catch = $myException 
    $Return.Error_Count++ 
}
# END REGION

# REGION Environment Variables
## Modify environment to support application install from User System
#  Set Shell folders to correct values for application install
#  If Shell folders must be modified the agent must be restarted
#  The point of the changes is to make per user installations 
#  put icons and files where the user can see and reach them.
try {
    $RestartNeeded = $false
    Push-Location # Save current location
    Set-Location "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
    Foreach ($Property in (Get-Item . | Select-Object -ExpandProperty Property)) {
        $NewValue = ''
        Switch ($Property) {
            'Desktop' 			{ $NewValue = '{0}\Desktop' -f $Env:PUBLIC }
            'Personal' 			{ $NewValue = '{0}\Documents' -f $Env:PUBLIC }
            'My Music'			{ $NewValue = '{0}\Music' -f $Env:PUBLIC }
            'My Pictures'		{ $NewValue = '{0}\Pictures' -f $Env:PUBLIC }
            'My Video'			{ $NewValue = '{0}\Videos' -f $Env:PUBLIC }
            'Favorites'			{ $NewValue = '{0}\Favorites' -f $Env:PUBLIC }
            'AppData'			{ $NewValue = '{0}' -f $Env:ALLUSERSPROFILE }
            'Start Menu'		{ $NewValue = '{0}\Microsoft\Windows\Start Menu' -f $Env:ALLUSERSPROFILE }
            'Programs'			{ $NewValue = '{0}\Microsoft\Windows\Start Menu\Programs' -f $Env:ALLUSERSPROFILE }
            'Startup'			{ $NewValue = '{0}\Microsoft\Windows\Start Menu\Programs\Startup' -f $Env:ALLUSERSPROFILE }
        }
        $OldValue = (Get-ItemProperty . -Name $Property).($Property)
        If (($NewValue) -and ($NewValue -ne $OldValue )) {
            Set-ItemProperty -Path . -Name $Property -Value $NewValue -Force
            $RestartNeeded = $true
        }   
    }
    If ($RestartNeeded) {
        $Return.Error_Count++
        $Return.Environment_Check = 'Agent restart required, local system envirionment not set'
        # Update last runtime to prevent changes too often
        [int]$currenttime = $(get-date -UFormat %s) -replace ",","." # Handle decimal comma 
        Set-IniEntry -Path $RMMIni -Section 'DAILYSAFETYCHECK' -Name 'RUNTIME' -Value $currenttime
        # Clear lastcheckday to make DSC run immediately
        Set-IniEntry -Path $RMMIni -Section 'DAILYSAFETYCHECK' -Name 'LASTCHECKDAY' -Value '0'
        # Prepare restart script
        $RestartScript = $env:Temp + "\RestartRMMAgent.cmd"
        $RestartScriptContent = @"
net stop "Advanced Monitoring Agent"
net start "Advanced Monitoring Agent"
Del /F $RestartScript
"@
        $RestartScriptContent | Out-File -Encoding OEM $RestartScript
        # Start time in the future
        $JobTime = (Get-Date).AddMinutes(-2)
        $StartTime = Get-Date $JobTime -Format HH:mm
        $TaskName = "Restart Advanced Monitoring Agent"
        $Result = &schtasks.exe /Create /TN "$TaskName" /TR "$RestartScript" /RU SYSTEM /SC ONCE /ST $StartTime /F
        If ($Result) {
            $Return.Agent_Restart_Easy = &schtasks.exe /run /TN "$TaskName" | Out-String
        } 
        If (!($Return.Agent_Restart_Easy -like 'SUCCESS:*')) {
            $Return.Agent_Restart_Hard = Restart-Service 'Advanced Monitoring Agent' -Verbose | Out-String
        }
        Write-Host = @"

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
        $Return.Environment_Check = 'Local system envirionment already set'
    }
    Pop-Location # Return to scripts directory
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Environment_Catch = $myException 
    $Return.Error_Count++ 
}
# END REGION

# REGION Install new packages
try {
    # Add any new packages to the Settings.INI file
    foreach ($Package in $Packages) {
        # Check if the package is listed in the INI file
        $PackageCheck = ($RMMSettings | Where-Object { ($_.Section -EQ 'CHOCOLATEY') -and ($_.Name -EQ $Package) }).Name
        if (!($PackageCheck)) {
            Set-IniEntry -Path $RMMIni -Section 'CHOCOLATEY' -Name $Package -Value (Get-Date -Format 'dd.MM.yyyy')
        }
    }
    # Get the INI file again and build the list of packages that should be installed
    $UpdatedINI = Split-Ini -Path $RMMIni
    $InstallChecks = ($UpdatedINI | Where-Object -Property 'Section' -EQ 'CHOCOLATEY' | Select-Object 'Name').Name
    # Compare installed Chocolatey packages to the list of packages that should be present
    $InstallList = @()
    foreach ($InstallCheck in $InstallChecks) {
        if ($ChocoApps -notcontains $InstallCheck) {
            $InstallList += $InstallCheck
        }
    }
    # Install packages if needed
    if (!($InstallList)) {
        $Return.Install_List = "No new packages to install"
    }  
    else {
        $Return.Error_Count++
        $Return.Install_List = $InstallList | Format-List | Out-String
        $Return.Install_Output = . $Choco install -yr --no-progress @InstallList | Out-String
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Install_Catch = $myException 
    $Return.Error_Count++ 
}
# END REGION

# REGION Update all packages
Try {
	$Return.Upgrade_Output = . $Choco upgrade all -yr --no-progress | Out-String
} Catch {
	$myException = $_.Exception | Format-List | Out-String
    $Return.Upgrade_Catch = $myException 
    $Return.Error_Count++ 
}
# END REGION

# REGION Clean-up
try {
    # Remove any unwanted desktop shortcuts if they exist.
    $DesktopPath = [System.Environment]::GetFolderPath("CommonDesktopDirectory")
    foreach ($item in $IconCleanup) {
        $itempath = $DesktopPath + "\" + $item
	    if (Test-Path $itempath) {
            # Use $Return.Add() because it thinks Remove_Icon_ is a method
            $itemReturn = "Remove_Icon_" + $item
            $itemOutput = Remove-Item -Path $itempath -Force | Out-String
		    $Return.Add("$itemReturn", "$itemOutput")
	    }
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Cleanup_Catch = $myException 
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