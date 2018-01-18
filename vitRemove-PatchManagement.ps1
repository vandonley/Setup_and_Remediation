# Remove files created by bad path in agent install
$myProcess = Get-Process | Where-Object { ($_.Path -like '*advanced.tmp') -or ($_.Path -like '*program.tmp') } | Select-Object Name,Path
if ($myProcess) {
    foreach ($item in $myProcess) {
        $ProcName = $item.Name
        $ProcPath = $item.Path
        Write-Host "Attempting to stop $ProcName"
        Stop-Process -Name $ProcName -Force
        Write-Host "Attempting to delete $ProcPath"
        Remove-Item -Path $ProcPath -Force
    }
}
else {
    Write-Host "Advanced.tmp and Program.tmp files not found, continuing"
}

#Does Languard 10 or 11 service exist?
if (Get-Service "gfi_lanss10_attservice" -ErrorAction SilentlyContinue)
{
    $languard10service = Get-Service -Name "gfi_lanss10_attservice"
    #Stop Languard 10 service
    if ($languard10service.Status -eq "Running") {
        Stop-Service $languard10service
        Write-Host "gfi_lanss10_attservice was stopped"
    }
} elseif (Get-Service "gfi_lanss10_attservice" -ErrorAction SilentlyContinue)
{
    $languard11service = Get-Service -Name "gfi_lanss11_attservice"
    if ($languard11service.Status -eq "Running") {
        Stop-Service $languard11service
        Write-Host "gfi_lanss11_attservice was stopped"
    }
}

#Remove Languard 11.4
$i = (Start-Process -FilePath "msiexec.exe" -ArgumentList "/X{A0707C59-4B32-48B8-94ED-73BB68E1C569} /quiet /norestart" -Wait -Passthru).ExitCode
if ($i -eq 0) {
    Write-Host "GFI Languard 11.4 has been successfully removed"
} elseIf ($i -eq 3010) {
    Write-Host "Reboot is required to complete removal of GFI Languard 11.4"
} elseIf ($i -eq 1605) {
    Write-Host "GFI Languard 11.4 is not installed"
} else {
    Write-Host "GFI Languard 11.4 removal failed: Error $i"
}

#Remove Languard 11.0
$i = (Start-Process -FilePath "msiexec.exe" -ArgumentList "/X{5D56359C-92E3-4306-A48D-7F95B8D0D48D} /quiet /norestart" -Wait -Passthru).ExitCode
if ($i -eq 0) {
    Write-Host "GFI Languard 11.0 has been successfully removed"
} elseIf ($i -eq 3010) {
    Write-Host "Reboot is required to complete removal of GFI Languard 11.0"
} elseIf ($i -eq 1605) {
    Write-Host "GFI Languard 11.0 is not installed"
} else {
    Write-Host "GFI Languard 11.0 removal failed: Error $i"
}

#Remove older versions of Languard
$i = (Start-Process -FilePath "msiexec.exe" -ArgumentList "/X{54233984-5466-45CE-BB95-682627A85D1D} /quiet /norestart" -Wait -Passthru).ExitCode
if ($i -eq 0) {
    Write-Host "Older Languard has been successfully removed"
} elseIf ($i -eq 3010) {
    Write-Host "Reboot is required to complete removal of older Languard"
} elseIf ($i -eq 1605) {
    Write-Host "Older Languard versions are not installed"
} else {
    Write-Host "Older Languard removal failed: Error $i"
}

#Delete GFI directory within %PROGRAMDATA% if it exists
if (Test-Path $env:ALLUSERSPROFILE\GFI) {
    Remove-Item -path $env:ALLUSERSPROFILE\GFI\ -Recurse
    Write-Host "$env:ALLUSERSPROFILE\GFI\ deleted"
}

#Is this a 32 or 64-bit OS?
if ([System.IntPtr]::Size -eq 4) {
    $b = 32
    Write-Host "32-bit OS" 
} else { 
    $b = 64
    Write-Host "64-bit OS" 
}

