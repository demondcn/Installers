@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

title Actualizacion IBM SPSS Statistics 32

REM ============================================================
REM IBM SPSS Statistics 32 - instalacion automatica v5
REM
REM Doble clic normal -> Windows pide UAC -> pulse Si.
REM
REM Coloque este BAT en la MISMA carpeta que:
REM   SPSSCLT64_v32_MWin_Multi.exe
REM
REM Esta version NO enumera todo el registro de Windows.
REM Detecta SPSS 32 por el ProductCode oficial del MSI:
REM   {E81723D5-55A2-427D-AA9B-8E63F3F2C387}
REM ============================================================

set "PRODUCT_CODE={E81723D5-55A2-427D-AA9B-8E63F3F2C387}"
set "INSTALLER=%~dp0SPSSCLT64_v32_MWin_Multi.exe"
set "LOGDIR=C:\SPSS32_Logs"
set "LOG=%LOGDIR%\SPSS32_%COMPUTERNAME%.log"
set "RESULT=%LOGDIR%\resultado_%COMPUTERNAME%.csv"

REM Licencia opcional. Dejar vacio si se licenciara despues.
set "LSHOST="
set "AUTHCODE="

REM ------------------------------------------------------------
REM 1. Auto-elevacion
REM ------------------------------------------------------------
fltmc >nul 2>&1
if not "%errorlevel%"=="0" (
    echo Solicitando permisos de administrador...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1

cls
echo ============================================================
echo        IBM SPSS Statistics 32 - ACTUALIZACION
echo ============================================================
echo Equipo: %COMPUTERNAME%
echo.

REM ------------------------------------------------------------
REM 2. Comprobar si SPSS 32 YA esta instalado
REM ------------------------------------------------------------
echo [CHECK] Comprobando IBM SPSS Statistics 32...
call :DETECT_SPSS32

if defined SPSS32_VERSION (
    echo.
    echo ============================================================
    echo [OK] IBM SPSS Statistics 32 YA esta instalado.
    echo Version detectada: !SPSS32_VERSION!
    echo ============================================================
    call :WRITE_RESULT "!SPSS32_VERSION!" "YA_INSTALADO" "0"
    echo.
    echo Resultado:
    echo   %RESULT%
    echo.
    pause
    exit /b 0
)

echo [INFO] SPSS Statistics 32 no esta registrado. Se instalara.
echo.

REM ------------------------------------------------------------
REM 3. Localizar instalador
REM ------------------------------------------------------------
if not exist "%INSTALLER%" (
    set "INSTALLER="
    for %%I in ("%~dp0*SPSSCLT64*v32*MWin*Multi*.exe") do (
        if exist "%%~fI" set "INSTALLER=%%~fI"
    )
)

if not defined INSTALLER (
    echo [ERROR] No encuentro SPSSCLT64_v32_MWin_Multi.exe
    echo Debe estar en la misma carpeta que este BAT.
    call :WRITE_RESULT "NO_DETECTADA" "FALTA_INSTALADOR" "2"
    echo.
    pause
    exit /b 2
)

if not exist "%INSTALLER%" (
    echo [ERROR] El instalador configurado no existe:
    echo   %INSTALLER%
    call :WRITE_RESULT "NO_DETECTADA" "FALTA_INSTALADOR" "2"
    echo.
    pause
    exit /b 2
)

echo Instalador encontrado:
echo   %INSTALLER%
echo.

REM ------------------------------------------------------------
REM 4. Cerrar SPSS si esta abierto
REM ------------------------------------------------------------
echo [1/3] Cerrando SPSS si esta abierto...
taskkill /IM stats.exe /F >nul 2>&1
taskkill /IM spssengine.exe /F >nul 2>&1
taskkill /IM statisticsb.exe /F >nul 2>&1

REM ------------------------------------------------------------
REM 5. Instalar silenciosamente
REM ------------------------------------------------------------
echo [2/3] Instalando IBM SPSS Statistics 32...
echo Esto puede tardar varios minutos. NO cierre esta ventana.
echo Log:
echo   %LOG%
echo.

set "MSIARGS=/qn /norestart /L*v %LOG%"

if defined LSHOST (
    set "MSIARGS=!MSIARGS! LICENSETYPE=Network LSHOST=%LSHOST%"
)

if defined AUTHCODE (
    set "MSIARGS=!MSIARGS! AUTHCODE=%AUTHCODE%"
)

start /wait "" "%INSTALLER%" /s /v"!MSIARGS!"
set "RC=%errorlevel%"

echo Instalador finalizo con codigo: !RC!
echo.

REM Esperar un momento a que Windows Installer cierre y registre el producto.
timeout /t 3 /nobreak >nul

REM ------------------------------------------------------------
REM 6. Verificacion REAL por ProductCode
REM ------------------------------------------------------------
echo [3/3] Verificando instalacion...
call :DETECT_SPSS32

if defined SPSS32_VERSION (
    echo.
    echo ============================================================
    echo [OK] IBM SPSS Statistics 32 instalado correctamente.
    echo Version: !SPSS32_VERSION!
    echo Codigo del instalador: !RC!
    echo ============================================================

    if "!RC!"=="3010" (
        echo [AVISO] Windows solicita reinicio para completar cambios.
        call :WRITE_RESULT "!SPSS32_VERSION!" "INSTALADO_REINICIO_PENDIENTE" "!RC!"
    ) else (
        call :WRITE_RESULT "!SPSS32_VERSION!" "INSTALADO_OK" "!RC!"
    )

    echo.
    echo Resultado guardado en:
    echo   %RESULT%
    echo.
    pause
    exit /b 0
)

REM Si Windows Installer devolvio exito pero no se pudo consultar el producto,
REM no decimos que la instalacion fallo: lo reportamos como verificacion pendiente.
if "!RC!"=="0" (
    echo.
    echo ============================================================
    echo [AVISO] El instalador termino correctamente ^(codigo 0^),
    echo pero no se pudo leer la version mediante Windows Installer.
    echo ============================================================
    echo.
    echo Revisa si existe:
    echo   C:\Program Files\IBM\SPSS Statistics
    echo.
    echo Log:
    echo   %LOG%
    call :WRITE_RESULT "NO_DETECTADA" "INSTALADOR_OK_VERIFICACION_PENDIENTE" "!RC!"
    echo.
    pause
    exit /b 4
)

if "!RC!"=="3010" (
    echo.
    echo ============================================================
    echo [AVISO] Instalacion terminada; Windows solicita reinicio.
    echo No se pudo consultar la version antes del reinicio.
    echo ============================================================
    call :WRITE_RESULT "NO_DETECTADA" "REINICIO_PENDIENTE_VERIFICACION" "!RC!"
    echo.
    pause
    exit /b 0
)

echo.
echo ============================================================
echo [ERROR] El instalador devolvio codigo: !RC!
echo ============================================================
echo.
echo Revisa:
echo   %LOG%
call :WRITE_RESULT "NO_DETECTADA" "ERROR_INSTALACION" "!RC!"
echo.
pause
exit /b 3


REM ============================================================
REM SUBRUTINA: DETECTAR SPSS 32
REM 1) Windows Installer COM por ProductCode.
REM 2) Registro exacto por ProductCode como respaldo.
REM NO recorre las claves de desinstalacion con Get-ItemProperty.
REM ============================================================
:DETECT_SPSS32
set "SPSS32_VERSION="

