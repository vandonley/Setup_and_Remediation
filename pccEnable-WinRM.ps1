<#
--------------------------
Check if Remote Management is enabled.
Parsec Computer Corp.
Created:  Van Donley - 04/18/2017
Last Updated:  Van Donely - 04/21/2017
--------------------------
#>

# Better way to test remoting
# http://www.leeholmes.com/blog/2009/11/20/testing-for-powershell-remoting-test-psremoting/

function Test-PsRemoting 
{ 
    param( 
        [Parameter(Mandatory=$false, Position=1)] 
        [string]$computername = 'localhost'
    ) 
    
    try 
    { 
        $errorActionPreference = "Stop" 
        $result = Invoke-Command -ComputerName $computername { 1 } 
    } 
    catch 
    { 
        Write-Verbose $_ 
        return $false 
    } 
    
    ## I've never seen this happen, but if you want to be 
    ## thorough.... 
    if($result -ne 1) 
    { 
        Write-Verbose "Remoting to $computerName returned an unexpected result." 
        return $false 
    } 
    
    $true    
}

# Hashtable for return from function

[HASHTABLE]$Return = @{}

# Checks

$WinRMService = Test-PsRemoting
$PSExePolicy = Get-ExecutionPolicy

# Check if the WinRM service is running. If not, run Enable-PSRemoting.

    try { 
        if ( $WinRMService -eq $false )
            {
            $Return.RMServiceStatusBegin = (Get-Service winrm).Status
            $Return.EnableWinRMOut = Enable-PSRemoting -Force -SkipNetworkProfileCheck `
                -ErrorAction Continue -WarningAction Continue
            $Return.RMServiceStatus = (Get-Service winrm).Status
            }

            else { $Return.RMServiceStatus = (Get-Service winrm).Status }
        }

    catch [EXCEPTION] { $_.Exception | Format-List -Force }

# Check to see if the Powershell execution policy is set to unrestricted and change if needed.

    try {
        if ( $PSExePolicy -ne 'RemoteSigned' )
            {
            $Return.PSExePolicyBegin = $PSExePolicy
            $Return.PSExePolicyOut = Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force `
                -ErrorAction Continue -WarningAction Continue
            $Return.PSExePolicy = Get-ExecutionPolicy
            }

            else { $Return.PSExePolicy = $PSExePolicy }
        }

    catch [EXCEPTION] { $_.Exception | Format-List -Force }

# Return results from function. Exit with error if not in correct state.

    if ( $Return.RMServiceStatus -ne 'Running' -or $Return.PSExePolicy -ne 'RemoteSigned' )
        {
        $Error.Clear()
        [string]$ErrorString = "Check Failure"
        [string]$ErrMessage = ( $Return | Format-List | Out-String )
        $Error.Add($ErrorString)
        Write-Error -Exception $ErrorString -ErrorId 1001 -Message $ErrMessage
        Exit 1001
        }
        
Return ( $Return | Format-List )
