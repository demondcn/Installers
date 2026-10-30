@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title SQL2025 - Recuperar acceso y configurar ESTUDIANTE v2

REM ============================================================
REM SQL SERVER 2025 - RECUPERAR SYSADMIN + CONFIGURAR ESTUDIANTE
REM v2 - sin generacion fragil de Replace() en PowerShell
REM
REM Hace:
REM   1) Verifica SQL2025 y usuario ESTUDIANTE.
REM   2) Intenta configurar normalmente.
REM   3) Si el admin actual no es sysadmin:
REM        - detiene SQL Agent si existe
REM        - detiene SQL2025
REM        - inicia SQL2025 en single-user con /mSQLCMD
REM        - conecta usando Application Name=SQLCMD
REM        - agrega el admin actual a sysadmin
REM        - crea ESTUDIANTE y lo agrega a dbcreator
REM        - reinicia SQL2025 normalmente
REM   4) Verifica login y rol.
REM   5) Prueba CREATE DATABASE como ESTUDIANTE.
REM   6) Elimina la base temporal.
REM
REM IMPORTANTE:
REM   Cierra SSMS antes de ejecutar.
REM ============================================================

fltmc >nul 2>&1
if not "%errorlevel%"=="0" (
    echo Solicitando permisos de administrador...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "SERVER=localhost\SQL2025"
set "SERVICE=MSSQL$SQL2025"
set "AGENT=SQLAgent$SQL2025"
set "TARGET=%COMPUTERNAME%\ESTUDIANTE"
set "ADMIN=%USERDOMAIN%\%USERNAME%"
set "LOGDIR=C:\Software_Logs"
set "LOG=%LOGDIR%\SQL2025_RECUPERAR_V2_%COMPUTERNAME%.log"
set "RESULT=%LOGDIR%\SQL2025_RECUPERAR_V2_resultado_%COMPUTERNAME%.txt"

if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1

cls
echo ============================================================
echo SQL2025 - RECUPERAR ACCESO + CONFIGURAR ESTUDIANTE v2
echo ============================================================
echo Equipo        : %COMPUTERNAME%
echo Servidor      : %SERVER%
echo Administrador : %ADMIN%
echo Estudiante    : %TARGET%
echo.
echo Cierra SSMS antes de continuar.
echo.

>>"%LOG%" echo ============================================================
>>"%LOG%" echo %date% %time% - Inicio v2
>>"%LOG%" echo ADMIN=%ADMIN%
>>"%LOG%" echo TARGET=%TARGET%

REM ============================================================
REM 1/6 - VALIDACIONES
REM ============================================================
echo [1/6] Verificando servicio SQL2025 y usuario ESTUDIANTE...

sc query "%SERVICE%" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] No existe el servicio %SERVICE%.
    >>"%LOG%" echo ERROR - Servicio no encontrado
    goto :FAIL
)

net user ESTUDIANTE >nul 2>&1
if errorlevel 1 (
    echo [ERROR] No existe el usuario local %TARGET%.
    >>"%LOG%" echo ERROR - Usuario ESTUDIANTE no encontrado
    goto :FAIL
)

powershell.exe -NoProfile -Command "Start-Service -Name '%SERVICE%' -ErrorAction SilentlyContinue" >nul 2>&1
timeout /t 3 /nobreak >nul

echo [OK] Servicio y usuario encontrados.
echo.

REM ============================================================
REM 2/6 - INTENTO NORMAL
REM ============================================================
echo [2/6] Intentando configuracion normal...

set "PSNORMAL=%TEMP%\sql2025_normal_v2_%RANDOM%.ps1"

