@echo off
:: Attempt to clean-up Vipre install using Solar Winds RMM.
:: 
:: Schedule workstation reboot after running.
::
:: Script forked from https://gist.github.com/radiumsoup/bff16c36731cb91758f40b7ff45e822b
::
:: Van Donly
:: VisionIT
:: 11/20/2017
::
:: In reverse order for easier adding from the Vipre support site (see link in header)
set "GUIDarr[19]=2B43966F-3C72-4D34-AB5A-2D35F5320C4C" REM Vipre 9.3.6000 Standard
set "GUIDarr[18]=0C92648E-DC79-4A1E-A63A-FA7492E8CDA7" REM Vipre 9.3.6000 Premium
set "GUIDarr[17]=2645C2A8-4700-46F9-B2F7-A0E826DBCF91" REM Vipre 9.3.6000 Endpoint Security
set "GUIDarr[16]=56CA3334-8B72-48D1-81E7-3EF5243E45D5" REM Vipre 7.5.5841 Premium
set "GUIDarr[15]=8B2C9073-C948-4033-93EF-E7F781E43E35" REM Vipre 7.5.5839 Standard
set "GUIDarr[14]=1BDEA9D9-7988-4BC2-8DE3-2AE4B6E65969" REM Vipre 7.5.5839 Premium
set "GUIDarr[13]=82FB46C5-494D-41A8-81C4-E2CC094169BE" REM Vipre 7.0.5725 Standard
set "GUIDarr[12]=BAA1CAE8-8E7B-4000-AC56-38AC8BB7506A" REM Vipre 7.0.5725 Premium
set "GUIDarr[11]=CC1CEA69-B7AF-47EE-AB64-68B7A1E2F3CF" REM Vipre 7.0.5711 Standard
set "GUIDarr[10]=D685DD76-77A3-4661-B9F0-7DAE2D651260" REM Vipre 7.0.5711 Premium
set "GUIDarr[9]=B0783CD0-27C6-49B4-9905-AC3A6437F5A8" REM Vipre 7.0.5685 Standard
set "GUIDarr[8]=9CE81981-648E-4C9D-AC2F-6B129071903F" REM Vipre 7.0.5685 Premium
set "GUIDarr[7]=628B718E-65C3-47C8-B4C8-A86CA1B42F69" REM Vipre 7.0.5666 Standard
set "GUIDarr[6]=6A68DC82-9FFD-41EB-91BA-86A4CECF29C0" REM Vipre 7.0.5666 Premium
set "GUIDarr[5]=092D4B8A-D0BA-4D2D-A690-78357FEBBC38" REM Vipre 6.2.5537 Standard
set "GUIDarr[4]=3DF87105-29CA-4F06-9ACC-1745AFE49555" REM Vipre 6.2.5537 Premium
set "GUIDarr[3]=39A086B2-07D6-430B-AE5E-B8AC1CC843A7" REM Vipre 6.2.5530 Standard
set "GUIDarr[2]=E10809C0-E65F-4493-A31B-3F86DB6E9E2A" REM Vipre 6.2.5530 Premium
set "GUIDarr[1]=9D544611-F437-4153-913E-91CE036583CC" REM Vipre 6.0.5481 and 6.0.5482 Standard and Premium
set "GUIDarr[0]=39A086B2-07D6-430B-AE5E-B8AC1CC843A7" REM Vipre all earlier versions
set "ProductFeatureArr[0]=0C90801EF56E39443AB1F368BDE6E9A2" REM unknown version
set "ProductFeatureArr[1]=116445D9734F351419E319EC305638CC" REM unknown version
set "ProductFeatureArr[2]=18918EC9E846D9C4CAF2B621091709F3" REM unknown version
set "ProductFeatureArr[3]=2B680A936D70B034EAE58BCAC18C347A" REM unknown version
set "ProductFeatureArr[4]=3709C2B8849C330439FE7E7F184EE353" REM unknown version
set "ProductFeatureArr[5]=4333AC6527B81D84187EE35F42E3545D" REM unknown version
set "ProductFeatureArr[6]=50178FD3AC9260F4A9CC7154FA4E5955" REM unknown version
set "ProductFeatureArr[7]=5C64BF28D4948A14184C2ECC901496EB" REM unknown version
set "ProductFeatureArr[8]=67DD586D3A7716649B0FD7EAD2562106" REM unknown version
set "ProductFeatureArr[9]=8A2C546200749F642B7F0A8E62BDFC19" REM unknown version
set "ProductFeatureArr[10]=8EAC1AABB7E80004CA6583CAB87B05A6" REM unknown version
set "ProductFeatureArr[11]=96AEC1CCFA7BEE74BA46867B1A2E3FFC" REM unknown version
set "ProductFeatureArr[12]=9D9AEDB188972CB4D83EA24E6B6E9596" REM unknown version
set "ProductFeatureArr[13]=C21346408A6123D4299DD1D723899DC1" REM unknown version
set "ProductFeatureArr[14]=C928BABD4AA3D694D99624F210BD8691" REM unknown version
set "ProductFeatureArr[15]=E84629C097CDE1A46AA3AF47298EDC7A" REM unknown version
set "ProductFeatureArr[16]=F66934B227C343D4BAA5D2535F23C0C4" REM unknown version
echo =========================================
echo Step 1: Running MsiExec /x on known GUIDs
echo.
set "x=0"
:msiexecloop
if defined GUIDarr[%x%] (
    start /wait MsiExec.exe /x !GUIDarr[%x%]! /qn /l*v "%temp%\VIPRE_MsiUninstall.log" REMOVE=ALL
    set /a "x+=1"
    GOTO :msiexecloop
)
echo Done.
echo ======================================
echo Step 2: Stopping and deleting services
set "servicearr[0]=gfiark"
set "servicearr[1]=SBAMSvc"
set "servicearr[2]=gfiark"
set "servicearr[3]=SBAPIFS"
set "servicearr[4]=SBEMI"
set "servicearr[5]=SbFw"
set "servicearr[6]=SBHIPS"
set "servicearr[7]=SBPIMSVC"
set "servicearr[8]=SBRE"
set "x=0"
:serviceloop
if defined servicearr[%x%] (
    start /wait SC stop !servicearr[%x%]!
    start /wait SC delete !servicearr[%x%]!
    set /a "x+=1"
    GOTO :serviceloop
)
echo Done.
echo ===============================================
echo Step 3: Removing registry entries if they exist
set "x=0"
:regGUIDloop
if defined GUIDarr[%x%] (
    set "regGUIDarr[%x%]=HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\{!GUIDarr[%x%]!}"
    set "regGUIDarr[%x%]=HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{!GUIDarr[%x%]!}"
    set /a "x+=1"
    GOTO :regGUIDloop
)
:: The following is a one-off registry entry that is a GUID but Vipre support does not include the GUID in their list
set "regGUIDarr[%x%]=HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\{C1D1FC57-3EB9-4B21-BCA3-F1C927508200}"
set /a "x+=1"
set "regGUIDarr[%x%]=HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{C1D1FC57-3EB9-4B21-BCA3-F1C927508200}"
REM now the list of registry entries that are not GUIDs
set "regNonGUIDarr[0]=HKLM\Software\Sunbelt Software\Sunbelt Enterprise Agent"
set "regNonGUIDarr[1]=HKLM\Software\Wow6432Node\Sunbelt Software\Sunbelt Enterprise Agent"
set "regNonGUIDarr[2]=HKLM\Software\GFI Software\GFI Business Agent"
set "regNonGUIDarr[3]=HKLM\Software\Wow6432Node\GFI Software\GFI Business Agent"
set "regNonGUIDarr[4]=HKLM\Software\GFI Software\Deployment"
set "regNonGUIDarr[5]=HKLM\Software\Wow6432Node\GFI Software\Deployment"
set "regNonGUIDarr[6]=HKLM\Software\SBAMsvc"
set "regNonGUIDarr[7]=HKLM\Software\Wow6432Node\SBAMsvc"
set "regNonGUIDarr[8]=HKLM\Software\SBAMSvcVolatile"
set "regNonGUIDarr[9]=HKLM\Software\Wow6432Node\SBAMSvcVolatile"
set "regNonGUIDarr[10]=HKLM\Software\Vipre Business Agent"
set "regNonGUIDarr[11]=HKLM\Software\Wow6432Node\Vipre Business Agent"
set "regNonGUIDarr[12]=HKLM\Software\GFI\LNSS10"
set "regNonGUIDarr[13]=HKLM\SoftwareWow6432Node\GFI\LNSS10"
REM put them all together in regarr
set "x=0" REM for big loop, regarr
set "n=0" REM for iterating the little loops regGUIDarr and regNonGUIDarr
:regInsertGUIDloop
if defined regGUIDarr[%n%] (
  set "regarr[%x%]=!regGUIDarr[%n%]!"
  set /a "x+=1"
  set /a "n+=1"
  GOTO :regInsertGUIDloop
)
set "n=0" REM for iterating the little loops regGUIDarr and regNonGUIDarr
:regInsertNonGUIDloop
if defined regNonGUIDarr[%n%] (
  set "regarr[%x%]=!regNonGUIDarr[%n%]!"
  set /a "x+=1"
  set /a "n+=1"
  GOTO :regInsertNonGUIDloop
)
set "n=0"
:regInsertProductFeatureLoop
if defined ProductFeatureArr[%n%] (
  :: Calling x+=1 multiple times in this loop only iterates once INSIDE although it counts them all once the loop exits. hack is x1 x2 x3 etc
  set "regarr[%x%]=HKLM\Software\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\!ProductFeatureArr[%n%]!"
  call set /a "x1=x+1"
  set "regarr[%x1%]=HKLM\Software\Classes\Installer\Features\!ProductFeatureArr[%n%]!"
  set /a "x2=x+2"
  set "regarr[%x2%]=HKLM\Software\Classes\Installer\Products\!ProductFeatureArr[%n%]!"
  set /a "x3=x+3"
  set "regarr[%x3%]=HKCR\Installer\Products\!ProductFeatureArr[%n%]!"
  set /a "x4=x+4"
  set "regarr[%x4%]=HKCR\Installer\Features\!ProductFeatureArr[%n%]!"
  set /a "x=x+5"
  set /a "n+=1"
  GOTO :regInsertProductFeatureLoop
)
REM now delete the registry keys
set "x=0"
:regDeleteLoop
if defined regarr[%x%] (
  GOTO :regDoDelete
)
GOTO :afterRegDeleteLoop
:regDoDelete
REM echo "Deleting key !regarr[%x%]!"
  reg query !regarr[%x%]! REM 2>NUL
    if not ErrorLevel 1 (
      reg delete !regarr[%x%]! /f 2>NUL
  )
  set /a "x+=1"