REM Metodo principal: preguntar directamente a Windows Installer.
for /f "usebackq delims=" %%V in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; $wi=New-Object -ComObject WindowsInstaller.Installer; try { $v=$wi.ProductInfo('%PRODUCT_CODE%','VersionString'); if($v){[Console]::WriteLine($v)} } catch {}" 2^>nul`) do (
    set "SPSS32_VERSION=%%V"
)

if defined SPSS32_VERSION (
    exit /b 0
)

REM Respaldo 1: clave de desinstalacion de 64 bits.
for /f "tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\%PRODUCT_CODE%" /v DisplayVersion 2^>nul ^| findstr /I /C:"DisplayVersion"') do (
    set "SPSS32_VERSION=%%B"
)

if defined SPSS32_VERSION (
    exit /b 0
)

REM Respaldo 2: clave WOW6432Node.
for /f "tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\%PRODUCT_CODE%" /v DisplayVersion 2^>nul ^| findstr /I /C:"DisplayVersion"') do (
    set "SPSS32_VERSION=%%B"
)

exit /b 0


REM ============================================================
REM SUBRUTINA: ESCRIBIR RESULTADO CSV
REM ============================================================
:WRITE_RESULT
set "R_VERSION=%~1"
set "R_STATUS=%~2"
set "R_CODE=%~3"
set "NOW="

for /f "usebackq delims=" %%D in (`powershell.exe -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'"`) do (
    set "NOW=%%D"
)

>"%RESULT%" echo Equipo,Fecha,SPSS_Version,Estado,Codigo
>>"%RESULT%" echo %COMPUTERNAME%,!NOW!,!R_VERSION!,!R_STATUS!,!R_CODE!
exit /b 0
