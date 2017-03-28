﻿function Remediate-VM
{
$cpu = @(Get-WmiObject -Class Win32_processor -ea stop)
                    $c_socket = $cpu.count
                    $c_core = $cpu[0].NumberOfCores * $c_socket 
                    $c_logical = $cpu[0].NumberOfLogicalProcessors * $c_socket

$PhyCores = $c_logical

$PhyMemory = Get-WmiObject -Class Win32_PhysicalMemory | Measure-Object -Property capacity -Sum `
    | Foreach {"{0:N2}" -f ([Math]::round(($_.Sum / 1MB),2))}

$MinMemory = ($PhyMemory/4)*1MB
$MaxMemory = ($PhyMemory/2)*1MB

$RunningVM = Get-VM | Where-Object {$_.State -eq "Running"}

$RunningVM | Stop-VM -Force

Get-VM | Set-VM -ProcessorCount $PhyCores -DynamicMemory -MemoryMaximumBytes $MaxMemory `
    -MemoryStartupBytes $MinMemory

$RunningVM | Start-VM
}

Remediate-VM