> "%PSNORMAL%" echo $ErrorActionPreference = 'Stop'
>>"%PSNORMAL%" echo $server = $env:SQL_SERVER
>>"%PSNORMAL%" echo $admin = $env:SQL_ADMIN
>>"%PSNORMAL%" echo $target = $env:SQL_TARGET
>>"%PSNORMAL%" echo $cn = New-Object System.Data.SqlClient.SqlConnection("Server=$server;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;Connection Timeout=10")
>>"%PSNORMAL%" echo try {
>>"%PSNORMAL%" echo     $cn.Open()
>>"%PSNORMAL%" echo     $cmd = $cn.CreateCommand()
>>"%PSNORMAL%" echo     $cmd.CommandText = "SELECT ISNULL(IS_SRVROLEMEMBER('sysadmin'),0)"
>>"%PSNORMAL%" echo     $isAdmin = [int]$cmd.ExecuteScalar()
>>"%PSNORMAL%" echo     if($isAdmin -ne 1) { exit 20 }
>>"%PSNORMAL%" echo     $cmd.CommandText = "IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$target') CREATE LOGIN [$target] FROM WINDOWS;"
>>"%PSNORMAL%" echo     [void]$cmd.ExecuteNonQuery()
>>"%PSNORMAL%" echo     $cmd.CommandText = "IF ISNULL(IS_SRVROLEMEMBER('dbcreator',N'$target'),0) ^<^> 1 ALTER SERVER ROLE [dbcreator] ADD MEMBER [$target];"
>>"%PSNORMAL%" echo     [void]$cmd.ExecuteNonQuery()
>>"%PSNORMAL%" echo     exit 0
>>"%PSNORMAL%" echo } catch {
>>"%PSNORMAL%" echo     Write-Error $_
>>"%PSNORMAL%" echo     exit 21
>>"%PSNORMAL%" echo } finally {
>>"%PSNORMAL%" echo     if($cn.State -eq 'Open') { $cn.Close() }
>>"%PSNORMAL%" echo }

set "SQL_SERVER=%SERVER%"
set "SQL_ADMIN=%ADMIN%"
set "SQL_TARGET=%TARGET%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PSNORMAL%" >>"%LOG%" 2>&1
set "NORMALRC=!errorlevel!"
del /q "%PSNORMAL%" >nul 2>&1

if "!NORMALRC!"=="0" (
    echo [OK] El administrador actual ya tenia sysadmin.
    echo [OK] ESTUDIANTE fue configurado.
    goto :VERIFY
)

echo [INFO] El administrador actual no tiene sysadmin.
echo Se usara single-user mode para recuperar acceso.
echo.

REM ============================================================
REM 3/6 - DETENER SERVICIOS
REM ============================================================
echo [3/6] Deteniendo servicios SQL2025...

set "AGENT_WAS_RUNNING=0"

sc query "%AGENT%" >nul 2>&1
if not errorlevel 1 (
    for /f "usebackq delims=" %%S in (`powershell.exe -NoProfile -Command "(Get-Service -Name '%AGENT%' -ErrorAction SilentlyContinue).Status"`) do (
        if /I "%%S"=="Running" set "AGENT_WAS_RUNNING=1"
    )
    powershell.exe -NoProfile -Command "Stop-Service -Name '%AGENT%' -Force -ErrorAction SilentlyContinue" >nul 2>&1
)

powershell.exe -NoProfile -Command "Stop-Service -Name '%SERVICE%' -Force -ErrorAction Stop" >>"%LOG%" 2>&1
if errorlevel 1 (
    echo [ERROR] No pude detener %SERVICE%.
    goto :FAIL
)

timeout /t 3 /nobreak >nul
echo [OK] SQL2025 detenido.
echo.

REM ============================================================
REM 4/6 - SINGLE USER + RECUPERAR SYSADMIN
REM ============================================================
echo [4/6] Iniciando SQL2025 en single-user mode...

net start "%SERVICE%" /mSQLCMD >>"%LOG%" 2>&1
if errorlevel 1 (
    echo [ERROR] No pude iniciar SQL2025 en single-user mode.
    goto :RESTORE
)

timeout /t 5 /nobreak >nul

set "PSREC=%TEMP%\sql2025_recovery_v2_%RANDOM%.ps1"

