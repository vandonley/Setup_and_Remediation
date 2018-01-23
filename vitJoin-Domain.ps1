<#
.Synopsis
   Join a computer to a domain and reboot. Must supply a domain name, user name, and password.
   This can be entered as Domain domain\user password or -Domain -User -Pass.
.DESCRIPTION
   The script is to be uploaded to your dashboard account as a user script.
   It can run both as a script check and as a scheduled task. Expects to be run
   with vitCheck-RMMDefaults.ps1
.EXAMPLE
   vitJoin-Domain myDomain myDomain\myUser myPassword
.EXAMPLE
   vitJoin-Domain -Domain myDomain -User myDomain\myUser -Pass myPassword
.EXAMPLE
   vitJoin-Domain -Domain 'myDomain.local' -User myDomain\myUser -Pass myPassword
.OUTPUTS
   Computer account and error file.
.EMAIL
   vdonley@visionms.net
.VERSION
   1.0
#>


# We are only binding -logfile for MaxRM script runner.
param (	
    # Name of the domain
	[Parameter(Position=1,Mandatory=$true)]
    [string]$Domain,
    
    # Domain user allowed to join a computer to the domain
    [Parameter(Position=2,Mandatory=$true)]
    [string]$User,

    # Domain user's password
    [Parameter(Position=3,Mandatory=$true)]
    [string]$Pass,

    # Make sure -logfile is NOT positional
	[Parameter(Mandatory=$false)]
	[string]$logfile
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

# List of files and folders to check for and create they don't exist
$ErrorPath = $env:RMMErrorFolder
$ErrorFile = $ErrorPath + "\vitJoin-DomainID.txt"

# Import Carbon module
try {
    Import-Module -Name Carbon -Force 
    $CarbonImport = Get-Module -Name Carbon
    if (! $CarbonImport) {
        $Return.Carbon_Import = "Carbon module import failed"
        $ErrorCount = $ErrorCount + 1
    }
    else {
        $Return.Carbon_Import = $CarbonImport | Select-Object Name,Version
    }
    }
    catch {
        $Return.Carbon_Import_Catch = $_.Exception | Format-List | Out-String
        $ErrorCount = $ErrorCount + 1
    }

# Join the computer to the domain and reboot
try {
        $Cred = New-Credential -UserName $User -Password $Pass
        Write-Host "Attempting to join computer to $Domain"
        $Return.Add_Computer = Add-Computer -DomainName $Domain -Credential $Cred -Restart -Force
}
catch {
    $Return.Add_Computer_Catch = $_.Exception | Format-List | Out-String
    $ErrorCount = $ErrorCount + 1
}

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