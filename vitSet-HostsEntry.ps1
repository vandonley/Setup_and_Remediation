<#
.Synopsis
   Add an entry to the Windows hosts file
.DESCRIPTION
   The script is to be uploaded to your dashboard account as a user script.
   It can run both as a script check and as a scheduled task. Expects to be run
   with vitCheck-RMMDefaults.ps1
.EXAMPLE
   vitSet-HostsEntry
.EXAMPLE
   vitSet-HostsEntry -IPAddress 'x.x.x.x' -HostName 'myHost.local' -Description "myserver's IP address"
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
    # IP Address to resolve too
    [Parameter(Mandatory=$true)]
    [string]$IPAddress,

    # Host name to lookup
    [Parameter(Mandatory=$true)]
    [string]$HostName,

    # Description of entry to the hosts file
    [Parameter(Mandatory=$false)]
    [string]$Description = 'Added by script',

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
    $ErrorFileName = "vitSet-HostsEntry.txt"
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

# REGION Add the entry to the hosts file
try {
    # Make sure Carbon module is installed
    $CarbonInstallCheck = Get-Module -ListAvailable -Name Carbon
    if (!($CarbonInstallCheck)) {
        $Return.Error_Count++
        $Return.Carbon_Test = "Unable to find Carbon module"
    }
    # Create the hosts file entry if needed
    $Return.Hosts_Entry = Set-HostsEntry -IPAddress $IPAddress -HostName $HostName -Description $Description
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Set_HostsEntry_Error = $myException 
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