> "%PSREC%" echo $ErrorActionPreference = 'Stop'
>>"%PSREC%" echo $server = $env:SQL_SERVER
>>"%PSREC%" echo $admin = $env:SQL_ADMIN
>>"%PSREC%" echo $target = $env:SQL_TARGET
>>"%PSREC%" echo $cs = "Server=$server;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;Connection Timeout=15;Application Name=SQLCMD"
>>"%PSREC%" echo $cn = New-Object System.Data.SqlClient.SqlConnection($cs)
>>"%PSREC%" echo try {
>>"%PSREC%" echo     $cn.Open()
>>"%PSREC%" echo     $cmd = $cn.CreateCommand()
>>"%PSREC%" echo     $cmd.CommandText = "IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$admin') CREATE LOGIN [$admin] FROM WINDOWS;"
>>"%PSREC%" echo     [void]$cmd.ExecuteNonQuery()
>>"%PSREC%" echo     $cmd.CommandText = "IF ISNULL(IS_SRVROLEMEMBER('sysadmin',N'$admin'),0) ^<^> 1 ALTER SERVER ROLE [sysadmin] ADD MEMBER [$admin];"
>>"%PSREC%" echo     [void]$cmd.ExecuteNonQuery()
>>"%PSREC%" echo     $cmd.CommandText = "IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$target') CREATE LOGIN [$target] FROM WINDOWS;"
>>"%PSREC%" echo     [void]$cmd.ExecuteNonQuery()
>>"%PSREC%" echo     $cmd.CommandText = "IF ISNULL(IS_SRVROLEMEMBER('dbcreator',N'$target'),0) ^<^> 1 ALTER SERVER ROLE [dbcreator] ADD MEMBER [$target];"
>>"%PSREC%" echo     [void]$cmd.ExecuteNonQuery()
>>"%PSREC%" echo     exit 0
>>"%PSREC%" echo } catch {
>>"%PSREC%" echo     Write-Error $_
>>"%PSREC%" echo     exit 30
>>"%PSREC%" echo } finally {
>>"%PSREC%" echo     if($cn.State -eq 'Open') { $cn.Close() }
>>"%PSREC%" echo }

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PSREC%" >>"%LOG%" 2>&1
set "RECOVERYRC=!errorlevel!"
del /q "%PSREC%" >nul 2>&1

if not "!RECOVERYRC!"=="0" (
    echo [ERROR] Fallo la recuperacion en single-user mode.
    goto :RESTORE
)

echo [OK] %ADMIN% agregado a sysadmin.
echo [OK] %TARGET% agregado a dbcreator.
echo.

REM ============================================================
REM 5/6 - VOLVER A NORMAL
REM ============================================================
echo [5/6] Reiniciando SQL2025 en modo normal...

powershell.exe -NoProfile -Command "Stop-Service -Name '%SERVICE%' -Force -ErrorAction SilentlyContinue" >nul 2>&1
timeout /t 3 /nobreak >nul

powershell.exe -NoProfile -Command "Start-Service -Name '%SERVICE%' -ErrorAction Stop" >>"%LOG%" 2>&1
if errorlevel 1 (
    echo [ERROR] No pude iniciar SQL2025 normalmente.
    goto :FAIL
)

timeout /t 5 /nobreak >nul

if "!AGENT_WAS_RUNNING!"=="1" (
    powershell.exe -NoProfile -Command "Start-Service -Name '%AGENT%' -ErrorAction SilentlyContinue" >nul 2>&1
)

echo [OK] SQL2025 nuevamente en modo normal.
echo.

REM ============================================================
REM 6/6 - VERIFICAR + PRUEBA REAL
REM ============================================================
:VERIFY
echo [6/6] Verificando login, dbcreator y CREATE DATABASE...

set "PSVERIFY=%TEMP%\sql2025_verify_v2_%RANDOM%.ps1"

> "%PSVERIFY%" echo $ErrorActionPreference = 'Stop'
>>"%PSVERIFY%" echo $server = $env:SQL_SERVER
>>"%PSVERIFY%" echo $target = $env:SQL_TARGET
>>"%PSVERIFY%" echo $db = 'BAT_PRUEBA_' + (Get-Random -Minimum 10000 -Maximum 99999)
>>"%PSVERIFY%" echo $cn = New-Object System.Data.SqlClient.SqlConnection("Server=$server;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;Connection Timeout=15")
>>"%PSVERIFY%" echo try {
>>"%PSVERIFY%" echo     $cn.Open()
>>"%PSVERIFY%" echo     $cmd = $cn.CreateCommand()
>>"%PSVERIFY%" echo     $cmd.CommandText = "SELECT CASE WHEN EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$target') THEN 1 ELSE 0 END"
>>"%PSVERIFY%" echo     if([int]$cmd.ExecuteScalar() -ne 1) { throw 'Login ESTUDIANTE no existe' }
>>"%PSVERIFY%" echo     $cmd.CommandText = "SELECT ISNULL(IS_SRVROLEMEMBER('dbcreator',N'$target'),0)"
>>"%PSVERIFY%" echo     if([int]$cmd.ExecuteScalar() -ne 1) { throw 'ESTUDIANTE no pertenece a dbcreator' }
>>"%PSVERIFY%" echo     $cmd.CommandText = "EXECUTE AS LOGIN = N'$target';"
>>"%PSVERIFY%" echo     [void]$cmd.ExecuteNonQuery()
>>"%PSVERIFY%" echo     $cmd.CommandText = "CREATE DATABASE [$db];"
>>"%PSVERIFY%" echo     [void]$cmd.ExecuteNonQuery()
>>"%PSVERIFY%" echo     $cmd.CommandText = "REVERT;"
>>"%PSVERIFY%" echo     [void]$cmd.ExecuteNonQuery()
>>"%PSVERIFY%" echo     $cmd.CommandText = "ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db];"
>>"%PSVERIFY%" echo     [void]$cmd.ExecuteNonQuery()
>>"%PSVERIFY%" echo     exit 0
>>"%PSVERIFY%" echo } catch {
>>"%PSVERIFY%" echo     try {
>>"%PSVERIFY%" echo         $cleanup = $cn.CreateCommand()
>>"%PSVERIFY%" echo         $cleanup.CommandText = "BEGIN TRY REVERT; END TRY BEGIN CATCH END CATCH; IF DB_ID(N'$db') IS NOT NULL BEGIN ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db]; END"
>>"%PSVERIFY%" echo         [void]$cleanup.ExecuteNonQuery()
>>"%PSVERIFY%" echo     } catch {}
>>"%PSVERIFY%" echo     Write-Error $_
>>"%PSVERIFY%" echo     exit 40
>>"%PSVERIFY%" echo } finally {
>>"%PSVERIFY%" echo     if($cn.State -eq 'Open') { $cn.Close() }
>>"%PSVERIFY%" echo }

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PSVERIFY%" >>"%LOG%" 2>&1
set "VERIFYRC=!errorlevel!"
del /q "%PSVERIFY%" >nul 2>&1

