<#
.Synopsis
   Installs Chocolatey, Powershell, Boxstarter, and Carbon if missing. Creates folders
   for automation with the RMM platform. Creates environment variables to be
   used by other scripts. Creates a custom event source for the application
   log to be used by other scripts. Checks for TXT error files to trigger an alert.
.DESCRIPTION
   The script is to be uploaded to your dashboard account as a user script.
   It can run both as a script check and as a scheduled task. Edit $RMM_Name to
   change the base folder name, environment variable names, and event log source name.
 .EXAMPLE
   vitCheck-RMMDefaults.ps1
.OUTPUTS
   Creates folders, envent log source, environment variables and output for the dashboard.
.NOTES
   Some syntax is less clear to support various limitations of different versions of Powershell.
   If the script is successfull, Powershell should be updated and all subsequent scripts can use
   most recent syntax.
.EMAIL
   vdonley@visionms.net
.VERSION
   .5
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

# Create ordered list for return (must be compatible with PS v2 in case v5.1 is not yet installed)
$Return = New-Object System.Collections.Specialized.OrderedDictionary

# Start an error counter so MaxRM will correctly error on failure
# When adding to Error_Count must divide by 1 to force it to be treated as a number
$Return.Add("Error_Count","0")

# Event source to create
$RMMEventSource = "VisionIT"

# List of folders to check for and create the folders if they don't exist
$RMMBase = $env:SystemDrive + "\" + $RMMEventSource + "_MSP"
$ErrorPath = $RMMBase + "\Errors"
$LogPath = $RMMBase + "\Logs"
$ReportPath = $RMMBase + "\Reports"
$StagingPath = $RMMBase + "\Staging"
$AllFolders = $RMMBase,$ErrorPath,$LogPath,$ReportPath,$StagingPath

# REGION Get Windows versions and Exit with error if script will not function
try {
    $OSInfo = Get-WmiObject Win32_OperatingSystem | Select-Object Caption,OSArchitecture,Version
    $OSInfoReturn = $OSInfo | Format-List | Out-String
    $Return.Add("OS_Info","$OSInfoReturn")
    if (($OSInfo.Caption -like "*Windows 7*") -or ($OSInfo.Caption -like "*Server 2008 R2") `
        -or ($OSInfo.Caption -like "*Windows 8.1*") -or ($OSInfo.Caption -like "*Server 2012 R2") `
        -or ($OSInfo.Caption -like "*Windows 10*") -or ($OSInfo.Caption -like "*Server 2016*")) {
        
            $Return.Add("OS_Check","Success")   
    }
    else {
        $Return.Add("OS_Check","Failure - Script will not work!")
        $Return.Error_Count = $Return.Error_Count/1 + 1
        Write-Output @"
        
Check Failure!
Troubleshooting info below
_______________________________
 
"@
        $Return | Format-List | Out-String
        Exit 1001
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Add("OS_Check_Catch","$myException")
    $Return.Error_Count = $Return.Error_Count/1 + 1
}
# END REGION

# REGION Check if Chocolatey is installed and fix if needed
try {
    # Don't depend on PATH to run Chocolatey
    $Choco = $env:ProgramData + "\chocolatey\bin\choco.exe"
    if (Test-Path $Choco) {
        $Return.Add("Chocolatey_Install_Check","Chocolatey found - Installed at $Choco")
    }
   else {
        $Return.Error_Count = $Return.Error_Count/1 + 1
        $Return.Add("Chocolatey_Install_Check","Chocolatey not installed - Trying to install")
        $ChocolateyInstall = Invoke-Expression -ErrorAction 'Stop' ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1')) | Out-String
        $Return.Add("Chocolatey_Install_Output","$ChocolateyInstall")
        If (Test-Path $Choco) {
            $Return.Add("Chocolatey_Install_Result","Chocolatey found - Installed at $Choco")
        }
        Else {
            $Return.Add("Chocolatey_Install_Result","Chocolatey not found - Install ran but failed")
            $Return.Error_Count = $Return.Error_Count/1 + 1
            Write-Output @"
            
Check Failure!
Troubleshooting info below
_______________________________
    
"@
            $Return | Format-List | Out-String
            Exit 1001
        }
    }
} 
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Add("Chocolatey_Install_Catch","$myException") 
    $Return.Error_Count = $Return.Error_Count/1 + 1
}
# END REGION

