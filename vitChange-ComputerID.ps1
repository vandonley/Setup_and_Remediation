<#
.Synopsis
   Changes computer name and/or description. Name and description can be passed
   the first and second parameters or as -Name and -Description. If the computer
   is joined to a domain, a username and password must be supplied that is
   allowed to rename the computer. Use -Scope 'domain' for computers joined to
   a domain. This script will reboot the computer if needed.
.DESCRIPTION
   The script is to be uploaded to your dashboard account as a user script.
   It can run both as a script check and as a scheduled task. Expects to be run
   with vitCheck-RMMDefaults.ps1
.EXAMPLE
   vitChange-ComputerID MyNewName
.EXAMPLE
   vitChange-ComputerID MyNewName 'My New Description'
.EXAMPLE
   vitChange-ComputerID MyNewName 'My New Description' domain MyDomain\MyUser MyPassword
.EXAMPLE
   vitChange-ComputerID -Name MyNewName -Description 'My New Description' -Scope domain -User MyDomain\MyUser -Pass MyPassword
.OUTPUTS
   Registry settings and error file.
.EMAIL
   vdonley@visionit.net
.VERSION
   1.0
#>


# We are only binding -logfile for MaxRM script runner.
param (	
    # Name of the computer
	[Parameter(Position=1,Mandatory=$false)]
    [string]$Name = 'myName',
    
    # Description of the computer
    [Parameter(Position=2,Mandatory=$false)]
    [string]$Description = 'myDescription',

    # Description of the computer
    [Parameter(Position=3,Mandatory=$false)]
    [string]$Scope = 'local',

    # Username for domain computer name change
    [Parameter(Position=4,Mandatory=$false)]
    [string]$User = 'myUser',

    # Username for domain computer name change
    [Parameter(Position=5,Mandatory=$false)]
    [string]$Pass = 'myPass',

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
$ErrorFile = $ErrorPath + "\vitChange-ComputerID.txt"

# Make sure there is either a name or description change
if ($Name -eq 'myName' -and $Description -eq 'myDescription') {
    $Return.Input_Error = 'Input error, you must supply a new computer name or description'
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

# Make sure scope is either local or domain
if (!($Scope -eq 'local' -or $Scope -eq 'domain')) {
    $Return.Input_Error = 'Input error, -Scope must be either local or domain'
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

# Make sure a username and password is supplied if the computer is domain joined
if ($Scope -eq 'domain'-and ($User -eq 'myUser' -or $Pass -eq 'myPass')) {
    $Return.Input_Error = 'Input error, domain computers require a username and password'
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

# Change the computer description
try {
    if ($Description -ne 'myDescription') {
    Set-RegistryKeyValue -Path 'hklm:\SYSTEM\ControlSet001\services\LanmanServer\Parameters' -Name 'srvcomment' -String $Description
    $Return.Desciption = "New description:  $Description"
    }
}
catch {
    $Return.Description_Catch = $_.Exception | Format-List | Out-String
    $ErrorCount = $ErrorCount + 1
}

# Change the computer name and reboot
try {
    if ($Scope -eq 'local' -and $Name -ne 'myName') {
        Write-Host "Attempting to rename computer to $Name"
        $Return.Rename_Computer = Rename-Computer -NewName $Name -Restart -Force
    }
    elseif ($Scope -eq 'domain') {
        $Cred = New-Credential -UserName $User -Password $Pass
        Write-Host "Attempting to rename computer to $Name"
        $Return.Rename_Computer = Rename-Computer -NewName $Name -DomainCredential $Cred -Restart -Force
    }
    else {
        Write-Host "Keeping computer name:  $env:COMPUTERNAME"
    }
}
catch {
    $Return.Rename_Computer_Catch = $_.Exception | Format-List | Out-String
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