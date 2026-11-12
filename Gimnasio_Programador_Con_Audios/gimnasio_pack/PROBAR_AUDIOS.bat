@echo off
cd /d "%~dp0"
echo 1 - 8:45
 echo 2 - 8:55
 echo 3 - 9:00
set /p OPCION=Seleccione anuncio [1/2/3]: 
if "%OPCION%"=="1" set "HORA=0845"
if "%OPCION%"=="2" set "HORA=0855"
if "%OPCION%"=="3" set "HORA=0900"
if not defined HORA (echo Opcion no valida & pause & exit /b 1)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Reproducir.ps1" -Hora %HORA%
pause
