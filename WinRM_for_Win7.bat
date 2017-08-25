:: Enable WinRM on Win7 when check fails.
powershell set-executionpolicy -executionpolicy remotesigned -force
winrm quickconfig -q
exit 0