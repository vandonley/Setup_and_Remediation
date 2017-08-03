<#
.Synopsis
   Installs software silently on servers and workstations using Chocolatey.
.DESCRIPTION
   The script is to be uploaded to your dashboard account as a user script.
   It can run both as a script check and as a scheduled task. You list package 
   names as parameter to script. Chocolatey will update packages that are 
   already installed. Intended to be used with pccCheck-RMMFolders for error
   
   Warning: If you later omit a package name it will NOT be uninstalled!
.EXAMPLE
   Install-ApplicationsFromMAXfocus notepadplusplus adobereader
.EXAMPLE
   Install-ApplicationsFromMAXfocus dropbox googlechrome
.EXAMPLE
   Install-ApplicationsFromMAXfocus google-chrome-x64
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
   vand@parseccomputer.com
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
Write-Host " "

# Create hashtable for output
[hashtable]$Return = @{}

# Start an error counter so MaxRM will correctly error on failure
[int]$ErrorCount = '0'

# List of folders to check for and create the folders if they don't exist
$StagingPath = $env:RMMFolder + "\Staging"
$ErrorFile = $env:RMMErrorFolder + "\Install-ApplicationsFromMAxRM.txt"

If (-not ($Packages)) {
	$Return.Package_Error = "No packages listed as an argument"
	$ErrorCount = $ErrorCount +1
}

#Region Functions

function Restart-MAXfocusService ([bool]$Safely=$true) {
	If ($Safely) {	
		# Update last runtime to prevent changes too often
		[int]$currenttime = $(get-date -UFormat %s) -replace ",","." # Handle decimal comma 
		$settingsContent["DAILYSAFETYCHECK"]["RUNTIME"] = $currenttime
	}
	# Clear lastcheckday to make DSC run immediately
	$settingsContent["DAILYSAFETYCHECK"]["LASTCHECKDAY"] = "0"
	Out-IniFile $settingsContent $IniFile
		
	# Prepare restartscript
	$RestartScript = $StagingPath + "\RestartMAXfocusAgent.cmd"
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
	$Result = &schtasks.exe /Create /TN $TaskName /TR "$RestartScript" /RU SYSTEM /SC ONCE /ST $StartTime /F
	If ($Result) {
		Output-Debug "Restarting Agent using scheduled task now."
		$Result = &schtasks.exe /run /TN "$TaskName"
	} 
		
	If (!($Result -like 'SUCCESS:*')) {
		Output-Debug "SCHTASKS.EXE failed. Restarting service the hard way."
		Restart-Service 'Advanced Monitoring Agent'
	}
	
	
}



# Downloaded from 
# http://blogs.technet.com/b/heyscriptingguy/archive/2011/08/20/use-powershell-to-work-with-any-ini-file.aspx
# modified to use ordered list by me
function Get-IniContent ($filePath) {
    $ini = New-Object System.Collections.Specialized.OrderedDictionary
    switch -regex -file $FilePath
    {
        "^\[(.+)\]" # Section
        {
			$section = $matches[1]
            $ini[$section] = New-Object System.Collections.Specialized.OrderedDictionary
            $CommentCount = 0
        }
        "^(;.*)$" # Comment
        {
            $value = $matches[1]
            $CommentCount = $CommentCount + 1
            $name = "Comment" + $CommentCount
            $ini[$section][$name] = $value
        } 
        "(.+?)\s*=(.*)" # Key
        {
            $name,$value = $matches[1..2]
            $ini[$section][$name] = $value
        }
    }
    return $ini
}
# Downloaded from 
# http://blogs.technet.com/b/heyscriptingguy/archive/2011/08/20/use-powershell-to-work-with-any-ini-file.aspx
# Modified to force overwrite by me
function Out-IniFile($InputObject, $FilePath) {
    $outFile = New-Item -ItemType file -Path $Filepath -Force
    foreach ($i in $InputObject.keys)
    {
        if ("Hashtable","OrderedDictionary" -notcontains $($InputObject[$i].GetType().Name))
        {
            #No Sections
            Add-Content -Path $outFile -Value "$i=$($InputObject[$i])"
        } else {
            #Sections
            Add-Content -Path $outFile -Value "[$i]"
            Foreach ($j in ($InputObject[$i].keys | Sort-Object))
            {
                if ($j -match "^Comment[\d]+") {
                    Add-Content -Path $outFile -Value "$($InputObject[$i][$j])"
                } else {
                    Add-Content -Path $outFile -Value "$j=$($InputObject[$i][$j])" 
                }

            }
            Add-Content -Path $outFile -Value ""
        }
    }
}


#EndRegion Functions

# Find "Advanced Monitoring Agent" service and use path to locate files
$gfimaxagent = Get-WmiObject Win32_Service | Where-Object { $_.Name -eq 'Advanced Monitoring Agent' }
# $gfimaxexe = $gfimaxagent.PathName
$gfimaxpath = Split-Path $gfimaxagent.PathName.Replace('"',"") -Parent

## Modify environment to support application install from User System
#  Set Shell folders to correct values for application install
#  If Shell folders must be modified the agent must be restarted
#  The point of the changes is to make per user installations 
#  put icons and files where the user can see and reach them.

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
		'Local AppData'		{ $NewValue = '{0}\Chocolatey\' -f $Env:ALLUSERSPROFILE }
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
	Write-Host 'Application install enviroment has been modified.'
}
Pop-Location # Return to scripts directory

