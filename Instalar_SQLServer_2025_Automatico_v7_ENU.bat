@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title SQL Server 2025 Developer ENU + SSMS - Automatico v7

REM ============================================================
REM SQL SERVER 2025 DEVELOPER + SSMS - AUTOMATICO v7
REM
REM CORRECCION PRINCIPAL:
REM   Descarga el medio EN INGLES (en-US) para evitar el error
REM   -2067529714 / 0x84C4000E / InvalidPlatformOSLanguage.
REM
REM Microsoft admite SQL Server en ingles sobre Windows localizado.
REM
REM Instancia:
REM   SQL2025
REM Conexion:
REM   localhost\SQL2025
REM
REM NO elimina ni modifica SQLEXPRESS 2022 existente.
REM ============================================================

fltmc >nul 2>&1
if not "%errorlevel%"=="0" (
    echo Solicitando permisos de administrador...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "INSTANCE=SQL2025"
set "SERVICE=MSSQL$SQL2025"
set "SERVER=localhost\SQL2025"

set "WORK=C:\SQL2025_Setup"
set "MEDIA=%WORK%\Media_ENU"
set "BOOT=%WORK%\SQL2025-SSEI-EntDev.exe"
set "SQLURL=https://go.microsoft.com/fwlink/?linkid=2344626"

set "LOGDIR=C:\Software_Logs"
set "LOG=%LOGDIR%\SQLServer2025_%COMPUTERNAME%.log"
set "RESULT=%LOGDIR%\SQLServer2025_resultado_%COMPUTERNAME%.txt"

if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
if not exist "%WORK%" mkdir "%WORK%" >nul 2>&1
if not exist "%MEDIA%" mkdir "%MEDIA%" >nul 2>&1

cls
echo ============================================================
echo SQL SERVER 2025 DEVELOPER ENU + SSMS - AUTOMATICO v7
echo ============================================================
echo Equipo    : %COMPUTERNAME%
echo Instancia : %INSTANCE%
echo Conexion  : %SERVER%
echo.

>>"%LOG%" echo ============================================================
>>"%LOG%" echo %date% %time% - Inicio v7 ENU
>>"%LOG%" echo Equipo=%COMPUTERNAME%

REM ============================================================
REM 1/9 - INFORMACION REGIONAL
REM ============================================================
echo [1/9] Revisando idioma/configuracion regional de Windows...
powershell.exe -NoProfile -Command "Write-Host ('UI Language : ' + (Get-UICulture).Name); Write-Host ('User Culture: ' + (Get-Culture).Name); Write-Host ('System Locale: ' + (Get-WinSystemLocale).Name)"
echo.

REM ============================================================
REM 2/9 - COMPROBAR INSTANCIA
REM ============================================================
echo [2/9] Comprobando instancia SQL2025...
sc query "%SERVICE%" >nul 2>&1
if not errorlevel 1 (
    echo [OK] La instancia SQL2025 ya existe.
    goto :VERIFY_SERVICE
)

echo [INFO] SQL2025 aun no existe.
echo.

REM ============================================================
REM 3/9 - DESCARGAR BOOTSTRAPPER
REM ============================================================
echo [3/9] Descargando bootstrapper actual de Microsoft...
where curl.exe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] curl.exe no esta disponible.
    goto :FAIL
)

if exist "%BOOT%" del /q "%BOOT%" >nul 2>&1

curl.exe --fail --location --retry 3 --retry-delay 5 --progress-bar ^
  --output "%BOOT%" "%SQLURL%"

if errorlevel 1 (
    echo [ERROR] No se pudo descargar el bootstrapper.
    goto :FAIL
)

for %%F in ("%BOOT%") do set "BOOTSIZE=%%~zF"
if !BOOTSIZE! LSS 1000000 (
    echo [ERROR] Bootstrapper invalido: !BOOTSIZE! bytes.
    goto :FAIL
)

echo [OK] Bootstrapper descargado.
echo.

REM ============================================================
REM 4/9 - DESCARGAR ISO EN INGLES
REM ============================================================
echo [4/9] Descargando medio SQL Server 2025 EN INGLES (en-US)...
echo.
echo Se fuerza /Language=en-US para evitar InvalidPlatformOSLanguage.
echo Esta descarga es grande y puede tardar.
echo.

REM Limpiar solo ISOs del directorio ENU de este BAT.
del /q "%MEDIA%\*.iso" >nul 2>&1

start /wait "" "%BOOT%" ^
  /ACTION=Download ^
  /LANGUAGE=en-US ^
  /MEDIAPATH="%MEDIA%" ^
  /MEDIATYPE=ISO ^
  /QUIET

set "DLRC=!errorlevel!"
>>"%LOG%" echo Download ENU RC=!DLRC!