if not "!VERIFYRC!"=="0" (
    echo [ERROR] Fallo la prueba final.
    echo Revisa:
    echo   %LOG%
    goto :FAIL
)

>"%RESULT%" echo SQL2025 - RECUPERACION Y ESTUDIANTE v2
>>"%RESULT%" echo Equipo=%COMPUTERNAME%
>>"%RESULT%" echo Estado=OK
>>"%RESULT%" echo Servidor=%SERVER%
>>"%RESULT%" echo AdministradorSysadmin=%ADMIN%
>>"%RESULT%" echo Estudiante=%TARGET%
>>"%RESULT%" echo dbcreator=SI
>>"%RESULT%" echo PruebaCreateDatabase=OK
>>"%RESULT%" echo Log=%LOG%

echo.
echo ============================================================
echo [OK] SQL2025 RECUPERADO Y ESTUDIANTE CONFIGURADO
echo ============================================================
echo.
echo Administrador sysadmin:
echo   %ADMIN%
echo.
echo Estudiante:
echo   %TARGET%
echo.
echo Servidor:
echo   %SERVER%
echo.
echo Login ESTUDIANTE : OK
echo dbcreator         : OK
echo Crear base datos  : OK
echo.
echo Ahora inicia sesion como ESTUDIANTE y conecta SSMS a:
echo   %SERVER%
echo.
echo con Autenticacion de Windows.
echo.
echo Resultado:
echo   %RESULT%
echo.
pause
exit /b 0

:RESTORE
echo.
echo Restaurando SQL2025 a modo normal...
powershell.exe -NoProfile -Command "Stop-Service -Name '%SERVICE%' -Force -ErrorAction SilentlyContinue" >nul 2>&1
timeout /t 2 /nobreak >nul
powershell.exe -NoProfile -Command "Start-Service -Name '%SERVICE%' -ErrorAction SilentlyContinue" >nul 2>&1
if "!AGENT_WAS_RUNNING!"=="1" powershell.exe -NoProfile -Command "Start-Service -Name '%AGENT%' -ErrorAction SilentlyContinue" >nul 2>&1
goto :FAIL

:FAIL
>"%RESULT%" echo SQL2025 - RECUPERACION Y ESTUDIANTE v2
>>"%RESULT%" echo Equipo=%COMPUTERNAME%
>>"%RESULT%" echo Estado=ERROR
>>"%RESULT%" echo Servidor=%SERVER%
>>"%RESULT%" echo Administrador=%ADMIN%
>>"%RESULT%" echo Estudiante=%TARGET%
>>"%RESULT%" echo Log=%LOG%

echo.
echo ============================================================
echo [ERROR] NO SE PUDO COMPLETAR LA CONFIGURACION
echo ============================================================
echo.
echo SQL2025 se intento dejar en modo normal.
echo.
echo Revisa:
echo   %LOG%
echo.
pause
exit /b 1
