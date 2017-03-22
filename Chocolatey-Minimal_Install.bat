@ECHO OFF
REM Base software install using Chocolatey
REM Parsec Computer Corp.
REM Created:  Van Donley - 05/11/2016
REM Updated:  Van Donley - 12/01/2016

REM Make sure Chocolatey is up to date
CUP chocolatey -y

REM Install packages

CHOCO install 7zip.install dotnet4.6.1 PowerShell procexp procmon AutoRuns -y --ignorechecksum
