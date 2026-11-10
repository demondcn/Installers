@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Lib\SolidWorksDeploy.ps1" -Action FinalTest
set "RC=%ERRORLEVEL%"
pause
exit /b %RC%
