@ECHO OFF
 
SET error_service_does_not_exist=1060
SET error_service_not_active=1062
 
SET old_languard_binary_path=C:\PROGRA~2\ADVANC~1\patchman\lnssatt.exe
SET new_languard_binary_path=C:\PROGRA~2\ADVANC~1\patchman\11\lnssatt.exe
 
IF NOT EXIST %new_languard_binary_path% (
    ECHO The new service path was not found "%new_languard_binary_path%".
    EXIT /B 2
)
ECHO The new service path was found at "%new_languard_binary_path%".
 
SET service_controller_command=sc
WHERE %service_controller_command% >nul 2>nul
IF %ERRORLEVEL% NEQ 0 (
    ECHO The "%service_controller_command%" command was not found in the path. >&2
    EXIT /B 1
)
 
SET service=gfi_lanss11_attservice
 
FOR /f "tokens=3 delims= " %%t in ('sc qc gfi_lanss11_attservice ^| find "BINARY"') DO SET raw_service_path=%%t
SET current_service_path=%raw_service_path:~1,-1%
SET current_service_path=%raw_service_path%
 
IF "%current_service_path%" == "%new_languard_binary_path%" (
    ECHO The Languard service is already pointing to the new path ^(%new_languard_binary_path%^), exiting.
    EXIT /B 0
)
ECHO The Languard service is pointing to an old path (%current_service_path%), proceeding with the fix.
 
ECHO Stopping service beforing making changes.
sc stop %service% 1>nul
IF %ERRORLEVEL% == 0 (
    ECHO Service succesfully stopped
) ELSE IF %ERRORLEVEL% == %ERROR_SERVICE_NOT_ACTIVE% (
    ECHO Service '%service' already stopped
) ELSE (
    ECHO Unable to stop service. Reason unknown. Proceeding anyway.
)
 
ECHO Updating binary path for service %service%
sc config %service% binPath= "%new_languard_binary_path% -service" 1>nul
 
ECHO Starting service
sc start %service% 1>nul
IF %ERRORLEVEL% NEQ 0 (
    ECHO Unable to start service.
    EXIT /B 1
)
 
ECHO The service was successfully updated and restarted.
EXIT /B 0