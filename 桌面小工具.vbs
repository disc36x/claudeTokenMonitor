' Launches the token usage widget with no console window
Set fso = CreateObject("Scripting.FileSystemObject")
folder = fso.GetParentFolderName(WScript.ScriptFullName)
ps1 = fso.BuildPath(folder, "widget.ps1")
CreateObject("WScript.Shell").Run "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1 & """", 0, False