# REGION Old Chocolatey Upgrade
try {
    # Parse Choco.exe to get version
	$ChocoCheck = . $Choco
	if (($ChocoCheck | Measure-Object -Line).Lines -gt '1') {
		$ChocoCheck = ($ChocoCheck -split '\n')[0]
    }
    $ChocoReport = $ChocoCheck
	$ChocoCheck = $ChocoCheck -replace '\s',''
	$ChocoCheck = $ChocoCheck -split 'v'
	$ChocoCheck = $ChocoCheck.Split('.')
	if ($ChocoCheck.Count -lt 4) {
        $Return.Error_Count = $Return.Error_Count/1 + 1
        $Return.Add("Chocolatey_Version_Check","Chocolatey version check failed")
        Write-Output @"
        
Check Failure!
Troubleshooting info below
_______________________________

"@
		$Return | Format-List | Out-String
		Exit 1001
    }
    # Test the Chocolatey version to see if update is needed
    [hashtable]$ChocoVersion = @{
        "Name" = $ChocoCheck[0];
        "Major" = $ChocoCheck[1];
        "Minor" = $ChocoCheck[2];
        "Build" = $ChocoCheck[3]
    }
	if (($ChocoVersion.Major -ge '1') -or (($ChocoVersion.Minor -ge '10') -and ($ChocoVersion.Build -ge '7'))) {
		$Return.Add("Chocolatey_Version_Check","Forced update not required - $ChocoReport")
	}
	else {
        $Return.Error_Count = $Return.Error_Count/1 + 1
        $Return.Add("Chocolatey_Version_Check","Update required - $ChocoReport")
        $ChocoUpdateResult = Invoke-Expression -ErrorAction 'Stop' ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1')) | Out-String
        $Return.Add("Chocolatey_Update_Result","$ChocoUpdateResult")
        # Make sure update succeded
        $ChocoRetest = . $choco
        if (($ChocoRetest | Measure-Object -Line).Lines -gt '1') {
            $ChocoRetest = ($ChocoRetest -split '\n')[0]
        }
        if ($ChocoCheck -eq "$ChocoRetest") {
            $Return.Error_Count = $Return.Error_Count/1 + 1
            $Return.Add("Chocolatey_Version_Retest","Chocolatey update did not take effect")
            Write-Output @"
            
Check Failure!
Troubleshooting info below
_______________________________
    
"@
            $Return | Format-List | Out-String
            Exit 1001
        }
	}
}
catch {
	$myException = $_.Exception | Format-List | Out-String
    $Return.Add("Chocolatey_Update_Catch","$myException") 
    $Return.Error_Count = $Return.Error_Count/1 + 1
}
# END REGION

