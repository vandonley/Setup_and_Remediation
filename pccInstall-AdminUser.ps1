<#
.Synopsis
   Creates a local user that is a member of the built-in administrators group.
   Must supply password either with -Passwd or as the first argument.
.DESCRIPTION
   The script is to be uploaded to your dashboard account as a user script.
   It can run both as a script check and as a scheduled task. Expects to be run
   with pccCheck-RMMFolders.ps1
   
.EXAMPLE
   pccInstall-AdminUser myPasswordHere
.EXAMPLE
   pccInstall-AdminUser -UserNm Parsec -Passwd myPasswordHere -FullNm 'Parsec Computer Corp. -UserComment 'Support Account'
.OUTPUTS
   Error file if needed and local user account
.EMAIL
   vand@parseccomputer.com
.VERSION
   1.0
#>


<#
 -Passwd can be passed as the first argument and must be supplied.
 Others optional but must accept -logfile from MaxRM.
#>  
param (	
    # User password as plain text
    [Parameter(Mandatory=$True,Position=1)]
    [string]
    $Passwd,

    # Username (Default is Parsec)
    [Parameter()]
    [string]
    $UserNm = 'Parsec',

    # Full Name (Default is Parsec Computer Corp.)
    [Parameter()]
    [string]
    $FullNm = 'Parsec Computer Corp.',

    # User Comment (Default is Support Account)
    [Parameter()]
    [string]
    $UserComment = 'Support Account',

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

# Where to write the error file
$ErrorFile = $env:RMMErrorFolder + "\pccInstall-AdminUser.txt"

# Import Carbon module
try {
    Import-Module -Name Carbon -Force 
    $CarbonImport = Get-Module -Name Carbon
    if (! $CarbonImport) {
        $Return.CarbonImport = "Carbon module import failed"
        $ErrorCount = $ErrorCount + 1
    }
    else {
        $Return.CarbonImport = $CarbonImport | Select-Object Name,Version
    }
    }
    catch {
        $Return.CarbonImport_Catch = $_.Exception | Format-List | Out-String
        $ErrorCount = $ErrorCount + 1
    }

# Create the user and add it to the local administrators group
try {
    $Cred = New-Credential -UserName $UserNm -Password $Passwd
    $Return.InstallUser = Install-User -Credential $Cred -Description $UserComment -FullName $FullNm -PassThru
    $AdminGroup = Resolve-Identity -SID 'S-1-5-32-544'
    Add-GroupMember -Name $AdminGroup.FullName -Member "$env:COMPUTERNAME\$UserNm"
    Enable-LocalUser -Name $UserNm
}
catch {
        $Return.User_Catch = $_.Exception | Format-List | Out-String
        $ErrorCount = $ErrorCount + 1
}

# Check to see if the user exists and is a member of the local administrators group
try {
    $Return.UserExists = Test-User -Username $UserNm
    if ($Return.UserExists -eq $false) {
        $ErrorCount = $ErrorCount + 1  
    }

    $Return.UserInGroup = Test-GroupMember -GroupName $AdminGroup.FullName -Member "$env:COMPUTERNAME\$UserNm"
    if ($Return.UserInGroup -eq $false) {
        $ErrorCount = $ErrorCount + 1 
    }

    $UserEnabled = Get-LocalUser -Name $UserNm
    $Return.UserEnabled = $UserEnabled | Format-List | Out-String
    if ($UserEnabled.Enabled -eq $false) {
        $ErrorCount = $ErrorCount + 1
    }
}
catch {
        $Return.Test_Catch = $_.Exception | Format-List | Out-String
        $ErrorCount = $ErrorCount + 1
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