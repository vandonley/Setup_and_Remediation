@ECHO off
::
:: Create user folder at logon
::
:: Van Donley
:: VisionIT
:: 03/21/2018
::
:: Set user folder location
SET myFolder="\\<SERVER>\Users\%USERNAME%"
:: Create folder and set permissions if it doesn't exist
IF NOT EXIST %myFolder% (
    MD %myFolder%
    ICACLS %myFolder% /grant %USERNAME%:M /t
)
EXIT