@ECHO off
::
:: Reset Windows Update component to fix patch management
::
:: Van Donley
:: VisionIT
:: 01/11/2018
::
:: Stop Windows Update services
ECHO Stopping services
for /F "tokens=3 delims=: " %%H in ('sc query bits ^| findstr "        STATE"') do (
  if /I "%%H" NEQ "STOPPED" (
   NET stop bits
  )
)
for /F "tokens=3 delims=: " %%H in ('sc query wuauserv ^| findstr "        STATE"') do (
  if /I "%%H" NEQ "STOPPED" (
   NET stop wuauserv
  )
)
for /F "tokens=3 delims=: " %%H in ('sc query appidsvc ^| findstr "        STATE"') do (
  if /I "%%H" NEQ "STOPPED" (
   NET stop appidsvc
  )
)
for /F "tokens=3 delims=: " %%H in ('sc query cryptsvc ^| findstr "        STATE"') do (
  if /I "%%H" NEQ "STOPPED" (
   NET stop cryptsvc
  )
)
::
:: Delete downloader files
ECHO Removing download files
Del "%ALLUSERSPROFILE%\Application Data\Microsoft\Network\Downloader\qmgr*.dat"
::
:: Rename SoftwareDistribution and Catroot2 folders so they can be deleted
ECHO Removing installed update history
Ren %systemroot%\SoftwareDistribution SoftwareDistribution.bak
Ren %systemroot%\system32\catroot2 catroot2.bak
Rd /q /s %systemroot%\SoftwareDistribution.bak
Rd /q /s %systemroot%\system32\catroot2.bak
::
:: Reset service security descriptors
ECHO Reset service secutiry descriptors
sc.exe sdset bits D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)
sc.exe sdset wuauserv D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)
::
:: Clear the BITS queue
ECHO Clear BITS queue
bitsadmin.exe /reset /allusers
::
:: Start Windows Update services
ECHO Starting services
for /F "tokens=3 delims=: " %%H in ('sc query bits ^| findstr "        STATE"') do (
  if /I "%%H" NEQ "RUNNING" (
   NET start bits
  )
)
for /F "tokens=3 delims=: " %%H in ('sc query wuauserv ^| findstr "        STATE"') do (
  if /I "%%H" NEQ "RUNNING" (
   NET start wuauserv
  )
)
for /F "tokens=3 delims=: " %%H in ('sc query appidsvc ^| findstr "        STATE"') do (
  if /I "%%H" NEQ "RUNNING" (
   NET start appidsvc
  )
)
for /F "tokens=3 delims=: " %%H in ('sc query cryptsvc ^| findstr "        STATE"') do (
  if /I "%%H" NEQ "RUNNING" (
   NET start cryptsvc
  )
)
::
:: Exit as success not matter what
EXIT /b 0