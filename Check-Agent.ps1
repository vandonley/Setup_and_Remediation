Function Check-Agent
{
    $Agents = Get-Service | where {$_.Name -like "Advanced Monitoring Agent*"}
    
    foreach ($Agent in $Agents) {

    if ($Agent.Status -ne "Running") {
        $Agent | Start-Service
        $Output = Write-Host "Starting $Agent.DisplayName service now"
            "-----------------------------"
            "Service is $Agent.Status"
        return $Output
    }
    if ($Agent.Status -eq "Running"){
        $Output = Write-Host "$Agent.DisplayName is running"
        return $Output
    }
    else {
         $Output = Write-Host "Troubleshoot $Agent.DisplayName"
            "-----------------------------"
            "Status:  $Agent.Status"
            "Start Type:  $Agent.StartType"
        return $Output
        }
    }
}

Check-Agent