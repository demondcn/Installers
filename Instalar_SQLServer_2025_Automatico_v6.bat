@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title SQL Server 2025 Developer + SSMS - Automatico v6

REM ============================================================
REM SQL SERVER 2025 DEVELOPER + SSMS - AUTOMATICO v6
REM
REM OBJETIVO:
REM   Instalar una instancia SQL Server 2025 independiente llamada:
REM       SQL2025
REM   Conexion:
REM       localhost\SQL2025
REM
REM IMPORTANTE:
REM   - NO confunde SQL Server 2022 Express con SQL Server 2025.
REM   - Si existe SQLEXPRESS 2022, lo deja intacto.
REM   - SQL Server 2025 se instala en paralelo.
REM   - SSMS usa SOLO la fuente "winget" (no msstore).
REM ============================================================

REM ---------------- ADMINISTRADOR ----------------
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
set "MEDIA=%WORK%\Media"
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
echo SQL SERVER 2025 DEVELOPER + SSMS - AUTOMATICO v6
echo ============================================================
echo Equipo    : %COMPUTERNAME%
echo Instancia : %INSTANCE%
echo Conexion  : %SERVER%
echo.
>>"%LOG%" echo ============================================================
>>"%LOG%" echo %date% %time% - Inicio v6
>>"%LOG%" echo Equipo=%COMPUTERNAME%

REM ============================================================
REM 1/8 - MOSTRAR SQL EXISTENTE
REM ============================================================
echo [1/8] Revisando instancias SQL existentes...
powershell.exe -NoProfile -Command "Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'MSSQLSERVER' -or $_.Name -like 'MSSQL$*' } | Select-Object Name,Status | Format-Table -AutoSize"
echo.

REM Si nuestra instancia 2025 ya existe, no reinstalar.
sc query "%SERVICE%" >nul 2>&1
if not errorlevel 1 (
    echo [OK] Ya existe la instancia %INSTANCE%.
    goto :START_VERIFY
)

echo [INFO] No existe la instancia %INSTANCE%.
echo SQL Server 2022 Express u otras instancias NO cuentan como SQL 2025.
echo.

REM ============================================================
REM 2/8 - DESCARGAR BOOTSTRAPPER ACTUAL
REM ============================================================
echo [2/8] Descargando instalador oficial SQL Server 2025 Developer...
where curl.exe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] curl.exe no esta disponible.
    goto :FAIL
)

if exist "%BOOT%" del /q "%BOOT%" >nul 2>&1

curl.exe --fail --location --retry 3 --retry-delay 5 --progress-bar ^
  --output "%BOOT%" "%SQLURL%"

if errorlevel 1 (
    echo [ERROR] No se pudo descargar el bootstrapper oficial.
    goto :FAIL
)

for %%F in ("%BOOT%") do set "BOOTSIZE=%%~zF"
if !BOOTSIZE! LSS 1000000 (
    echo [ERROR] La descarga parece invalida: !BOOTSIZE! bytes.
    goto :FAIL
)

echo [OK] Bootstrapper descargado.
echo.

REM ============================================================
REM 3/8 - DESCARGAR ISO
REM ============================================================
echo [3/8] Descargando medio ISO de SQL Server 2025...
echo Esta es la parte pesada de la descarga.
echo.

REM No se pasa IACCEPTSQLSERVERLICENSETERMS aqui:
REM Microsoft no lo permite con ACTION=Download.
start /wait "" "%BOOT%" ^
  /ACTION=Download ^
  /MEDIAPATH="%MEDIA%" ^
  /MEDIATYPE=ISO ^
  /QUIET

set "DLRC=!errorlevel!"
>>"%LOG%" echo Download RC=!DLRC!

if not "!DLRC!"=="0" (
    echo [ERROR] La descarga del medio devolvio codigo !DLRC!.
    goto :FAIL
)

set "ISO="
for /r "%MEDIA%" %%F in (*.iso) do (
    if exist "%%~fF" if not defined ISO set "ISO=%%~fF"
)

if not defined ISO (
    echo [ERROR] El descargador termino pero no encuentro ningun ISO.
    echo Carpeta:
    echo   %MEDIA%
    goto :FAIL
)

echo [OK] ISO:
echo      !ISO!
echo.

REM ============================================================
REM 4/8 - MONTAR ISO
REM ============================================================
echo [4/8] Montando ISO...

set "DRIVE="
for /f "usebackq delims=" %%D in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$img=Mount-DiskImage -ImagePath '!ISO!' -PassThru; Start-Sleep -Seconds 3; $v=$img | Get-Volume; if($v){$v.DriveLetter}"`) do (
    if not defined DRIVE set "DRIVE=%%D"
)

if not defined DRIVE (
    echo [ERROR] No pude obtener la letra del ISO montado.
    goto :FAIL
)

set "SETUP=!DRIVE!:\setup.exe"
if not exist "!SETUP!" (
    echo [ERROR] No encuentro !SETUP!
    goto :FAIL
)

echo [OK] Setup: !SETUP!
echo.

