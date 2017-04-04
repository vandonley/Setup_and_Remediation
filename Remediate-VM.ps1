<#
--------------------------
Reconfigure VM's to improve performance.
Parsec Computer Corp.
Created:  Van Donley - 03/25/2017
Last Updated:  Van Donely - 04/03/2017
--------------------------
#>

function Remediate-VM
{
# Create hashtable for return from function

[hashtable]$Return = @{}

# Get core count of host server and set $PhyCores to that number

$cpu = @(Get-WmiObject -Class Win32_processor -ea stop)
                    $c_socket = $cpu.count
                    $c_core = $cpu[0].NumberOfCores * $c_socket 
                    $c_logical = $cpu[0].NumberOfLogicalProcessors * $c_socket

$PhyCores = $c_logical
$Return.PhysicalCores = $PhyCores

# Get a total of the physical memory of the host in megabytes

$PhyMemory = Get-WmiObject -Class Win32_PhysicalMemory | Measure-Object -Property capacity -Sum `
    | Foreach {"{0:N2}" -f ([Math]::round(($_.Sum / 1MB),2))}
$Return.PhysicalMemory = $PhyMemory

# Get a list of the VM's currently running on the host 

$RunningVM = Get-VM | Where-Object {$_.State -eq "Running"}
$Return.StartingVMRunning = $RunningVM

$VMCount = $RunningVM.Count

# Get the ammount of memory to assign to each VM

$MinTest = $VMCount*2
    if( $MinTest -le '8' ) { $MinDiv = $VMCount + 2 }
    else { $MinDiv = $MinTest }

$MaxTest = ([system.math]::Round(($VMCount/2), 0))
    if($MaxTest -le '1') { $MaxDiv = .75 }
    else { $MaxDiv = $MaxTest }

$MinMemory = ([system.math]::Round((($PhyMemory/$MinDiv)/2), 0))*2MB
$MaxMemory = ([system.math]::Round((($PhyMemory/$MaxDiv)/2), 0))*2MB
$Return.StartingMemory = $MinMemory
$Return.MaximumMemory = $MaxMemory

# Shut down all running VM's

$RunningVM | Stop-VM -Force

# Set all VM's to the new settings if they are running or not

Get-VM | Set-VM -ProcessorCount $PhyCores -DynamicMemory -MemoryMaximumBytes $MaxMemory `
    -MemoryStartupBytes $MinMemory

# Re-start the VM's that were running

$RunningVM | Start-VM

# Check which VM's are running when we are all done

$EndRunningVM = Get-VM | Where-Object {$_.State -eq "Running"}
$Return.EndingVMRunning = $EndRunningVM

# Output everything we have been keeping track of

return $Return

}

Remediate-VM