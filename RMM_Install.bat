:: Install SolarWinds agent if not present.
:: Vision Municipal Systems
:: Created by Van Donley
:: on 10/08/2014
::
:: Last updated by Van Donley
:: on 06/27/2018
::
:: Note that the script expects that a folder
:: exists in the install share that
:: the installer can write to!
::
:: Set the software friendly name for reporting.
SET SOFTWARE_NAME=SolarWinds_RMM_Client
::
:: Set the install point.
SET INSTALL_POINT=<FQDN\Share>
::
:: Set install folder for this application.
SET INSTALL_FOLDER=<Folder Name>
::
:: Set the logging folder.
SET RESULT_FOLDER=<Folder Name>
::
:: Set the installer file.
SET INSTALL_FILE=agent.msi
::
:: Set the base of the registry key to query to check if application is installed.
SET REG_BASE="HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\Advanced Monitoring Agent"
::
:: Set the registry value to query.
SET REG_VALUE=ImagePath
::
:: Check to see if registry value is present. End if it is present and install if any other error level.
REG QUERY %REG_BASE% /v %REG_VALUE%
IF %ERRORLEVEL%==0 GOTO END
GOTO INSTALL
::
:INSTALL
:: Creating log folder on server.
IF NOT EXIST "\\%INSTALL_POINT%\%RESULT_FOLDER%\%COMPUTERNAME%\" MKDIR "\\%INSTALL_POINT%\%RESULT_FOLDER%\%COMPUTERNAME%\"
::
:: Report install for tracking.
ECHO %SOFTWARE_NAME% installed on %COMPUTERNAME% at %DATE% %TIME% >> %SYSTEMROOT%\%COMPUTERNAME%.txt
ECHO %SOFTWARE_NAME% installed on %COMPUTERNAME% at %DATE% %TIME% >> \\%INSTALL_POINT%\%RESULT_FOLDER%\%COMPUTERNAME%.txt
::
:: install the software
START /WAIT MSIExec.EXE /i \\%INSTALL_POINT%\%INSTALL_FOLDER%\%INSTALL_FILE% /l* \\%INSTALL_POINT%\%RESULT_FOLDER%\%COMPUTERNAME%\%SOFTWARE_NAME%_Install.txt /qn
::
:END
EXIT