REM ============================================================
REM 5/8 - INSTALAR SQL 2025
REM ============================================================
echo [5/8] Instalando SQL Server 2025 Developer...
echo.
echo Se mostrara una interfaz basica de progreso.
echo No requiere seleccionar opciones.
echo.

set "SQLADMIN=%USERDOMAIN%\%USERNAME%"

start /wait "" "!SETUP!" ^
  /QS ^
  /ACTION=Install ^
  /FEATURES=SQLEngine ^
  /INSTANCENAME=%INSTANCE% ^
  /SQLSYSADMINACCOUNTS="%SQLADMIN%" ^
  /IACCEPTSQLSERVERLICENSETERMS ^
  /SUPPRESSPRIVACYSTATEMENTNOTICE ^
  /TCPENABLED=1 ^
  /NPENABLED=0 ^
  /UpdateEnabled=True

set "SQLRC=!errorlevel!"
>>"%LOG%" echo SQL Setup RC=!SQLRC!

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Dismount-DiskImage -ImagePath '!ISO!' -ErrorAction SilentlyContinue" >nul 2>&1

echo.
echo Codigo SQL Setup: !SQLRC!

if not "!SQLRC!"=="0" if not "!SQLRC!"=="3010" (
    echo [ERROR] SQL Server Setup fallo.
    goto :FAIL
)

REM ============================================================
REM 6/8 - SERVICIO
REM ============================================================
:START_VERIFY
echo.
echo [6/8] Verificando servicio %SERVICE%...

sc query "%SERVICE%" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] No existe el servicio %SERVICE%.
    goto :FAIL
)

powershell.exe -NoProfile -Command "Start-Service -Name '%SERVICE%' -ErrorAction SilentlyContinue" >nul 2>&1
timeout /t 5 /nobreak >nul

set "SQL_STATUS="
for /f "usebackq delims=" %%S in (`powershell.exe -NoProfile -Command "(Get-Service -Name '%SERVICE%' -ErrorAction SilentlyContinue).Status"`) do set "SQL_STATUS=%%S"

echo Estado: !SQL_STATUS!

if /I not "!SQL_STATUS!"=="Running" (
    echo [ERROR] %SERVICE% no esta Running.
    goto :FAIL
)

REM ============================================================
REM 7/8 - CONEXION + VERSION
REM ============================================================
echo.
echo [7/8] Comprobando que realmente sea SQL Server 2025...

set "VERIFY=%TEMP%\sql2025_verify_%RANDOM%.txt"
if exist "%VERIFY%" del /q "%VERIFY%" >nul 2>&1

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $cn=New-Object System.Data.SqlClient.SqlConnection('Server=%SERVER%;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;Connection Timeout=20'); $cn.Open(); $cmd=$cn.CreateCommand(); $cmd.CommandText='SELECT CAST(SERVERPROPERTY(''ProductVersion'') AS nvarchar(50))+''@@''+CAST(SERVERPROPERTY(''Edition'') AS nvarchar(150))+''@@''+CAST(SERVERPROPERTY(''ProductLevel'') AS nvarchar(50))'; $r=$cmd.ExecuteScalar(); $cn.Close(); Set-Content -LiteralPath '%VERIFY%' -Value $r -Encoding ASCII" >>"%LOG%" 2>&1

if errorlevel 1 (
    echo [ERROR] El servicio corre, pero no pude conectarme a %SERVER%.
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

echo [OK] Confirmado: SQL Server 2025 (17.x).
echo.

REM ============================================================
REM 8/8 - SSMS
REM ============================================================
echo [8/8] Instalando/comprobando SSMS 22...

set "SSMS_EXE="
call :FIND_SSMS

if defined SSMS_EXE (
    echo [OK] SSMS ya existe:
    echo      !SSMS_EXE!
    set "SSMS_STATUS=OK"
) else (
    where winget.exe >nul 2>&1
    if errorlevel 1 (
        echo [AVISO] No hay WinGet para instalar SSMS.
        set "SSMS_STATUS=REVISAR"
    ) else (
        REM Forzar solo la fuente winget evita el fallo de region de msstore.
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
            echo [OK] SSMS instalado.
        ) else (
            set "SSMS_STATUS=REVISAR"
            echo [AVISO] SQL Server 2025 funciona, pero SSMS no fue confirmado.
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
echo NOTA:
echo SQL Server 2022 Express puede seguir instalado como SQLEXPRESS.
echo No interfiere con esta instancia SQL2025.
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
echo Lo que buscamos especificamente es:
echo   Servicio : %SERVICE%
echo   Servidor : %SERVER%
echo   Version  : 17.x
echo.
echo El SQLEXPRESS 16.x que ya exista es SQL Server 2022,
echo y NO se toma como instalacion 2025.
echo.
echo Log:
echo   %LOG%
echo.
echo Logs oficiales SQL 2025:
echo   C:\Program Files\Microsoft SQL Server\170\Setup Bootstrap\Log
echo.
pause
exit /b 1
