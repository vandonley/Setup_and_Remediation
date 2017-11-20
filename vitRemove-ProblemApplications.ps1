<#
.Synopsis
   Removes software silently on servers and workstations.
.DESCRIPTION
   The script is to be uploaded to your dashboard account as a user script.
   It can run both as a script check and as a scheduled task. Script removal
   of applications that we never want to see on a workstation.
   Intended to be used with RMM folder checks for error reporting. Will remove
   the default applications or applications can be removed using command line arguments.
   Use -WMIRemovals as an array of names to look for in Win32_Product.
   Use -ARPRemovals as a hashtable of names for key and uninstall command suffix for silent uninstall.
   Use -ChocoRemovals as an array of names to check for Chocolatey packages to remove.
.EXAMPLE
   .\vitRemove-ProblemApplications.ps1
.EXAMPLE
    .\vitRemove-ProblemApplications.ps1 `
    -WMIRemovals Quicktime,Silverlight `
    -ARPRemovals @{"Malwarebytes"=" /verysilent /suppressmsgboxes /norestart"} `
    -ChocoRemovals adobeshockwaveplayer
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
    # WMI installs to remove, default if none are entered
    [Parameter(Mandatory=$false)]
    [array]$WMIRemovals = @('Quicktime','Silverlight'),

    # Uninstall registry keys of programs to remove to remove, default if none are entered
    [Parameter(Mandatory=$false)]
    [hashtable]$ARPRemovals = @{"Malwarebytes"=" /verysilent /suppressmsgboxes /norestart"},

    # WMI installs to remove, default if none are entered
    [Parameter(Mandatory=$false)]
    [array]$ChocoRemovals = @('adobeshockwaveplayer','malwarebytes','quicktime','silverlight'),

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
    $ErrorFileName = "vitRemove-ProblemApplications.txt"
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

# REGION Get uninstall information for all applications so it doesn't query for every program.
try {
    # Retrieve the WMI installed application information
    $WMIApps = Get-WmiObject -Class Win32_Product
    # Use Carbon module to get installed application from the registry
    $ARPApps = Get-ProgramInstallInfo
    # Get the path to Chocolatey and Chocolatey package list then parse the list
    $Choco = $env:ChocolateyInstall + "\bin\choco.exe"
    $ChocoList = (. $Choco list -lo)
    $ChocoApps = @{}
    foreach ($item in $ChocoList) {
        $Package = $item.Split(' ')
        $ChocoApps[$Package[0]]=$Package[1]
    }
    # Get the path to the RMM INI file and its contents if packages are listed there
    $RMMAgent = Get-ServiceConfiguration -name 'Advanced Monitoring Agent'
    $RMMPath = Split-Path $RMMAgent.Path.Replace('"',"") -Parent
    $RMMIni = $RMMPath + "\settings.ini"
    $RMMSettings = Split-Ini -Path $RMMIni
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Installed_Applications_Catch = $myException 
    $Return.Error_Count++
}
# END REGION

# REGION Remove WMI Applications
try {
    # Start a counter of WMI applications found, if none are found report success
    $WMIFoundCount = 0
    # Make sure there are installs to check for
    if ($WMIRemovals) {
        # See if the apps listed in WMIRemovals are installed
        foreach ($WMIRemoval in $WMIRemovals) {
            # There may be more than one app with the name, create a list to uninstall and return them
            if ($WMIApps.Name -like "*$WMIRemoval*") {
                $WMIFoundCount++
                $WMItoRemove = $WMIApps | Where-Object -Property Name -Like "*$WMIRemoval*"
                $WMIRemovalReturn = $WMIRemoval + "_Found"
                $Return.$WMIRemovalReturn = $WMItoRemove | Select-Object Name,Version | Format-List | Out-String
                # Remove each application
                foreach ($item in $WMItoRemove) {
                    $Return.Error_Count++
                    $itemReturn = $item.Name + "_" + $item.Version + "_Output"
                    $Return.$itemReturn = ($item).Uninstall() | Out-String
                } 
            } 
        }
    }
    if ($WMIFoundCount -eq '0') {
        $Return.WMI_Removal = "No WMI applications found for uninstall"
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.WMI_Removal_Catch = $myException 
    $Return.Error_Count++
}
# END REGION

# REGION Add and Remove Programs from the registry to uninstall
try {
    # Start a counter for how many installs are found
    $ARPFoundCount = 0
    # Check that there are installs to check for
    if ($ARPRemovals) {
        foreach ($ARPRemoval in $ARPRemovals.GetEnumerator()) {
            # There may be more than one install that matches the name, create a list
            $ARPName = $ARPRemoval.Name
            if ($ARPApps.DisplayName -like "*$ARPName*" ) {
                $ARPFoundCount++
                $ARPtoRemove = $ARPApps | Where-Object -Property 'DisplayName' -like "*$ARPName*"
                $ARPReturn = $ARPName + "_Found"
                $Return.$ARPReturn = $ARPtoRemove | Select-Object DisplayName,Version | Format-List | Out-String
                # Remove each application
                foreach ($item in $ARPtoRemove) {
                    $Return.Error_Count++
                    $itemReturn = $item.DisplayName + "_" + $item.Version + "_Output"
                    $SilentUninstall = $item.UninstallString + $ARPRemoval.Value
                    $Return.$itemReturn = . cmd /c $Silentuninstall | Out-String                    
                }
            }
        }
    }
    if ($ARPFoundCount -eq '0') {
        $Return.ARP_Removal = "No Add and Remove programs found for uninstall"
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.ARP_Removal_Catch = $myException 
    $Return.Error_Count++
}
# END REGION

# REGION Chocolatey packages to remove
try {
    # Start a counter of packages found
    $ChocoFoundCount = 0
    # Check that there are Chocolatey packages to remove
    if ($ChocoRemovals) {
        foreach ($ChocoRemoval in $ChocoRemovals) {
            # Check if the package is installed
            if ($ChocoApps.Keys -eq $ChocoRemoval) {
                $ChocoFoundCount++
                $Return.Error_Count++
                $ChocoReturn = $ChocoRemoval + "_Output"
                $Return.$ChocoReturn = . $Choco uninstall -yr $ChocoRemoval | Out-String
                # Check to see if uninstall must be forced
                $ChocoForceCheck = . $Choco list -lo $ChocoRemoval
                if (!($ChocoForceCheck -like "0 packages installed")) {
                    $Return.Error_Count++
                    $ChocoForceReturn = $ChocoRemoval + "_Forced_Output"
                    $Return.$ChocoForceReturn = . $Choco uninstall -yrf $ChocoRemoval | Out-String
                }
                # Remove from RMM settings.ini file if present for tracking
                if ($RMMSettings.Section -eq "CHOCOLATEY" -and $RMMSettings.Name -eq $ChocoRemoval) {
                    $Return.Error_Count++
                    $INIReturn = $ChocoRemoval + "_RMM_INI_Output"
                    $Return.$INIReturn = Remove-IniEntry -Path $RMMIni -Section CHOCOLATEY -Name $ChocoRemoval
                }
            }
        }
    }
    if ($ChocoFoundCount -eq '0') {
        $Return.Choco_Removal = "No Chocolatey packages found for uninstall"
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Choco_Removal_Catch = $myException 
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