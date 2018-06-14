<#
.Synopsis
   Installs a URL shortcut to the All Users Desktop.
.DESCRIPTION
   The script is to be uploaded to your dashboard account as a user script.
   It can run both as a script check and as a scheduled task. By default, the script
   creates a shortcut to "https://outlook.office.com". You can change this by setting
   -Name and -URL
 .EXAMPLE
   vitInstall-DesktopURL.ps1
 .EXAMPLE
   vitInstall-DesktopURL.ps1 -Name 'Outlook Web Access' -URL 'https://outlook.office.com'
.OUTPUTS
   Creates a URL shortcut in the All Users Desktop.
.NOTES
   
.EMAIL
   vdonley@visionms.net
.VERSION
   .5
#>
param (
    # Name of the shortcut
    [Parameter(Mandatory=$false)]
    [string]
    $Name='Outlook Web Access',

    # URL for the shorcut
    [Parameter(Mandatory=$false)]
    [string]
    $URL='http://outlook.office.com',
    
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

# Create an error counter
[int]$ErrorCount = 0

# Create ordered list for return (must be compatible with PS v2 in case v5.1 is not yet installed)
$Return = New-Object System.Collections.Specialized.OrderedDictionary

# REGION Variables
# Shell object for shortcut
$Shell = New-Object -ComObject ("WScript.Shell")
# Path to the All Users Desktop
$myDesktop = [Environment]::GetFolderPath("CommonDesktopDirectory")
# Path to the shorcut
$myPath = $myDesktop + "\" + $Name + ".url"
# Add to Return
$Return.Add("Error_Count","$ErrorCount")
$Return.Add("Name","$Name")
$Return.Add("URL","$URL")
$Return.Add("Shortcut_Path","$myPath")
# END REGION

# REGION Create shortcut
try {
    # Create the shortcut
    $Favorite = $Shell.CreateShortcut($myPath)
    $Favorite.TargetPath = $URL;
    $Favorite.Save()
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Add("Shortcut_Catch","$myException")
    $ErrorCount++
}
# END REGION

# REGION Check for shortcuts existence
# Check if the shortcut exists
$myTest = Test-Path -Path $myPath
# Return the test
if ($myTest) {
    $Return.Add("Shortcut_Exists","Success")
}
else {
    $Return.Add("Shortcut_Exists","Fail")
    $ErrorCount++
}
# END REGION

# REGION Output results and create an alert if needed

if ($ErrorCount -eq 0) {
    Write-Output @"
     
Script Success!
Troubleshooting info below
_______________________________
   
"@
    $Return | Format-List | Out-String
    Exit 0
    }
else {
    $Return.Error_Count = $ErrorCount
    Write-Output @"
    
Check Failure!
Troubleshooting info below
_______________________________

"@
    $Return | Format-List | Out-String
    Exit 1001
}
# END REGION