if not "!DLRC!"=="0" (
    echo [ERROR] La descarga ENU devolvio codigo !DLRC!.
    goto :FAIL
)

set "ISO="
for /r "%MEDIA%" %%F in (*.iso) do (
    if exist "%%~fF" if not defined ISO set "ISO=%%~fF"
)

if not defined ISO (
    echo [ERROR] No encuentro el ISO ENU descargado.
    echo Carpeta: %MEDIA%
    goto :FAIL
)

echo [OK] ISO ENU:
echo      !ISO!
echo.

REM ============================================================
REM 5/9 - MONTAR ISO
REM ============================================================
echo [5/9] Montando ISO...

set "DRIVE="
for /f "usebackq delims=" %%D in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$img=Mount-DiskImage -ImagePath '!ISO!' -PassThru; Start-Sleep -Seconds 3; $v=$img | Get-Volume; if($v){$v.DriveLetter}"`) do (
    if not defined DRIVE set "DRIVE=%%D"
)

if not defined DRIVE (
    echo [ERROR] No pude obtener la letra del ISO.
    goto :FAIL
)

set "SETUP=!DRIVE!:\setup.exe"
if not exist "!SETUP!" (
    echo [ERROR] No encuentro setup.exe en el ISO.
    goto :FAIL
)

echo [OK] Setup:
echo      !SETUP!
echo.

REM ============================================================
REM 6/9 - INSTALAR MOTOR 2025 EN INGLES
REM ============================================================
echo [6/9] Instalando SQL Server 2025 Developer ENU...
echo.
echo Se mostrara solo una interfaz basica de progreso.
echo No requiere seleccionar opciones.
echo.

set "SQLADMIN=%USERDOMAIN%\%USERNAME%"

start /wait "" "!SETUP!" ^
  /QS ^
  /ACTION=Install ^
  /ENU=TRUE ^
  /FEATURES=SQLEngine ^
  /INSTANCENAME=%INSTANCE% ^
  /SQLSYSADMINACCOUNTS="%SQLADMIN%" ^
  /IACCEPTSQLSERVERLICENSETERMS ^
  /SUPPRESSPRIVACYSTATEMENTNOTICE ^
  /TCPENABLED=1 ^
  /NPENABLED=0 ^
  /UpdateEnabled=True

set "SQLRC=!errorlevel!"
>>"%LOG%" echo SQL Setup ENU RC=!SQLRC!

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Dismount-DiskImage -ImagePath '!ISO!' -ErrorAction SilentlyContinue" >nul 2>&1

echo.
echo Codigo SQL Setup: !SQLRC!
echo.

if not "!SQLRC!"=="0" if not "!SQLRC!"=="3010" (
    echo [ERROR] SQL Server Setup fallo.
    echo Codigo decimal: !SQLRC!
    powershell.exe -NoProfile -Command "$n=[uint32]([int64]'!SQLRC!' -band 0xffffffff); Write-Host ('Codigo hexadecimal: 0x{0:X8}' -f $n)" 2>nul
    goto :FAIL
)

REM ============================================================
REM 7/9 - SERVICIO
REM ============================================================
:VERIFY_SERVICE
echo [7/9] Verificando servicio %SERVICE%...

sc query "%SERVICE%" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] No existe %SERVICE%.
    goto :FAIL
)

powershell.exe -NoProfile -Command "Start-Service -Name '%SERVICE%' -ErrorAction SilentlyContinue" >nul 2>&1
timeout /t 5 /nobreak >nul

set "SQL_STATUS="
for /f "usebackq delims=" %%S in (`powershell.exe -NoProfile -Command "(Get-Service -Name '%SERVICE%' -ErrorAction SilentlyContinue).Status"`) do set "SQL_STATUS=%%S"

echo Estado: !SQL_STATUS!
if /I not "!SQL_STATUS!"=="Running" goto :FAIL
echo.

REM ============================================================
REM 8/9 - CONEXION REAL Y VERSION
REM ============================================================
echo [8/9] Probando conexion y confirmando SQL Server 2025...

set "VERIFY=%TEMP%\sql2025_verify_%RANDOM%.txt"
if exist "%VERIFY%" del /q "%VERIFY%" >nul 2>&1

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $cn=New-Object System.Data.SqlClient.SqlConnection('Server=%SERVER%;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;Connection Timeout=20'); $cn.Open(); $cmd=$cn.CreateCommand(); $cmd.CommandText='SELECT CAST(SERVERPROPERTY(''ProductVersion'') AS nvarchar(50))+''@@''+CAST(SERVERPROPERTY(''Edition'') AS nvarchar(150))+''@@''+CAST(SERVERPROPERTY(''ProductLevel'') AS nvarchar(50))'; $r=$cmd.ExecuteScalar(); $cn.Close(); Set-Content -LiteralPath '%VERIFY%' -Value $r -Encoding ASCII" >>"%LOG%" 2>&1

