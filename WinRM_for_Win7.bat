:: Enable WinRM on Win7 when check fails.
@powershell set-executionpolicy -executionpolicy remotesigned -force
winrm quickconfig -q
Ver > nul
Exit /b 0