#Is this CN and/or AMA?
if ($b = 64) {

    #Does this device have ControlNow installed?
    if (Test-Path ${env:ProgramFiles(x86)}/LogicNow) {
        $cnln = $true
        Write-Host "ControlNow is installed under ${env:ProgramFiles(x86)}/LogicNow"
    } elseif (Test-Path "${env:ProgramFiles(x86)}/GFI Software") {
        $cngfi = $true
        Write-Host "ControlNow is installed under ${env:ProgramFiles(x86)}/GFI Software"
    }

    #Does this device have Advanced Monitoring Agent installed?
    if (Test-Path "${env:ProgramFiles(x86)}/Advanced Monitoring Agent") {
        $ama = $true
        Write-Host "Advanced Monitoring Agent is installed"
    }

    #Clear out patchman location
    if ($ama) {
        Remove-Item -path "${env:ProgramFiles(x86)}/Advanced Monitoring Agent/patchman"
        Write-Host "${env:ProgramFiles}\Advanced Monitoring Agent\patchman\ deleted"
    }
    if ($cngfi) {
        Remove-Item -path "${env:ProgramFiles(x86)}/GFI Software/GFI Cloud Agent/patchman"
        Write-Host "${env:ProgramFiles}\GFI Software\GFI Cloud Agent\patchman\ deleted"
    } 
    if ($cnln) {
        Remove-Item -path "${env:ProgramFiles(x86)}/LogicNow/ControlNow Agent/patchman"
        Write-Host "${env:ProgramFiles}\LogicNow\ControlNow Agent\patchman\ deleted"
    }

} elseif ($b = 32) {

    #Does this device have ControlNow installed?
    if (Test-Path ${env:ProgramFiles}/LogicNow) {
        $cnln = $true
        Write-Host "ControlNow is installed under ${env:ProgramFiles}/LogicNow"
    } elseif (Test-Path "${env:ProgramFiles}/GFI Software") {
        $cngfi = $true
        Write-Host "ControlNow is installed under ${env:ProgramFiles}/GFI Software"
    }

    #Does this device have Advanced Monitoring Agent installed?
    if (Test-Path "${env:ProgramFiles}/Advanced Monitoring Agent") {
        $ama = $true
        Write-Host "Advanced Monitoring Agent is installed"
    }

    #Clear out patchman location
    if ($ama) {
        Remove-Item -path "${env:ProgramFiles}/Advanced Monitoring Agent/patchman"
        Remove-Item -path "${env:ProgramFiles}/Advanced Monitoring Agent/LastPatchScan.xml"
        Write-Host "${env:ProgramFiles}\Advanced Monitoring Agent\patchman\ deleted"
    }
    if ($cngfi) {
        Remove-Item -path "${env:ProgramFiles}/GFI Software/ControlNow Agent/patchman"
        Remove-Item -path "${env:ProgramFiles}/GFI Software/ControlNow Agent/LastPatchScan.xml"
        Write-Host "${env:ProgramFiles}\GFI Software\ControlNow Agent\patchman\ deleted"
    }
    if ($cnln) {
        Remove-Item -path "${env:ProgramFiles}/LogicNow/ControlNow Agent/patchman"
        Remove-Item -path "${env:ProgramFiles}/LogicNow/ControlNow Agent/LastPatchScan.xml"
        Write-Host "${env:ProgramFiles}\LogicNow\ControlNow Agent\patchman\ deleted"
    }

}

#Delete Reg Keys for 32-bit AND 64-bit
Write-Host "--------------------"
Write-Host "Registry Key Removal"
Write-Host "--------------------"

if (Test-Path hklm:System\CurrentControlSet\Services\gfi_lanss11_attservice) {
    Remove-Item -path hklm:System\CurrentControlSet\Services\gfi_lanss11_attservice -Recurse
    Write-Host "hklm:System\CurrentControlSet\Services\gfi_lanss11_attservice deleted"
} else {
    Write-Host "hklm:System\CurrentControlSet\Services\gfi_lanss11_attservice does not exist"
}

if (Test-Path hklm:SOFTWARE\Classes\Installer\Products\95C7070A23B48B8449DE37BB861E5C96) {
    Remove-Item -path hklm:SOFTWARE\Classes\Installer\Products\95C7070A23B48B8449DE37BB861E5C96 -Recurse
    Write-Host "hklm:SOFTWARE\Classes\Installer\Products\95C7070A23B48B8449DE37BB861E5C96 deleted"
} else {
    Write-Host "hklm:SOFTWARE\Classes\Installer\Products\95C7070A23B48B8449DE37BB861E5C96 does not exist"
}

if (Test-Path hklm:SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\95C7070A23B48B8449DE37BB861E5C96) {
    Remove-Item -path hklm:SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\95C7070A23B48B8449DE37BB861E5C96 -Recurse
    Write-Host "hklm:SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\95C7070A23B48B8449DE37BB861E5C96 deleted"
} else {
    Write-Host "hklm:SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\95C7070A23B48B8449DE37BB861E5C96 does not exist"
}


#Delete Reg Keys for 32-bit
if (Test-Path 'hklm:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{A0707C59-4B32-48B8-94ED-73BB68E1C569}') {
    Remove-Item -path 'hklm:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{A0707C59-4B32-48B8-94ED-73BB68E1C569}' -Recurse
    Write-Host "hklm:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{A0707C59-4B32-48B8-94ED-73BB68E1C569} deleted"
}
 else {
    Write-Host "hklm:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{A0707C59-4B32-48B8-94ED-73BB68E1C569} does not exist"
}

if (Test-Path hklm:SOFTWARE\GFI\LNSS11) {
    Remove-Item -path hklm:SOFTWARE\GFI\LNSS11 -Recurse
    Write-Host "hklm:SOFTWARE\GFI\LNSS11 deleted"
} else {
    Write-Host "hklm:SOFTWARE\GFI\LNSS11 does not exist"
}

#Delete Reg Keys for 64-bit
if (Test-Path "hklm:SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{A0707C59-4B32-48B8-94ED-73BB68E1C569}") {
    Remove-Item -path "hklm:SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{A0707C59-4B32-48B8-94ED-73BB68E1C569}" -Recurse
    Write-Host "hklm:SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{A0707C59-4B32-48B8-94ED-73BB68E1C569} deleted"
} else {
    Write-Host "hklm:SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{A0707C59-4B32-48B8-94ED-73BB68E1C569} does not exist"
}

if (Test-Path hklm:SOFTWARE\Wow6432Node\GFI\LNSS11) {
    Remove-Item -path hklm:SOFTWARE\Wow6432Node\GFI\LNSS11 -Recurse
    Write-Host "hklm:SOFTWARE\Wow6432Node\GFI\LNSS11 deleted"
} else {
    Write-Host "hklm:SOFTWARE\Wow6432Node\GFI\LNSS11 does not exist"
}
#Script created by Dion Jones
#LogicNow Technical Support
#02/21/2016