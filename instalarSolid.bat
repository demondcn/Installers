
@echo off
setlocal
title Instalador SOLIDWORKS - GitHub
color 0A

:: Comprobar permisos de administrador
fltmc >nul 2>&1
if errorlevel 1 (
    echo Ejecuta este BAT como administrador.
    pause
    exit /b 1
)

set "URL=https://github.com/demondcn/Installers/releases/download/v1.00.1/SolidWorksSetup.exe"
set "DESTINO=%TEMP%\SolidWorksSetup.exe"

echo ========================================
echo DESCARGANDO SOLIDWORKS DESDE GITHUB
echo ========================================

powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%URL%' -OutFile '%DESTINO%' -ErrorAction Stop } catch { Write-Host $_.Exception.Message; exit 1 }"

if errorlevel 1 (
    echo ERROR: No se pudo descargar el instalador.
    pause
    exit /b 1
)

if not exist "%DESTINO%" (
    echo ERROR: No se encontro el instalador.
    pause
    exit /b 1
)

echo.
echo Descarga completada.
echo Ejecutando instalador como administrador...
start "" /wait "%DESTINO%"

echo.
echo El instalador ha terminado.
pause
