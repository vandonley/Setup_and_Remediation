<#
.Synopsis
   Creates a local user that is a member of the built-in administrators group.
   Must supply password either with -Passwd or as the first argument.
.DESCRIPTION
   The script is to be uploaded to your dashboard account as a user script.
   It can run both as a script check and as a scheduled task. Expects to be run
   with vitCheck-RMMDefaults.ps1
   
.EXAMPLE
   vitInstall-AdminUser myPasswordHere
.EXAMPLE
   vitInstall-AdminUser -UserNm VITAdmin -Passwd myPasswordHere -FullNm 'VisionIT' -UserComment 'Support Account'
.OUTPUTS
   Error file if needed and local user account
.EMAIL
   vdonley@visionms.net
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

    # Username (Default is VITAdmin)
    [Parameter()]
    [string]
    $UserNm = 'VITAdmin',

    # Full Name (Default is VisionIT)
    [Parameter()]
    [string]
    $FullNm = 'VisionIT',

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

# Force output to keep RMM from timing out
Write-Host ' '

# Create hashtable for output. Make it stay in order and start an error counter to create an alert if needed. Divide by 1 to force integer
$Return = [ordered]@{}
$Return.Error_Count = 0

# REGION Reporting setup
try {
    # Information about the script for reporting.
    $ErrorFileName = "vitInstall-AdminUser.txt"
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

# REGION Make sure script can run and find everything it needs
try {
    # Make sure Carbon module is installed
    $CarbonInstallCheck = Get-Module -ListAvailable -Name Carbon
    if (!($CarbonInstallCheck)) {
        $Return.Error_Count++
        $Return.Carbon_Test = "Unable to find Carbon module"
    }
    if ($Return.Error_Count -ge '1') {
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
    else {
        # Return success
        $Return.Carbon_Test = 'Carbon v{0}' -f $CarbonInstallCheck.Version
        # Import Carbon module
        Import-Module -Name 'Carbon'
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Prerequisit_Catch = $myException 
    $Return.Error_Count++ 
}
# END REGION

# REGION Create the user and add it to the local administrators group
try {
    $Cred = New-Credential -UserName $UserNm -Password $Passwd
    $Return.Install_User_Output = Install-User -Credential $Cred -Description $UserComment -FullName $FullNm -PassThru
    $AdminGroup = Resolve-Identity -SID 'S-1-5-32-544'
    Add-GroupMember -Name $AdminGroup.FullName -Member "$env:COMPUTERNAME\$UserNm"
    Enable-LocalUser -Name $UserNm
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.User_Catch = $myException 
    $Return.Error_Count++ 
}
# END REGION

# REGION Check to see if the user exists and is a member of the local administrators group
try {
    $Return.User_Exists = Test-User -Username $UserNm
    if ($Return.User_Exists -eq $false) {
        $Return.Error_Count++  
    }
    $Return.User_In_Group = Test-GroupMember -GroupName $AdminGroup.FullName -Member "$env:COMPUTERNAME\$UserNm"
    if ($Return.User_In_Group -eq $false) {
        $Return.Error_Count++ 
    }

    $UserEnabled = Get-LocalUser -Name $UserNm
    $Return.User_Enabled = $UserEnabled | Format-List | Out-String
    if ($UserEnabled.Enabled -eq $false) {
        $Return.Error_Count++
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.User_Test_Catch = $myException 
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