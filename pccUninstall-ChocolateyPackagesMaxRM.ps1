<#
.Synopsis
   Removes software silently on servers and workstations using Chocolatey.
.DESCRIPTION
   The script is to be uploaded to your dashboard account as a user script.
   It can run both as a script check and as a scheduled task. You list package 
   names as parameter to script. Chocolatey will update packages that are 
   already installed. Intended to be used with pccCheck-RMMFolders for error
   
   Warning: If you later omit a package name it will NOT be uninstalled!
.EXAMPLE
   pccUninstall-ChocolateyPackagesMaxRM notepadplusplus adobereader
.EXAMPLE
   pccUninstall-ChocolateyPackagesMaxRM dropbox googlechrome
.EXAMPLE
   pccUninstall-ChocolateyPackagesMaxRM google-chrome-x64
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
$ErrorFile = $env:RMMErrorFolder + "\pccUninstall-ChocolateyPackagesMaxRM.txt"

If (-not ($Packages)) {
	$Return.Package_Error = "No packages listed as an argument"
	$ErrorCount = $ErrorCount +1
}

#Region Functions

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


#EndRegion

#
$inifile = $gfimaxpath + '\settings.ini'
$settings = Get-IniContent $inifile

If (!($Settings['CHOCOLATEY'])) {
	$Settings['CHOCOLATEY'] = @{}
}

# Chocolatey commands
$Choco = $env:ProgramData + "\chocolatey\bin\choco.exe"

Write-Host "Removing packages:"

# Make a copy of installed packages as the hashtable cannot be changed while
# using it as base for a foreach loop
$packageList = @()
Foreach ($TrackedPackage in $settings['CHOCOLATEY'].Keys) {
    $Packagelist += $TrackedPackage.ToString()
}

# Get installed packages and separate package name from version
$InstalledPackages = ( &clist -localonly)
$InstalledList = @{}
Foreach ($InstalledPackage in $InstalledPackages) {
	$Package = $InstalledPackage.Split(' ')
    $InstalledList[$Package[0]] = $Package[1]
}
	
# Loop through each package from command line and remove if needed
Foreach ($Package in $Packages) {
    Try {
        If (($InstalledList.Contains($Package))) {
            $ReturnValue = "Uninstall_" + $Package
            $Return.$ReturnValue = . $Choco uninstall -y $Package | Out-String
        }
        if ($packageList -contains $Package) {
            $settings['CHOCOLATEY'].Remove($Package)
            Out-IniFile $settings $inifile 
        } 
    } Catch {
        $PackageReturn = "Uninstall_Failure_" + $Package
        $Return.$PackageReturn = $_.Exception | Format-List | Out-String
        $ErrorCount = $ErrorCount + 1
    }
}

# Get installed packages and separate package name from version in case uninstall needs to be forced
$InstalledPackages = ( &clist -localonly)
$InstalledList = @{}
Foreach ($InstalledPackage in $InstalledPackages) {
	$Package = $InstalledPackage.Split(' ')
	$InstalledList[$Package[0]] = $Package[1]
}

# Loop through each package from command line and remove if needed
Foreach ($Package in $Packages) {
        Try {
        If (($InstalledList.Contains($Package))) {
            $ReturnValue = "Uninstall_Forced_" + $Package
            $Return.$ReturnValue = . $Choco uninstall -yf $Package | Out-String
        }
    } Catch {
        $PackageReturn = "Uninstall_Forced_Failure_" + $Package
        $Return.$PackageReturn = $_.Exception | Format-List | Out-String
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
	$Return | Format-List | Out-String
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