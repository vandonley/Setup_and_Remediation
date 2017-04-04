$TaskNm = "Parsec - Check MSP Agent"

$Action = New-ScheduledTaskAction -Execute 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' `
    -Argument "-NonInteractive -NoLogo -NoProfile -ExecutionPolicy Bypass -Command 'C:\Parsec_MSP\Check-Agent.ps1'"

$Interval = New-TimeSpan -Hours 4
$Trigger = New-ScheduledTaskTrigger -Once -At 3am -RandomDelay "00:30" -RepetitionDuration ([TimeSpan]::MaxValue) -RepetitionInterval $Interval

$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

$Task = Register-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal -TaskName $TaskNm -Description "Starts Check-Agent script" -Force

