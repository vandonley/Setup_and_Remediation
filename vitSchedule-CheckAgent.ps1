<#
.Synopsis
   Checks for the existence of a scheduled job to make sure the monitoring agent
   is running and set to automatic.
.DESCRIPTION
   The script is to be uploaded to your dashboard account as a user script.
   It can run both as a script check and as a scheduled task. Expects to be run
   with vitCheck-RMMDefaults.ps1
   
.EXAMPLE
   .\vitShedule-CheckAgent.ps1
.OUTPUTS
   Scheduled task, Powershell script to be run by task, and errors.
.EMAIL
   vdonley@visionit.net
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
    $ErrorFileName = "vitSchedule-CheckAgent.txt"
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

# REGION Schedule the task.
try {
    # Files and options for the scheduled job
    $TaskNm = "VisionIT - Check MSP Agent"
    $TaskFile = $Return.Staging_Path + "\vitCheck-RMMAgent.ps1"
    $TaskCommand = "powershell.exe -ExecutionPolicy bypass -NonInteractive $TaskFile"
    $TaskRunAs = "System"
    $TaskPS1 = @'
<#
--------------------------
Check Advanced Monitoring Agent service and try to fix if needed.
Expects to be used with vitCheck-RMMDefaults.ps1
VisionIT
Created:  Van Donley - 03/25/2017
Last Updated:  Van Donely - 11/01/2017
--------------------------
#>
    # Set the RMM agent to check for
	$RMMAgent = "Advanced Monitoring Agent"
	
	#Set the event source name set by vitCheck-RMMDefaults
	$EventSourceName = "VisionIT"
	
	# Create hashtable for output
	$Output = [ordered]@{}
	
	# Start an error counter so MaxRM will correctly error on failure
	[int]$ErrorCount = '0'
  
    # Get the RMM Agent status
    $Agent = Get-Service -Name $RMMAgent
    
    $AgentOutput = $Agent.name
    $AgentName = $Agent.DisplayName
    $AgentStatus = $Agent.Status
    $AgentStartType = $Agent.StartType
    
    # If the service is running there is nothing to do

    if ( $Agent.Status -eq "Running" -and $Agent.StartType -eq "Automatic" )
        {
            $Output.$AgentOutput = "$AgentName is running and set to start automatically"
        }

    # If the service is not running then make sure it is set to automatic start and try to start it

        else {
        if ( $Agent.StartType -ne 'Automatic' ) { $Agent | Set-Service -StartupType Automatic }
        if ( $Agent.Status -ne 'Running' ) { $Agent | Start-Service }

        $AgentResult = $Agent | Get-Service
        $AgentResultStart = $AgentResult.StartType
        $AgentResultRunning = $AgentResult.Status
        
        $Output.AgentOutput = @"
-----------------------------------------------------
$AgentName is $AgentStatus
$AgentName is $AgentStartType

Attempting to repair $AgentName service now.

$AgentName is $AgentResultStart
$Agentname is $AgentResultRunning
-----------------------------------------------------
"@
    $ErrorCount = $ErrorCount + 1
    
    # Write a warning to the event log to track restart and failure if unsuccessfull     
    if ( $AgentResult.Status -ne 'Running' -or $AgentResult.StartType -ne 'Automatic' ) {
        Write-EventLog -LogName Application -Source $EventSourceName -EventId 1 -EntryType Error -Message $Output.AgentOutput
    }
    else {
        Write-EventLog -LogName Application -Source $EventSourceName -EventId 1 -EntryType Warning -Message $Output.AgentOutput
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