:: Base software install using Chocolatey
:: Parsec Computer Corp.
:: Created:  Van Donley - 05/11/2016
:: Updated:  Van Donley - 0428/2017
::
@ECHO off
::
:: Make sure Chocolatey is up to date
C:\ProgramData\Chocolatey\CHOCO.exe upgrade -y chocolatey
::
:: Install packages
C:\ProgramData\Chocolatey\CHOCO.exe install -y adobereader 7zip.install dotnet4.6.2 powershell procexp procmon autoruns