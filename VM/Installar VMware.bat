@echo off
title Instalador VMware
cd /d "%~dp0"

echo Buscando instalador PowerShell...

for %%F in (*.ps1) do (
    echo Encontrado: %%F
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%%~fF"
    goto :fin
)

echo.
echo ERROR: No se encontro ningun archivo .ps1 en esta carpeta.
echo Asegurate de poner el BAT junto al archivo PS1.

:fin
echo.
pause