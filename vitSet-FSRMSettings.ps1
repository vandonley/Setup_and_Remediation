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
   with pccCheck-RMMFolders.ps1
.EXAMPLE
   pccChange-ComputerID MyNewName
.EXAMPLE
   pccChange-ComputerID MyNewName 'My New Description'
.EXAMPLE
   pccChange-ComputerID MyNewName 'My New Description' domain MyDomain\MyUser MyPassword
.EXAMPLE
   pccChange-ComputerID -Name MyNewName -Description 'My New Description' -Scope domain -User MyDomain\MyUser -Pass MyPassword
.OUTPUTS
   Registry settings and error file.
.EMAIL
   vand@parseccomputer.com
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

# Get Windows Version
$OSCheck = (Get-WmiObject Win32_OperatingSystem).Caption
