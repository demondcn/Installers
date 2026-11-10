@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
fltmc.exe >nul 2>&1
if errorlevel 1 (
  set "SW_DEPLOY_BAT=%~f0"
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:SW_DEPLOY_BAT -Verb RunAs" 2>nul
  if errorlevel 1 echo [ERROR] No se concedieron permisos de administrador.
  exit /b
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Lib\SolidWorksDeploy.ps1" -Action License
set "RC=%ERRORLEVEL%"
pause
exit /b %RC%
