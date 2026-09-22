Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
widget = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "CodexQuotaWidget.ps1")
command = "powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File " & Chr(34) & widget & Chr(34)
shell.Run command, 0, False
