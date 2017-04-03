<#
--------------------------
Check Advanced Monitoring Agent service and try to fix if needed.
Parsec Computer Corp.
Created:  Van Donley - 03/25/2017
Last Updated:  Van Donely - 04/03/2017
--------------------------
#>

Function Check-Agent
{
    # Check to see if the Parsec source exists in the event log and create it if needed

    if( [System.Diagnostics.EventLog]::SourceExists( "Parsec" ) -ne $True )
        { [System.Diagnostics.EventLog]::CreateEventSource( "Parsec", "Application" ) }
    
    # Get a list of all services that might be the Advanced Monitoring Agent

    $Agents = Get-Service | Where-Object { $_.Name -like "Advanced Monitoring Agent*" }
    
    # Loop through each of the services

    foreach ( $Agent in $Agents )
    {
 
        # If the service is running there is nothing to do

        if ( $Agent.Status -eq "Running" )
            {
             $Output = $Agent.DisplayName + " is running"
             return $Output
            }

        # If the service is not running then make sure it is set to automatic start and try to start it

        if ( $Agent.Status -ne "Running" )
            {
             $Output = "Attempting to start " + $Agent.DisplayName + " service now"
             $Agent.DisplayName + " is " + $Agent.Status
             $Agent.Displayname + " is " + $Agent.StartType
             "-----------------------------"
        
             if ( $Agent.StartType -ne 'Automatic' ) { $Agent | Set-Service -StartupType Automatic }

            # Write a warning to the event log to track restart

            Write-EventLog -LogName Application -Source "Parsec" -EventId 1 -EntryType Warning -Message "Attempting to fix Advanced Monitoring Agent"
            
            # Try to start the service

            $Agent | Start-Service

            return $Output
            }

        # Try to catch any other error and write an event to the log for tracking
        
        else
            {
            $Output = "Troubleshoot Advanced Monitoring Agent, service check failed"
            Write-EventLog -LogName Application -Source "Parsec" -EventId 1 -EntryType Error -Message "Advanced Monitoring Agent service check has failed"
            return $Output
            }
    
    }
}

Check-Agent