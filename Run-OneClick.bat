@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-WindowsPCHandover.ps1"
set "RC=%ERRORLEVEL%"
echo.
echo Windows PC Handover Test finished with exit code %RC%.
pause
exit /b %RC%