## Check if service must be restarted
If ($RestartNeeded) {
	$Return.Special_Folders = @"
Service needs a restart before setting takes effect.
Restarting Now.
WARNING: Software installation will NOT happen until next run!
"@
	Restart-MAXfocusService
	$ErrorCount = $ErrorCount + 1
	Add-Content -Path $ErrorFile -Value "`n----------------------`n "
	Add-Content -Path $ErrorFile -Value (get-date) -passthru
	Add-Content -Path $ErrorFile -Value "`n "
	Add-Content -Path $ErrorFile -Value ( $Return | Format-List | Out-String )
    $Error.Clear() | Out-Null
    [string]$ErrorString = "Check Failure"
    [string]$ErrMessage = ( $Return | Format-List | Out-String )
    $Error.Add($ErrorString)
    Write-Error -Exception $ErrorString -ErrorId 1001 -Message $ErrMessage
	Exit 1001
}

#EndRegion

# Look for parameter '-uninstall'
# We can't have more than 1 non-positional parameter
$ParsedArray = @()
$Uninstall = $false
Foreach ($Package in $Packages) {
	If ($Package -eq '-uninstall') {
		$Uninstall = $true
	} Else {
		$ParsedArray += $Package
	}
}

$Packages = $ParsedArray

$inifile = $gfimaxpath + '\settings.ini'
$settings = Get-IniContent $inifile

If (!($Settings['CHOCOLATEY'])) {
	$Settings['CHOCOLATEY'] = @{}
}

# Chocolatey commands
$Choco = $env:ProgramData + "\chocolatey\bin\choco.exe"

#Region Install Chocolatey if necessary
If (!(Test-Path $Choco)) {
	$Return.Chocolatey_Install = "Chocolatey not installed. Trying to install."

	Try {
		Invoke-Expression -ErrorAction 'Stop' ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
	} Catch {
		$Return.Chocolatey_Install_Catch = $_.Exception | Format-List | Out-String
		$ErrorCount = $ErrorCount + 1
	}
	If (Test-Path $Choco) {
		$Return.Chocolatey_Install = "Chocolatey is installed. Proceeding."
	} Else {
		$Return.Chocolatey_Install = "ERROR: Installation succeeded, but Chocolatey still not found! Exiting."
		$ErrorCount = $ErrorCount + 1
	}
}
#EndRegion

Write-Host "Verifying package installation:"

If ($Uninstall) {
	# Make a copy of installed packages as the hashtable cannot be changed while
	# using it as base for a foreach loop
	$packageList = @()
	Foreach ($InstalledPackage in $settings['CHOCOLATEY'].Keys) {
		$Packagelist += $InstalledPackage.ToString()
	}
	
	# Loop through copy of hashtable keys, updating hashtable if necessary
	Foreach ($InstalledPackage in $Packagelist) {
		$ErrorActionPreference = 'Stop'
		Try {
			If ($Packages -notcontains $InstalledPackage) {
				. $Choco uninstall -y $InstalledPackage
			}
			$settings['CHOCOLATEY'].Remove($Package)
			Out-IniFile $settings $inifile 
		} Catch {
			$ErrorActionPreference = 'Continue'
			$PackageReturn = "Uninstall_Failure_" + $Package
			$Return.$PackageReturn = $_.Exception | Format-List | Out-String
		}
	}
}

# Get installed packages and separate package name from version
$InstalledPackages = ( &choco list -localonly)
$InstalledList = @{}
Foreach ($InstalledPackage in $InstalledPackages) {
	$Package = $InstalledPackage.Split(' ')
	$InstalledList[$Package[0]] = $Package[1]
}

# Loop through package names given to us from command line
$InstallPackages = @()
Foreach ($Package in $Packages) {
	# Maintain installed package list in agent settings.ini
	If ($Settings['CHOCOLATEY'][$Package] -notmatch '\d\d\.\d\d\.\d{4}') {
		$Settings['CHOCOLATEY'][$Package] = Get-Date -Format 'dd.MM.yyyy'
		Out-IniFile $settings $inifile 
	}
	If (!($InstalledList.ContainsKey($Package))) {
		$InstallPackages += $Package
	}
}

Write-Host 'Updating All'
Try {
	$Return.CUP = . $choco upgrade all -yr --no-progress
} Catch {
	$Return.CUP_Error = $_.Exception | Format-List | Out-String
}
	Write-Host ('Installing packages {0}' -f $InstallPackages)
If ($InstallPackages.Count -gt 0) {	
	Try {
		$Return.cint = . $choco install -yr --no-progress @InstallPackages
	} Catch {
		$Return.Package_Install_Error = $_.Exception | Format-List | Out-String
		$ErrorCount = $ErrorCount + 1
	}
}

# Return output and create alert if needed or cleanup error file if successful
$Return.Error_Count = $ErrorCount
if ($ErrorCount -eq 0) {
Write-Output @"
 
Script Success!
Troubleshooting info below
_______________________________
 
"@
	$Return | Format-List
	if (Test-Path $ErrorFile) {
		Remove-Item $ErrorFile
	}
	Exit 0
}
else {
	Add-Content -Path $ErrorFile -Value "`n----------------------`n "
	Add-Content -Path $ErrorFile -Value (get-date) -passthru
	Add-Content -Path $ErrorFile -Value "`n "
	Add-Content -Path $ErrorFile -Value ( $Return | Format-List | Out-String )
    $Error.Clear() | Out-Null
        [string]$ErrorString = "Check Failure"
        [string]$ErrMessage = ( $Return | Format-List | Out-String )
        $Error.Add($ErrorString)
        Write-Error -Exception $ErrorString -ErrorId 1001 -Message $ErrMessage
        Exit 1001
}