<#
--------------------------
Check if Remote Management is enabled.
Vision IT
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

# Create ordered list for output
$Return = New-Object System.Collections.Specialized.OrderedDictionary

# Start error counter
$Return.Add("Error_Count","0")

# Get execution policy from the registry, the agent lies....
# If execution policy is 'Restricted', set it to RemoteSigned
try {
    [hashtable]$RegistryPaths = @{
        "Registry" = "Registry::HKLM\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell";
        "WoW64_Registry" = "Registry::HKLM\SOFTWARE\WOW6432Node\Microsoft\PowerShell\1\ShellIds\ScriptedDiagnostics"
    }
    foreach ($item in $RegistryPaths.Keys) {
        $myName = ${item}
        $myValue = $($RegistryPaths.Item($item))
        $myReturnName = $myName + "_Execution_Policy"
        $myReturnNameEnd =  $myReturnName + "_End"
        if ((Test-Path $myValue) -eq $true) {
            $CurrentPolicy = (get-itemproperty -Path $myValue -Name ExecutionPolicy).ExecutionPolicy
            $Return.Add("$myReturnName","$CurrentPolicy")
                if ($CurrentPolicy -eq 'Restricted') {
                    $Return.Add("$myReturnNameEnd","Attempting to set to RemoteSigned")
                    $Return.Error_Count = $Return.Error_Count + 1
                    Set-ItemProperty -Path $myValue -Name ExecutionPolicy -Value 'RemoteSigned' -Force
                    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
                }
        }
    }
}
catch {
    $myException = $_.Exception | Format-List | Out-String
    $Return.Add("Registry_Catch","$myException")
    $Return.Error_Count = $Return.Error_Count + 1
}

# Build Enable-WinRM command line - under version 3 does not allow skip network check
if ($PSVersionTable.PSVersion.Major -ge 3) {
    $EnableRemoting = Enable-PSRemoting -Force -SkipNetworkProfileCheck
}
else {
    $EnableRemoting = Enable-PSRemoting -Force
}

# Check WinRM Remoting status
$WinRMService = Test-PsRemoting

# Check if the WinRM service is running. If not, run Enable-PSRemoting.
    try { 
        if ( $WinRMService -eq $false )
            {
            $RMServiceStatusBegin = (Get-Service winrm).Status
            $EnableWinRMOut = $EnableRemoting | Out-String
            $RMServiceStatus = (Get-Service winrm).Status
            $Return.Add("RM_Service_Status_Begin","$RMServiceStatusBegin")
            $Return.Add("Enable_WinRM_Output","$EnableWinRMOut")
            $Return.Add("RM_Service_Status","$RMServiceStatus")
            }

            else {
                $RMServiceStatus = (Get-Service winrm).Status
                $Return.Add("RM_Service_Status","$RMServiceStatus")
            }
        }

    catch [EXCEPTION] { 
        $myException = $_.Exception | Format-List | Out-String
        $Return.Add("RM_Service_Status_Catch","$myException")
        $Return.Error_Count = $Return.Error_Count + 1
    }

# Return results from function. Exit with error if not in correct state.

    if ( $Return.RM_Service_Status -ne 'Running' -or $Return.Execution_Policy -eq 'Restricted' -or $Return.Error_Count -gt '0' )
        {
        Write-Output @"

Check Failure!
Troubleshooting info below
_______________________________
       
"@
          $Return | Format-List | Out-String
          Exit 1001
        }
        else {
            Write-Output @"
            
Check Success!
Troubleshooting info below
_______________________________
      
"@
          $Return | Format-List | Out-String
          Exit 0
        }
