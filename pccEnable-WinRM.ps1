<#
--------------------------
Check if Remote Management is enabled.
Parsec Computer Corp.
Created:  Van Donley - 04/18/2017
Last Updated:  Van Donely - 04/21/2017
--------------------------
#>

function pccEnable-WinRM
{

# Hashtable for return from function

[HASHTABLE]$Return = @{}

# Checks

$WinRMService = Get-Service winrm
$PSExePolicy = Get-ExecutionPolicy

# Check if the WinRM service is running. If not, run Enable-PSRemoting.

    try { 
        if ( $WinRMService.Status -ne 'Running' )
            {
            $Return.RMServiceStatusBegin = $WinRMService.Status
            $Return.EnableWinRMOut = Enable-PSRemoting -Force -SkipNetworkProfileCheck `
                -ErrorAction Continue -WarningAction Continue
            $Return.RMServiceStatus = (Get-Service winrm).Status
            }

            else { $Return.RMServiceStatus = $WinRMService.Status }
        }

    catch [EXCEPTION] { $_.Exception | Format-List -Force }

# Check to see if the Powershell execution policy is set to unrestricted and change if needed.

    try {
        if ( $PSExePolicy -ne 'Unrestricted' )
            {
            $Return.PSExePolicyBegin = $PSExePolicy
            $Return.PSExePolicyOut = Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force `
                -ErrorAction Continue -WarningAction Continue
            $Return.PSExePolicy = Get-ExecutionPolicy
            }

            else { $Return.PSExePolicy = $PSExePolicy }
        }

    catch [EXCEPTION] { $_.Exception | Format-List -Force }

# Return results from function. Exit with error if not in correct state.

    if ( $Return.RMServiceStatus -ne 'Running' -or $Return.PSExePolicy -ne 'Unrestricted' )
        {
        $Error.Clear()
        [string]$ErrorString = "Check Failure"
        [string]$ErrMessage = ( $Return | Format-List | Out-String )
        $Error.Add($ErrorString)
        Write-Error -Exception $ErrorString -ErrorId 1001 -Message $ErrMessage
        Exit 1001
        }
        
Return ( $Return | Format-List )

}

pccEnable-WinRM
