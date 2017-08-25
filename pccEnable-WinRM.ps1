<#
--------------------------
Check if Remote Management is enabled.
Parsec Computer Corp.
Created:  Van Donley
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
[int]$ErrorCount = 0



# Get execution policy from the registry, the agent lies....
# If execution policy is 'Restricted', set it to RemoteSigned
try {
    $RegistryPaths = @(
        "Registry::HKLM\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell",
        "Registry::HKLM\SOFTWARE\WOW6432Node\Microsoft\PowerShell\1\ShellIds\ScriptedDiagnostics"
    )
    foreach ($item in $RegistryPaths) {
        if ((Test-Path $item) -eq $true) {
            $CurrentPolicy = (get-itemproperty -Path $item -Name ExecutionPolicy).ExecutionPolicy
            $Return.ExecutionPolicy_Begin = $CurrentPolicy
                if ($CurrentPolicy -eq 'Restricted') {
                    Set-ItemProperty -Path $item -Name ExecutionPolicy -Value 'RemoteSigned' -Force
                    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
                    $Return.ExecutionPolicy_End = "Attempting to set to RemoteSigned"
                }
        }
    }
}
catch {
    $Return.Registry_Catch = $_.Exception | Format-List | Out-String
    $ErrorCount = $ErrorCount + 1
}

# Build Enable-WinRM command line - under version 3 does not all skip network check
if ($PSVersionTable.PSVersion.Major -ge 3) {
    $EnableRemoting = Enable-PSRemoting -Force -SkipNetworkProfileCheck
}
else {
    $EnableRemoting = Enable-PSRemoting -Force
}

# Checks

$WinRMService = Test-PsRemoting
$Return.PSExePolicy = (get-itemproperty -Path $RegistryPaths[0] -Name ExecutionPolicy).ExecutionPolicy

# Check if the WinRM service is running. If not, run Enable-PSRemoting.

    try { 
        if ( $WinRMService -eq $false )
            {
            $Return.RMServiceStatusBegin = (Get-Service winrm).Status
            $Return.EnableWinRMOut = $EnableRemoting
            $Return.RMServiceStatus = (Get-Service winrm).Status
            }

            else { $Return.RMServiceStatus = (Get-Service winrm).Status }
        }

    catch [EXCEPTION] { 
        $Return.WinRM_Catch = $_.Exception | Format-List | Out-String
        $ErrorCount = $ErrorCount + 1
    }

# Return results from function. Exit with error if not in correct state.

    if ( $Return.RMServiceStatus -ne 'Running' -or $Return.PSExePolicy -eq 'Restricted' -or $ErrorCount -gt '0' )
        {
        $Return.Error_Count = $ErrorCount    
        $Error.Clear()
        [string]$ErrorString = "Check Failure"
        [string]$ErrMessage = ( $Return | Format-List | Out-String )
        $Error.Add($ErrorString)
        Write-Error -Exception $ErrorString -ErrorId 1001 -Message $ErrMessage
        Exit 1001
        }
        
Write-Output @"
  
Script Success!
Troubleshooting info below
_______________________________
 
"@
$Return | Format-List | Out-String
Exit 0