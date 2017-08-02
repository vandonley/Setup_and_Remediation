<#
.Synopsis
   Checks for the existence of a scheduled job to make sure the monitoring agent
   is running and set to automatic.
.DESCRIPTION
   The script is to be uploaded to your dashboard account as a user script.
   It can run both as a script check and as a scheduled task. Expects to be run
   with pccCheck-RMMFolders.ps1
   
.EXAMPLE
   Install-ApplicationsFromMAXfocus notepadplusplus adobereader
.EXAMPLE
   Install-ApplicationsFromMAXfocus dropbox googlechrome
.EXAMPLE
   Install-ApplicationsFromMAXfocus google-chrome-x64
.OUTPUTS
   Scheduled task, Powershell script to be run by task, and errors.
.EMAIL
   vand@parseccomputer.com
.VERSION
   1.0
#>


# We are only binding -logfile for MaxRM script runner
param (	
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
$StagingPath = $env:RMMFolder + "\Staging"
$ErrorFile = $ErrorPath + "\pccScedule-CheckAgent.txt"

# Files and options for the scheduled job
$TaskNm = "Parsec - Check MSP Agent"
$TaskCommand = "powershell -NoLogo -Noninteractive -ExecutionPolicy bypass -File " + $TaskFile
$TaskRunAs = "System"
$TaskFile = $StagingPath + "\pccCheck-RMMAgent.ps1"
$TaskPS1 = @"
<#
--------------------------
Check Advanced Monitoring Agent service and try to fix if needed.
Expects to be used with pccCheck-RMMFolders.ps1
Parsec Computer Corp.
Created:  Van Donley - 03/25/2017
Last Updated:  Van Donely - 07/28/2017
--------------------------
#>
    # Set the RMM agent to check for
	$RMMAgent = "Advanced Monitoring Agent"
	
	#Set the event source name set by pccCheck-RMMFolders
	$EventSourceName = "Parsec"
	
	# Create hashtable for output
	[hashtable]$Output = @{}
	
	# Start an error counter so MaxRM will correctly error on failure
	[int]$ErrorCount = '0'
  
    # Get a list of all services that might be the RMM agent

    $Agents = Get-Service | Where-Object { $_.Name -like ($RMMAgent + "*") }
    
    # Loop through each of the services

    foreach ( $Agent in $Agents )
    {
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
`"@
        $ErrorCount = $ErrorCount + 1
		
        # Write a warning to the event log to track restart and failure if unsuccessfull

        Write-EventLog -LogName Application -Source $EventSourceName -EventId 1 -EntryType Warning -Message $Output.AgentOutput
        
		if ( $AgentResult.Status -ne 'Running' -or $AgentResult.StartType -ne 'Automatic' ) {
			Write-EventLog -LogName Application -Source $EventSourceName -EventId 1 -EntryType Error -Message $Output
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
"@

# Check if the Powershell file exists and create it if needed
if (! (Test-Path -Path $TaskFile)) {
    $Return.TaskPS1 = "File missing, creating script file"
    $TaskPS1 | Out-File -FilePath $TaskFile -Force
    $ErrorCount = $ErrorCount + 1
}
else {
    $Return.TaskPS1 = "Script file found, updating"
    $TaskPS1 | Out-File -FilePath $TaskFile -Force
}

# Create and reset settings of Scheduled task
$Return.TaskCreate = . schtasks.exe /Create /tn $TaskNm /tr $TaskCommand /sc Hourly /mo 4 /ru $TaskRunAs /rl Highest /f

# Make sure the job has been created and state is ready
$Return.TaskQuery = . schtasks.exe /query /tn $TaskNm | Out-String
if ($Return.TaskQuery -like "*Ready*") {
    $Return.TaskStatus = "Task found and is ready"
}
else {
    $Return.TaskStatus = "Task not found or disabled"
    $ErrorCount = $ErrorCount + 1
}
# Check for errors and create an error file for the dashboard if needed

if ($ErrorCount -eq '0') {
    Write-Host @"
Success
RMM service check job found

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
        [string]$ErrorString = "Check Failure"
        [string]$ErrMessage = ( $Return | Format-List | Out-String )
        $Error.Add($ErrorString)
        Write-Error -Exception $ErrorString -ErrorId 1001 -Message $ErrMessage
        Exit 1001
}