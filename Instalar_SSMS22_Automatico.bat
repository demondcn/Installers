@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title SSMS 22 - Instalacion automatica

REM ============================================================
REM SQL SERVER MANAGEMENT STUDIO 22 (SSMS)
REM Interfaz visual para administrar SQL Server
REM
REM Flujo:
REM   1) Auto-elevacion a Administrador
REM   2) Detecta si SSMS ya esta instalado
REM   3) Descarga el instalador oficial de Microsoft
REM   4) Instala en modo PASSIVE (muestra progreso)
REM   5) Verifica Ssms.exe
REM ============================================================

fltmc >nul 2>&1
if not "%errorlevel%"=="0" (
    echo Solicitando permisos de administrador...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "WORK=C:\SSMS22_Setup"
set "BOOT=%WORK%\vs_SSMS.exe"
set "URL=https://aka.ms/ssms/22/release/vs_SSMS.exe"
set "LOGDIR=C:\Software_Logs"
set "LOG=%LOGDIR%\SSMS22_%COMPUTERNAME%.log"
set "RESULT=%LOGDIR%\SSMS22_resultado_%COMPUTERNAME%.txt"

if not exist "%WORK%" mkdir "%WORK%" >nul 2>&1
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1

cls
echo ============================================================
echo        SSMS 22 - INSTALACION AUTOMATICA
echo ============================================================
echo Equipo: %COMPUTERNAME%
echo.

echo [1/4] Comprobando si SSMS ya esta instalado...
call :FIND_SSMS

if defined SSMS_EXE (
    echo [OK] SSMS ya esta instalado:
    echo      !SSMS_EXE!
    goto :SUCCESS
)

echo [INFO] SSMS no esta instalado.
echo.

echo [2/4] Descargando SSMS 22 desde Microsoft...
where curl.exe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] curl.exe no esta disponible.
    goto :FAIL
)

if exist "%BOOT%" del /q "%BOOT%" >nul 2>&1

curl.exe --fail --location --retry 3 --retry-delay 5 --progress-bar ^
  --output "%BOOT%" "%URL%"

if errorlevel 1 (
    echo [ERROR] No se pudo descargar SSMS.
    goto :FAIL
)

for %%F in ("%BOOT%") do set "SIZE=%%~zF"
if !SIZE! LSS 1000000 (
    echo [ERROR] La descarga parece invalida.
    goto :FAIL
)

echo.
echo [OK] Instalador descargado.
echo.

echo [3/4] Instalando SSMS 22...
echo.
echo Se mostrara una interfaz basica de progreso.
echo No requiere seleccionar opciones.
echo.

"%BOOT%" --installPath "C:\SSMS22" --passive --wait --norestart
set "RC=!errorlevel!"

>>"%LOG%" echo %date% %time% - SSMS RC=!RC!

echo.
echo Codigo instalador: !RC!
echo.

if not "!RC!"=="0" if not "!RC!"=="3010" (
    echo [ERROR] El instalador devolvio un error.
    goto :FAIL
)

echo [4/4] Verificando SSMS...
timeout /t 5 /nobreak >nul
call :FIND_SSMS

if not defined SSMS_EXE (
    echo [ERROR] No pude encontrar Ssms.exe.
    goto :FAIL
)

:SUCCESS
>"%RESULT%" echo SSMS 22 - RESULTADO
>>"%RESULT%" echo Equipo=%COMPUTERNAME%
>>"%RESULT%" echo Estado=OK
>>"%RESULT%" echo Ruta=!SSMS_EXE!
>>"%RESULT%" echo Log=%LOG%

echo.
echo ============================================================
echo [OK] SSMS 22 QUEDO INSTALADO
echo ============================================================
echo Ruta:
echo   !SSMS_EXE!
echo.
echo Para conectarte a SQL Server 2025 usa:
echo   localhost\SQL2025
echo.
echo Autenticacion:
echo   Windows Authentication
echo.
pause
exit /b 0

:FIND_SSMS
set "SSMS_EXE="
for /f "usebackq delims=" %%F in (`powershell.exe -NoProfile -Command "$roots=@('C:\SSMS22',$env:ProgramFiles,${env:ProgramFiles(x86)}); foreach($r in $roots){if($r -and (Test-Path $r)){$f=Get-ChildItem -Path $r -Filter 'Ssms.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1; if($f){$f.FullName;break}}}"`) do (
    if not defined SSMS_EXE set "SSMS_EXE=%%F"
)
exit /b 0

:FAIL
>"%RESULT%" echo SSMS 22 - RESULTADO
>>"%RESULT%" echo Equipo=%COMPUTERNAME%
>>"%RESULT%" echo Estado=ERROR
>>"%RESULT%" echo Log=%LOG%

echo.
echo ============================================================
echo [ERROR] SSMS 22 NO QUEDO VERIFICADO
echo ============================================================
echo Revisa:
echo   %LOG%
echo.
pause
exit /b 1