# REGION Get Chocolatey in system path if needed
# Check if Chocolatey is in the system path and add it if it is missing
try {
    $ChocoPath = $env:ProgramData + "\chocolatey\bin"
    # Check the registry key in case path has been applied but computer has not been rebooted yet.
    $RegistryPath =  "Registry::HKLM\System\CurrentControlSet\Control\Session Manager\Environment"
    $CurrentPath = (Get-ItemProperty -Path $RegistryPath -Name PATH).Path
    if (!($CurrentPath -like "*$ChocoPath*")) {
        $Return.Error_Count = $Return.Error_Count/1 + 1
        $NewPath = $CurrentPath + ";" + $ChocoPath
        Set-ItemProperty -Path $RegistryPath -Name PATH -Value $NewPath -Force
        $Return.Add("Chocolatey_Path_Check",'Adding Chocolatey to path')
    }
    
    else {
        $Return.Add("Chocolatey_Path_Check",'Chocolatey found in path')
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Add("Chocolatey_Path_Catch","$myException") 
    $Return.Error_Count = $Return.Error_Count/1 + 1
}
# END REGION

# REGION Check Powershell version and update if needed
try {
    $PSVersionCheck = $PSVersionTable.PSVersion
    $PSVersionString = "Powershell v" + $PSVersionCheck.Major + "." + $PSVersionCheck.Minor
    if (($PSVersionCheck.Major -gt '5') -or (($PSVersionCheck.Major -eq '5') -and ($PSVersionCheck.Minor -ge '1'))) {
        $Return.Add("Powershell_Version_Check","No update needed - $PSVersionString")
    }
    # Powershell v3 upgrade must be forced
    elseif ($PSVersionCheck.Major -eq '3') {
        $Return.Error_Count = $Return.Error_Count/1 + 1
        # Check to see if Powershell has been updated but computer has not yet rebooted
        $PSChocoInstallCheck = . $Choco list -lo
        if ($PSChocoInstallCheck -like "*Powershell 5*") {
            $Return.Add("Powershell_Version_Check","$PSVersionString updated by Chocolatey - Reboot required")
            Write-Output @"
            
Check Failure!
Troubleshooting info below
_______________________________

"@
            $Return | Format-List | Out-String
            Exit 1001
        }
        else {
            $Return.Add("Powershell_Version_Check","Powershell update and reboot required - $PSVersionString")
            $PSUpgradeOut = . $choco install -yrf --no-progress powershell | Out-String
            $Return.Add("Powershell_Upgrade_Result","$PSUpgradeOut")
            Write-Output @"
            
Check Failure!
Troubleshooting info below
_______________________________

"@
            $Return | Format-List | Out-String
            Exit 1001
        }
        
    }
    # Update Powershell versions that do not need to be forced
    else {
        $PSChocoInstallCheck = .$Choco list -lo
        if ($PSChocoInstallCheck -like "*Powershell 5*") {
            $Return.Add("Powershell_Version_Check","$PSVersionString updated by Chocolatey - Reboot required")
            Write-Output @"
            
Check Failure!
Troubleshooting info below
_______________________________

"@
            $Return | Format-List | Out-String
            Exit 1001
        }
        else {
            $Return.Add("Powershell_Version_Check","Powershell update and reboot required - $PSVersionString")
            $PSUpgradeOut = . $choco install -yr --no-progress powershell | Out-String
            $Return.Add("Powershell_Upgrade_Result","$PSUpgradeOut")
            Write-Output @"
            
Check Failure!
Troubleshooting info below
_______________________________

"@
            $Return | Format-List | Out-String
            Exit 1001
        }
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Add("Powershell_Upgrade_Catch","$myException") 
    $Return.Error_Count = $Return.Error_Count/1 + 1
}
# END REGION

# REGION Make sure Carbon module is installed
try {
    $CarbonInstallCheck = Get-Module -ListAvailable -Name Carbon
    if (!($CarbonInstallCheck)) {
        $Return.Error_Count = $Return.Error_Count/1 + 1
        $Return.Add("Carbon_Install_Check","Carbon module not found - Installing")
        $CarbonInstallOut = . $choco install -yr --no-progress carbon | Out-String
        $Return.Add("Carbon_Install_Result","$CarbonInstallOut")
        $CarbonInstallRetest = Get-Module -ListAvailable -Name Carbon
        if (!($CarbonInstallRetest)) {
            $Return.Error_Count = $Return.Error_Count/1 + 1
            $Return.Add("Carbon_Install_Retest","Carbon module not found - Exiting")
            Write-Output @"
            
Check Failure!
Troubleshooting info below
_______________________________

"@
            $Return | Format-List | Out-String
            Exit 1001
        }
    }
    else {
        $CarbonVersion = $CarbonInstallCheck.Version
        $Return.Add("Carbon_Install_Check","Carbon module found - Carbon v$CarbonVersion")
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Add("Carbon_Install_Catch","$myException") 
    $Return.Error_Count = $Return.Error_Count/1 + 1
}
# END REGION

# REGION Make sure Boxstarter is installed
try {
    $BoxstarterInstallCheck = Get-Module -ListAvailable -Name Boxstarter.Common
    if (!($BoxstarterInstallCheck)) {
        $Return.Error_Count = $Return.Error_Count/1 + 1
        $Return.Add("Boxstarter_Install_Check","Boxstarter module not found - Installing")
        $BoxstarterInstallOut = . $choco install -yr --no-progress boxstarter | Out-String
        $Return.Add("Boxstarter_Install_Result","$BoxstarterInstallOut")
        $BoxstarterInstallRetest = Test-Path -Path "$env:ProgramData\Boxstarter\Boxstarter.bat"
        if (!($BoxstarterInstallRetest)) {
            $Return.Error_Count = $Return.Error_Count/1 + 1
            $Return.Add("Boxstarter_Install_Retest","Boxstarter module not found - Exiting")
            Write-Output @"
            
Check Failure!
Troubleshooting info below
_______________________________

"@
            $Return | Format-List | Out-String
            Exit 1001
        }
    }
    else {
        $BoxstarterVersion = $CarbonInstallCheck.Version | Out-String
        $Return.Add("Boxstarter_Install_Check","$BoxstarterVersion")
    }
    # Remove All Users Desktop shortcut for Boxstarter
    $AllUserDesktopLinks = ([environment]::GetFolderPath("CommonDesktopDirectory")) + "\*.lnk"
    Get-ChildItem -Path  $AllUserDesktopLinks | Where-Object -Property Name -Like "*Boxstarter*" | Remove-Item -Force
    # Remove Start Menu folder for Boxstarter
    $AllUserStartMenuBoxstarter = ([environment]::GetFolderPath("CommonStartMenu")) + "\Programs\Boxstarter"
    Uninstall-Directory -Path $AllUserStartMenuBoxstarter -Recurse
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Add("Boxstarter_Install_Catch","$myException") 
    $Return.Error_Count = $Return.Error_Count/1 + 1
}
# END REGION

# REGION Create folders if missing
try {
    foreach ($item in $AllFolders) {
        Install-Directory -Path $item
    }
    foreach ($item in $AllFolders) {
        if (Test-Path -Path $item) {
            $Return.Add("Folder_Check_$item","Found")
        }
        else {
            $Return.Error_Count = $Return.Error_Count/1 + 1
            $Return.Add("Folder_Check_$item","Not found")
        }
    }
    # Make sure the base RMM folder is hidden
    Get-Item -Path $RMMBase -Force | ForEach-Object {$_.Attributes = $_.Attributes -bor "Hidden"}    
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Add("Folder_Check_Catch","$myException") 
    $Return.Error_Count = $Return.Error_Count/1 + 1
}

# END REGION

# REGION Event log source

# Check to see if event log source for the application log exists and create if missing
try {
    if ( [System.Diagnostics.EventLog]::SourceExists( "$RMMEventSource" )) {
        $Return.Add("Event_Source_Check","Event source found - $RMMEventSource")
    }

    else {
        $Return.Error_Count = $Return.Error_Count/1 + 1
        $Return.Add("Event_Source_Check","Event source missing - Creating $RMMEventSource")
        [System.Diagnostics.EventLog]::CreateEventSource( $RMMEventSource, "Application" )
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Add("Event_Source_Catch","$myException") 
    $Return.Error_Count = $Return.Error_Count/1 + 1
}

# END REGION

# REGION System Envirionment Variables

# Create system variables to be used by other scripts
try {
    if ($env:RMMFolder -eq $RMMBase) {
        $Return.Add("RMM_Folder_Variable_Check","Envirionment variable found - RMMFolder = $env:RMMFolder")
    }
    else {
        $Return.Error_Count = $Return.Error_Count/1 + 1
        $Return.Add("RMM_Folder_Variable_Check","Envirionment variable missing - Creating RMMFolder = $RMMBase")
        Set-EnvironmentVariable -Name 'RMMFolder' -Value $RMMBase -ForComputer -Force
        if (!($env:RMMFolder -eq $RMMBase)) {
            $Return.Error_Count = $Return.Error_Count/1 + 1
            $Return.Add("RMM_Folder_Variable_Retest","Environment variable creation failed - RMMFolder = $RMMBase")
        }
    }
    if ($env:RMMErrorFolder -eq $ErrorPath) {
        $Return.Add("RMM_Error_Folder_Variable_Check","Envirionment variable found - RMMErrorFolder = $env:RMMErrorFolder")
    }
    else {
        $Return.Error_Count = $Return.Error_Count/1 + 1
        $Return.Add("RMM_Error_Folder_Variable_Check","Envirionment variable missing - Creating RMMErrorFolder = $ErrorPath")
        Set-EnvironmentVariable -Name 'RMMErrorFolder' -Value $ErrorPath -ForComputer -Force
        if (!($env:RMMErrorFolder -eq $ErrorPath)) {
            $Return.Error_Count = $Return.Error_Count/1 + 1
            $Return.Add("RMM_Error_Folder_Variable_Retest","Environment variable creation failed - RMMErrorFolder = $ErrorPath")
        }
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Add("Enviornment_Variable_Catch","$myException") 
    $Return.Error_Count = $Return.Error_Count/1 + 1
}

# END REGION

# REGION Check for files in the error folder

# Check to see if an error files exist and write their content
try {
    $ErrorFiles = Get-ChildItem $ErrorPath
    if ($ErrorFiles.Count -ge 1) {
        $ErrorFilesCount = $ErrorFiles.Count
        $Return.Error_Count = $Return.Error_Count + $ErrorFilesCount
        $Return.Add("Error_Files","$ErrorFilesCount files found`n")
        foreach ($item in $ErrorFiles) {
            $ErrorFileContent = Get-Content -Path $item.FullName -Raw
            [string]$ReturnItem = "_______________________________`n" + $item.Name + "`n" + $item.LastWriteTime + "`n" + $ErrorFileContent + "`n"
            $return.Error_Text = $Return.Error_Text + $ReturnItem
            }
    }
    else {
        $Return.Add("Error_Files","No files found")
    }    
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Add("Error_Files_Catch","$myException") 
    $Return.Error_Count = $Return.Error_Count/1 + 1
}

# END REGION

# REGION Output results and create an alert if needed

if ($Return.Error_Count -eq 0) {
    Write-Output @"
     
Check Passed!
Troubleshooting info below
_______________________________
   
"@
    $Return | Format-List | Out-String
    Exit 0
    }
else {
    Write-Output @"
    
Check Failure!
Troubleshooting info below
_______________________________

"@
    $Return | Format-List | Out-String
    Exit 1001
}