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
"@
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