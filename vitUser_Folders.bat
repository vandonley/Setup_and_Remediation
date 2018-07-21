@ECHO off
::
:: Create user folder at logon
::
:: Van Donley
:: VisionIT
:: 03/21/2018
::
:: Set user folder location
SET myFolder="\\<SERVER>\<Folder>\%USERNAME%"
:: AD group to check membership for creating a folder
SET myGroup="<AD Group Name>"
::
:: Check to see if the user is a member of the gorup
FOR /f %%f in ('"NET user %USERNAME% /domain | FINDSTR /i %MyGroup%"') do SET /a i=%i%+1
:: Check for folder if in group or exit
IF %i% gtr 0 (GOTO :FOLDERCHECK)
GOTO :END
::
:FOLDERCHECK
:: Create folder and set permissions if it doesn't exist
IF NOT EXIST %myFolder% (
    MD %myFolder%
    ICACLS %myFolder% /inheritance:e /t
    ICACLS %myFolder% /grant "%USERDOMAIN%\%USERNAME%:(OI)(CI)M"
    )
::
:END
EXIT