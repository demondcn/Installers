@echo off
setlocal
chcp 65001 >nul
title Instalador SOLIDWORKS desde GitHub Releases
fltmc >nul 2>&1
if errorlevel 1 (
 echo ERROR: Ejecuta este archivo como administrador.
 pause
 exit /b 1
)
set "REPO=demondcn/Installers"
set "ASSET=SolidWorksSetup.exe"
set "DESTINO=%TEMP%\SolidWorksSetup.exe"
echo Consultando el ultimo Release de %REPO%...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $headers=@{'User-Agent'='SolidWorks-Installer'; 'Accept'='application/vnd.github+json'}; try { $r=Invoke-RestMethod -Uri 'https://api.github.com/repos/%REPO%/releases/latest' -Headers $headers; $a=$r.assets | Where-Object { $_.name -eq '%ASSET%' } | Select-Object -First 1; if (-not $a) { throw 'No se encontro %ASSET% en el ultimo Release.' }; Write-Host ('Release: ' + $r.tag_name); Write-Host ('Descargando: ' + $a.browser_download_url); Invoke-WebRequest -Uri $a.browser_download_url -OutFile '%DESTINO%' -Headers @{'User-Agent'='SolidWorks-Installer'}; if ((Get-Item '%DESTINO%').Length -ne $a.size) { throw 'Tamano de descarga incorrecto.' }; Write-Host 'Descarga completada y tamano verificado.' } catch { Write-Host ('ERROR: ' + $_.Exception.Message); exit 1 }"
if errorlevel 1 (
 echo.
 echo No se pudo descargar. Comprueba que el repositorio sea publico,
 echo que el Release este publicado y que el archivo tenga el nombre correcto.
 pause
 exit /b 1
)
echo.
echo Ejecutando instalador con permisos de administrador...
start "" /wait "%DESTINO%"
echo.
echo El instalador se ha cerrado.
pause
