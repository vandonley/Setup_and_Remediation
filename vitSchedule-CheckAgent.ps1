<#
.Synopsis
   Checks for the existence of a scheduled job to make sure the monitoring agent
   is running and set to automatic.
.DESCRIPTION
   The script is to be uploaded to your dashboard account as a user script.
   It can run both as a script check and as a scheduled task. Expects to be run
   with cotCheck-RMMDefaults.ps1
   
.EXAMPLE
   .\cotShedule-CheckAgent.ps1
.OUTPUTS
   Scheduled task, Powershell script to be run by task, and errors.
.EMAIL
   van.donley@cityoftoppenish.us
.VERSION
   1.0
#>

# We are only binding -logfile. Leave the rest unbound.
param (	
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
    $ErrorFileName = "cotSchedule-CheckAgent.txt"
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
    # Check if the staging folder exists and use %TEMP% if it doesn't.
    $myStagingPath = $env:RMMFolder
    if ($myStagingPath) {
        $myStagingPath = $myStagingPath + "\Staging"
        $Return.Staging_Path = $myStagingPath
    }
    else {
        $Return.Staging_Path = $env:TEMP
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.File_Information_Catch = $myException 
    $Return.Error_Count++ 
}
# END REGION

# REGION Remove Vision tasks if present
try {
    # Make sure Carbon module is installed
    $CarbonInstallCheck = Get-Module -ListAvailable -Name Carbon
    if (!($CarbonInstallCheck)) {
        $Return.Error_Count++
        $Return.Carbon_Test = "Unable to find Carbon module"
    }
    else {
        $Return.Carbon_Test = "Carbon module found, importing"
        Import-Module -Name 'Carbon'
    }
    # Brute force removing the tasks
    Uninstall-CScheduledTask -Name "VisionIT - Check MSP Agent"
    Uninstall-CScheduledTask -Name "VIT-Complete_Install"
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Vision_Tasks_Catch = $myException 
    $Return.Error_Count++
}
# END REGION

# REGION Schedule the task.
try {
    # Files and options for the scheduled job
    $TaskNm = "CoT - Check RMM Agent"
    $TaskFile = $Return.Staging_Path + "\cotCheck-RMMAgent.ps1"
    $TaskCommand = "powershell.exe -ExecutionPolicy bypass -NonInteractive $TaskFile"
    $TaskRunAs = "System"
    $TaskPS1 = @'
<#
--------------------------
Check RMM monitoring services and try to fix if needed.
Expects to be used with cotCheck-RMMDefaults.ps1
van.donley@cityoftoppenish.us
Created:  Van Donley - 03/25/2017
Last Updated:  Van Donely - 05/04/2023
--------------------------
#>
# Get the current status of all services
$myServices = Get-Service | Sort-Object -Property 'DisplayName'

# Array of services to check for
$RMMServices = @(
    'Advanced Monitoring Agent',
    'Backup Service Controller',
    'BitDefender Endpoint',
    'Ecosystem Agent',
    'File Cache Service Agent',
    'PME Agent',
    'Sentinel Agent',
    'SentinelOne',
    'SolarWinds MSP',
    'Take Control Agent (N-able)'
)

#Set the event source name set by cotCheck-RMMDefaults
$EventSourceName = "CoT"

# Create hashtable for output
$Output = [ordered]@{}

# Start an error counter so MaxRM will correctly error on failure
[int]$ErrorCount = '0'

# Check that the services are running and fix if needed
foreach ($myService in $myServices) {
    # Make the properties easier to deal with  
    $myName = $myService.DisplayName
    $myStatus = $myService.Status
    $myStartType = $myService.StartType
    
    # Check each RMM service name
    foreach ($RMMService in $RMMServices) {
        # Check the service display name agains the RMM service name
        if ($myName -like "*$RMMService*") {
            # If the service is running and set to automatic there is nothing to do
            if ($myStatus -eq 'Running' -and $myStartType -eq 'Automatic') {
                $Output.$myName = 'Service running and set to start automatically'
            }
            # If the service is not running then make sure it is set to automatic start and try to start it
            else {
                $ErrorCount++
                # Start reporting on the service
                $Output.$myName = "Error - $myName is $myStatus with $MyStartType start`n"
                # Set to start automatically if needed
                if ($myStartType -ne 'Automatic') {
                    $myResult = $myService | Set-Service -StartupType 'Automatic' | Out-String
                    $Output.$myName += "`nSetting service to Automatic`nOutput:  $myResult `n"
                }
                # Try to start the service if needed
                if ($myStatus -ne 'Running') {
                    $myResult = $myService | Start-Service | Out-String
                    $Output.$myName += "`nAttemping to start service`nOutput:  $myResult `n"
                }
                # Get the service status after trying to fix
                $myResult = $myService | Get-Service
                $myResultStatus = $myResult.Status
                $myResultStartType = $myResult.StartType
                $Output.$myName += "`nService is now $myResultStatus and set to $myResultStartType"
                # Write a warning if the service is working now
                if ($myResultStatus -eq 'Running' -and $myResultStartType -eq 'Automatic') {
                    Write-EventLog -LogName 'Application' -Source $EventSourceName -EventId '1' -EntryType 'Warning' -Message $Output.$myName
                }
                # Write an error if the service is not working now
                else {
                    Write-EventLog -LogName 'Application' -Source $EventSourceName -EventId '1' -EntryType 'Error' -Message $Output.$myName
                }
            }
        }          
    }
}
    # Check for errors and output

if ($ErrorCount -eq 0) {
    $Output | Format-List -Force
    Exit 0
}
else {
    $Output | Format-List -Force
    Exit 1
}
'@

    # Check if the Powershell file exists and create it if needed
    if (! (Test-Path -Path $TaskFile)) {
        $Return.TaskP_PS1 = "File missing, creating script file"
        $TaskPS1 | Out-File -FilePath $TaskFile -Force
        $Return.Error_Count++
    }
    else {
        $Return.Task_PS1 = "Script file found, updating"
        $TaskPS1 | Out-File -FilePath $TaskFile -Force
    }

    # Create and reset settings of Scheduled task
    $Return.Task_Create = . schtasks.exe /Create /tn $TaskNm /tr $TaskCommand /sc Hourly /mo 4 /ru $TaskRunAs /rl Highest /f

    # Make sure the job has been created and state is ready
    $Return.Task_Query = . schtasks.exe /query /tn $TaskNm | Out-String
    if (($Return.Task_Query -like "*Ready*") -or ($Return.Task_Query -like "*Running*")) {
        $Return.Task_Status = "Task found and is ready"
    }
    else {
        $Return.Task_Status = "Task not found or disabled"
        $Return.Error_Count++
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Task_Creation_Catch = $myException 
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