if errorlevel 1 (
    echo [ERROR] El servicio corre, pero no pude conectar a %SERVER%.
    goto :FAIL
)

set "LINE="
set /p LINE=<"%VERIFY%"
del /q "%VERIFY%" >nul 2>&1

for /f "tokens=1,2,3 delims=@" %%A in ("!LINE!") do (
    set "SQLVER=%%A"
    set "SQLED=%%B"
    set "SQLLEVEL=%%C"
)

echo Version : !SQLVER!
echo Edicion : !SQLED!
echo Nivel   : !SQLLEVEL!

echo !SQLVER! | findstr /B /C:"17." >nul
if errorlevel 1 (
    echo [ERROR] La instancia responde, pero NO es SQL Server 2025.
    goto :FAIL
)

echo [OK] Confirmado SQL Server 2025.
echo.

REM ============================================================
REM 9/9 - SSMS
REM ============================================================
echo [9/9] Comprobando/instalando SSMS 22...

set "SSMS_EXE="
call :FIND_SSMS

if defined SSMS_EXE (
    echo [OK] SSMS ya existe:
    echo      !SSMS_EXE!
    set "SSMS_STATUS=OK"
) else (
    where winget.exe >nul 2>&1
    if errorlevel 1 (
        set "SSMS_STATUS=REVISAR"
        echo [AVISO] WinGet no esta disponible para instalar SSMS.
    ) else (
        winget source update --name winget >nul 2>&1

        winget install --id Microsoft.SQLServerManagementStudio.22 -e ^
          --source winget ^
          --silent --disable-interactivity ^
          --accept-package-agreements --accept-source-agreements

        set "SSMSRC=!errorlevel!"
        >>"%LOG%" echo SSMS RC=!SSMSRC!

        timeout /t 5 /nobreak >nul
        call :FIND_SSMS

        if defined SSMS_EXE (
            set "SSMS_STATUS=OK"
        ) else (
            set "SSMS_STATUS=REVISAR"
        )
    )
)

>"%RESULT%" echo SQL SERVER 2025 - RESULTADO
>>"%RESULT%" echo Equipo=%COMPUTERNAME%
>>"%RESULT%" echo Estado=OK
>>"%RESULT%" echo Instancia=%INSTANCE%
>>"%RESULT%" echo Servidor=%SERVER%
>>"%RESULT%" echo Servicio=%SERVICE%
>>"%RESULT%" echo Version=!SQLVER!
>>"%RESULT%" echo Edicion=!SQLED!
>>"%RESULT%" echo Nivel=!SQLLEVEL!
>>"%RESULT%" echo SSMS=!SSMS_STATUS!
>>"%RESULT%" echo SSMSPath=!SSMS_EXE!

echo.
echo ============================================================
echo [OK] SQL SERVER 2025 QUEDO FUNCIONAL
echo ============================================================
echo Instancia : %INSTANCE%
echo Servidor  : %SERVER%
echo Servicio  : %SERVICE%
echo Version   : !SQLVER!
echo Edicion   : !SQLED!
echo Nivel     : !SQLLEVEL!
echo SSMS      : !SSMS_STATUS!
echo.
echo SQL Server 2022 Express existente se dejo intacto.
echo.
echo Resultado:
echo   %RESULT%
echo.
pause
exit /b 0


:FIND_SSMS
set "SSMS_EXE="
for /f "usebackq delims=" %%F in (`powershell.exe -NoProfile -Command "$roots=@($env:ProgramFiles,${env:ProgramFiles(x86)}); foreach($r in $roots){if($r){$f=Get-ChildItem -Path $r -Filter 'Ssms.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1; if($f){$f.FullName;break}}}"`) do (
    if not defined SSMS_EXE set "SSMS_EXE=%%F"
)
exit /b 0


:FAIL
if defined ISO powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Dismount-DiskImage -ImagePath '!ISO!' -ErrorAction SilentlyContinue" >nul 2>&1

>"%RESULT%" echo SQL SERVER 2025 - RESULTADO
>>"%RESULT%" echo Equipo=%COMPUTERNAME%
>>"%RESULT%" echo Estado=ERROR
>>"%RESULT%" echo Instancia=%INSTANCE%
>>"%RESULT%" echo Log=%LOG%

echo.
echo ============================================================
echo [ERROR] SQL SERVER 2025 NO QUEDO VERIFICADO
echo ============================================================
echo.
echo Esta version descarga especificamente medio EN-US.
echo.
echo Log del BAT:
echo   %LOG%
echo.
echo Logs oficiales:
echo   C:\Program Files\Microsoft SQL Server\170\Setup Bootstrap\Log
echo.
pause
exit /b 1
