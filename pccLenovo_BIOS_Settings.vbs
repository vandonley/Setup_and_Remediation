'
' Set specific BIOS Setting for Lenovo via WMI
' Defaults to changing fan setting to better
' temperature control. Pass other settings as
' <scriptname> "Setting" "Value"
'
On Error Resume Next
Dim colItems
Dim numArgurments

' Set the fan speed by default and ignore -logfile from MaxRM
If WScript.Arguments.Count < 2 OR WScript.Arguments(0) = "-logfile" Then
	strRequest = "ICE Performance Mode,Better Thermal Performance;"
	
	Else strRequest = WScript.Arguments(0) + "," + WScript.Arguments(1) + ";"
End If

strComputer = "LOCALHOST"     ' Change as needed.
Set objWMIService = GetObject("WinMgmts:" _
    &"{ImpersonationLevel=Impersonate}!\\" & strComputer & "\root\wmi")
Set colItems = objWMIService.ExecQuery("Select * from Lenovo_SetBiosSetting")

For Each objItem in colItems
    ObjItem.SetBiosSetting strRequest, strReturn
Next

WScript.Echo strRequest
WScript.Echo " SetBiosSetting: " + strReturn

If strReturn = "Success" Then
    WScript.Quit 0
End If

Set colItems = objWMIService.ExecQuery("Select * from Lenovo_SaveBiosSettings")

strReturn = "error"
For Each objItem in colItems
    ObjItem.SaveBiosSettings ";", strReturn
Next

WScript.Echo strRequest
WScript.Echo " SaveBiosSettings: " + strReturn
WScript.Quit 1001