PING localhost -n 1 -w 100 >NUL REM - required pause here to allow SET to finish - otherwise it often causes a race with reg query errors
  :: Return to loop (this label should only be called from in the loop)
GOTO :regDeleteLoop
:afterRegDeleteLoop
echo Done.
echo =======================================
echo Step 4: Unregistering SBAMScanShell.dll
set "InstallLocation[0]=C:\Program Files\VIPRE Business Agent"
set "InstallLocation[1]=C:\Program Files (x86)\VIPRE Business Agent"
set "InstallLocation[2]=C:\Program Files (x86)\VIPRE Business Agent\x64"
set "InstallLocation[3]=C:\Program Files\GFI Software\GFIAgent"
set "InstallLocation[4]=C:\Program Files (x86)\GFI Software\GFIAgent"
set "InstallLocation[5]=C:\Program Files\Sunbelt Software\SBEAgent"
set "InstallLocation[6]=C:\Program Files (x86)\Sunbelt Software\SBEAgent"
set "x=0"
:unregisterSBAMloop
if defined InstallLocation[%x%] (
  CD "!InstallLocation[%x%]!" 2>NUL
  PING localhost -n 1 -w 100 >NUL
  RegSvr32 /u SBAMScanShellExt.dll /s >NUL
  set /a "x+=1"
  PING localhost -n 1 -w 100 >NUL
  GOTO :unregisterSBAMloop
)
echo Done.
echo ================================================
echo Step 5: Removing folders and files if they exist
set "FolderLocation[0]=C:\Program Files\VIPRE Business Agent\"
set "FolderLocation[1]=C:\Program Files\GFI Software\Deployment\"
set "FolderLocation[2]=C:\Program Files\GFI Software\GFIAgent\"
set "FolderLocation[3]=C:\Program Files\GFI Software\LanGuard 10\"
set "FolderLocation[4]=C:\Program Files\Sunbelt Software\Deployment\"
set "FolderLocation[5]=C:\Program Files\Sunbelt Software\SBEAgent\"
set "FolderLocation[6]=C:\Program Files (x86)\VIPRE Business Agent\"
set "FolderLocation[7]=C:\Program Files (x86)\GFI Software\Deployment\"
set "FolderLocation[8]=C:\Program Files (x86)\GFI Software\GFIAgent\"
set "FolderLocation[9]=C:\Program Files (x86)\GFI Software\LanGuard 10\"
set "FolderLocation[10]=C:\Program Files (x86)\Sunbelt Software\Deployment\"
set "FolderLocation[11]=C:\Program Files (x86)\Sunbelt Software\SBEAgent\"
set "FolderLocation[12]=C:\ProgramData\VIPRE Business Agent\"
set "FolderLocation[13]=C:\ProgramData\GFI Software\Antimalware\"
set "FolderLocation[14]=C:\ProgramData\GFI Software\LanGuard 10\"
set "FolderLocation[15]=C:\ProgramData\Sunbelt Software\Antimalware\"
set "FolderLocation[16]=C:\Documents and Settings\All Users\Application Data\VIPRE Business Agent\"
set "FolderLocation[17]=C:\Documents and Settings\All Users\Application Data\GFI Software\Antimalware\"
set "FolderLocation[18]=C:\Documents and Settings\All Users\Application Data\GFI Software\LanGuard 10\"
set "FolderLocation[19]=C:\Documents and Settings\All Users\Application Data\Sunbelt Software\Antimalware\"
set "FolderLocation[20]=C:\Users\Default\VIPRE Business Agent\"
set "FolderLocation[21]=C:\Users\Default\GFI Software\Antimalware\"
set "FolderLocation[22]=C:\Users\Default\GFI Software\LanGuard 10\"
set "FolderLocation[23]=C:\Users\Default\Sunbelt Software\Antimalware\"
set "x=0"
:deleteFolderLoop
if defined FolderLocation[%x%] (
  if exist "!FolderLocation[%x%]!" rmdir /s /q "!FolderLocation[%x%]!"
  set /a "x+=1"
  PING localhost -n 1 -w 100 >NUL REM - required to prevent race errors
  GOTO :deleteFolderLoop
)
set "FileLocation[0]=%SYSTEMROOT%\system32\drivers\sbaphd.sys"
set "FileLocation[1]=%SYSTEMROOT%\system32\drivers\sbapifs.sys"
set "FileLocation[2]=%SYSTEMROOT%\system32\drivers\SbFw.sys"
set "FileLocation[3]=%SYSTEMROOT%\system32\drivers\SbFwIm.sys"
set "FileLocation[4]=%SYSTEMROOT%\system32\drivers\sbhips.sys"
set "FileLocation[5]=%SYSTEMROOT%\system32\drivers\SBREDrv.sys"
set "FileLocation[6]=%SYSTEMROOT%\system32\drivers\sbtis.sys"
set "FileLocation[7]=%SYSTEMROOT%\system32\drivers\sbwtis.sys"
set "FileLocation[8]=%SYSTEMROOT%\system32\drivers\gfiark.sys"
set "FileLocation[9]=%SYSTEMROOT%\system32\drivers\gfiutil.sys"
set "x=0"
:deleteFileLoop
if defined FileLocation[%x%] (
  if exist "!FileLocation[%x%]!" del "!FileLocation[%x%]!"
  set /a "x+=1"
  GOTO :deleteFileLoop
)
echo Done.
echo.
echo ==========================================================
echo This script is now complete.  The final task is to reboot.
echo Schedule reboot in RMM.
echo ==========================================================
:END
:: Run ver so that we can Exit 0
Ver >NUL
endlocal
Exit /b 0