@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0chrome_json_opener.ps1"
if errorlevel 1 pause
