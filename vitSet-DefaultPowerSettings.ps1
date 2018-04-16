<#
.Synopsis
   Set Windows power plan to a standard. Use -ComputerType with
   "Desktop", "Laptop", or "Server" to set manually. Script will attempt to determine 
   computer type with WMI if not specified. The plan version can be set as "2008" for
   Windows 7 or Server 2008, "2012" for Windows 8 and Server 2012, or "2016" for
   Windows 10 and Server 2016. Set sleep and hibernate time in seconds or don't specify
   the default for that configuration
.DESCRIPTION
   The script is to be uploaded to your dashboard account as a user script.
   It can run both as a script check and as a scheduled task. Expects to be run
   with vitCheck-RMMFolders.ps1
.EXAMPLE
   vitSet-DefaultPowerSettings
.EXAMPLE
   vitSet-DefaultPowerSettings Desktop 2016
.EXAMPLE
   vitSet-DefaultPowerSettings -ComputerType Desktop -PlanVersion 2016 -ACSleep 0 -DCSleep 0 -ACHibernate 0 -DCHibernate 0
.OUTPUTS
   Error file if needed and sets power options
.EMAIL
   vdonley@visionms.net
.VERSION
   1.0
#>


<#
 -ComputerType can be passed as the first argument.
 -Power plan version as the second argument.
 -Must accept -logfile from MaxRM.
