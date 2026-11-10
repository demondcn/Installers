@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Lib\SolidWorksDeploy.ps1" -Action Configure
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" echo [ERROR] No se creo la configuracion. Codigo %RC%.
pause
exit /b %RC%
