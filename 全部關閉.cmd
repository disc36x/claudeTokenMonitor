@echo off
powershell -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -like '*widget.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
echo done & timeout /t 1 >nul