#>  
param (	
    # Desktop, Laptop, or Server
    [Parameter(Mandatory=$false,Position=1)]
    [ValidateSet("Not Detected","Desktop","Laptop","Server")]
    [string]
    $ComputerType = "Not Detected",

    # Powerplan Version - 2008, 2012, or 2016
    [Parameter(Mandatory=$false,Position=2)]
    [ValidateSet("Not Detected","2008","2012","2016")]
    [string]
    $PlanVersion = "Not Detected",

    # AC Sleep Timer , -1 will cause default setting for the detected type
    [Parameter(Mandatory=$false)]
    [ValidateRange(-1,86400)]
    [int]
    $ACSleep = "-1",

    # DC Sleep Timer, -1 will cause default setting for the detected type
    [Parameter(Mandatory=$false)]
    [ValidateRange(-1,86400)]
    [int]
    $DCSleep = "-1",

    # AC Hibernate Timer, -1 will cause default setting for the detected type
    [Parameter(Mandatory=$false)]
    [ValidateRange(-1,86400)]
    [int]
    $ACHibernate = "-1",

    # DC Hibernate Timer, -1 will cause default setting for the detected type
    [Parameter(Mandatory=$false)]
    [ValidateRange(-1,86400)]
    [int]
    $DCHibernate = "-1",

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
    $ErrorFileName = "vitSet-DefaultPowerSettings.txt"
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
# REGION Computer type and version
# Use WMI to determine if the computer is a server, desktop, or laptop/tablet if not correctly specified on the command line
# Use version variable to determine power plan version if not specified on the command line
try {
    # Get chassis type
    if ($ComputerType -eq "Not Detected") {
        # Check if Server is in the caption to catch server OSes
        $Return.WMI_OS_Result = Get-WmiObject -Class Win32_OperatingSystem -Property "Caption"
        if ($Return.WMI_OS_Result.Caption -like "*Server*") {
            $ComputerType = "Server"
        }
        else {
            # Laptops and tablets will always be PCSystemType 2
            $Return.WMI_Chassis_Result = Get-WmiObject -Class Win32_ComputerSystem -Property "PCSystemType"
            if ($Return.WMI_Chassis_Result.PCSystemType -ne '2') {
            $ComputerType = 'Desktop'
            }
            else {
            $ComputerType = 'Laptop'
            }
        }
    }
    # Get the OS version to get the right power plan settings
    if ($PlanVersion -eq "Not Detected") {
        $Return.OS_Version = [System.Environment]::OSVersion.Version
        if ($Return.OS_Version.Major -eq "10") {
            $PlanVersion = "2016"
        }
        elseif (($Return.OS_Version.Major -eq "6") -and ($Return.OS_Version.Minor -gt "1")) {
            $PlanVersion = "2012"
        }
        elseif (($Return.OS_Version.Major -eq "6") -and ($Return.OS_Version.Minor -eq "1")) {
            $PlanVersion = "2008"
        }
        else {
            # Exit if we cannot determine the correct power plan
            $Return.Error_Count = $Return.Error_Count++
            $Return.Plan_Version = $PlanVersion
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
    
    } 
}
catch {
        $myException = $_.Exception | Format-List | Out-String
        $Return.ComputerType_Catch = $myException
        $Return.Error_Count++ 
}
finally {
    # Get the final chassis type in the output
    $Return.Computer_Type = $ComputerType
    # Get the final version in the output
    $Return.Plan_Version = $PlanVersion  
}
# END REGION
# REGION Set Sleep and Hibernate times
try {
    # -1 means the setting has not been defined on the command line
    # AC Sleep Timer in seconds
    if ($ACSleep -eq "-1") {
        # Desktop AC sleep off
        if ($ComputerType -eq "Desktop") {
            $ACSleep = "0"
        }
        # Laptop AC sleep off
        elseif ($ComputerType -eq "Laptop") {
            $ACSleep = "0"
        }
        # Server AC sleep off
        else {
            $ACSleep = "0"
        }
    }
    # DC Sleep timer in seconds
    if ($DCSleep -eq "-1") {
        # Desktop DC sleep off
        if ($ComputerType -eq "Desktop") {
            $DCSleep = "0"
        }
        # Laptop DC sleep 1 hour
        elseif ($ComputerType -eq "Laptop") {
            $DCSleep = "3600"
        }
        # Server DC sleep off
        else {
            $DCSleep = "0"
        }
    }
    # AC Hibernate timer in seconds
    if ($ACHibernate -eq "-1") {
        # Desktop AC Hibernate off
        if ($ComputerType -eq "Desktop") {
            $ACHibernate = "0"
        }
        # Laptop AC Hibernate off 
        elseif ($ComputerType -eq "Laptop") {
            $ACHibernate = "0"
        }
        # Server DC sleep off
        else {
            $ACHibernate = "0"
        }
    }
    # DC Hibernate timer in seconds
    if ($DCHibernate -eq "-1") {
        # Desktop DC Hibernate off
        if ($ComputerType -eq "Desktop") {
            $DCHibernate = "0"
        }
        # Laptop DC Hibernate 2 hours 
        elseif ($ComputerType -eq "Laptop") {
            $ACHibernate = "7200"
        }
        # Server DC sleep off
        else {
            $DCHibernate = "0"
        }
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Timers_Catch = $myException
    $Return.Error_Count++
}
finally {
    # Capture the timers for output
    $Return.AC_Sleep_Time = $ACSleep
    $Return.DC_Sleep_Time = $DCSleep
    $Return.AC_Hibernate_Time = $ACHibernate
    $Return.DC_Hibernate_Time = $DCHibernate
}
# END REGION
# REGION Set the powerplan using powercfg.exe
try {
    # Enable or disable hibernate based off the timers
    if (($ACHibernate -eq "0") -and ($DCHibernate -eq "0")) {
        $Return.Hybernate_Off = . powercfg -h off
    }
    else {
        $Return.Hybernate_On = . powercfg -h on
    }
    # Get the current list of power plans
    $myPowerPlans = . powercfg -list
    # Create the power plan if it does not exist
    if (!($myPowerPlan -like "*381b4222-f694-41f0-9685-ff5bb260*")) {
        # Alert if the plan does not exist
        $Return.Error_Count++
        if ($ComputerType -eq "Desktop") {
            # Copy High Performance plan and rename
            $Return.Create_Plan = . powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 5e3a46e6-ce58-4430-89ca-eb155d5daaaa
            $Return.Rename_Plan = . powercfg -changename 5e3a46e6-ce58-4430-89ca-eb155d5daaaa "Vision PC Power Management Plan"
        }
        if ($ComputerType -eq "Laptop") {
            # Copy Balanced plan and rename
            $Return.Create_Plan = . powercfg -duplicatescheme 381b4222-f694-41f0-9685-ff5bb260df2e 5e3a46e6-ce58-4430-89ca-eb155d5dbbbb
            $Return.Rename_Plan = . powercfg -changename 5e3a46e6-ce58-4430-89ca-eb155d5dbbbb "Vision Laptop Power Management Plan"
        }
        else {
            # Copy High Performance plan and rename
            $Return.Create_Plan = . powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 5e3a46e6-ce58-4430-89ca-eb155d5dcccc
            $Return.Rename_Plan = . powercfg -changename 5e3a46e6-ce58-4430-89ca-eb155d5dcccc "Vision Server Power Management Plan"
        }
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.PowerCFG_Catch = $myException
    $Return.Error_Count++
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
        [string]$ErrorString = "Script Failure"
        [string]$ErrMessage = ( $Return | Format-List | Out-String )
        $Error.Add($ErrorString)
        Write-Error -Exception $ErrorString -ErrorId 1001 -Message $ErrMessage
        Exit 1001
}