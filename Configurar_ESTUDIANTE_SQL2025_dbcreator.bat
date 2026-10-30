@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title Recuperar acceso SQL2025 y configurar ESTUDIANTE

REM ============================================================
REM SQL SERVER 2025 - RECUPERAR SYSADMIN + CONFIGURAR ESTUDIANTE
REM
REM Uso:
REM   Doble clic -> aceptar UAC / credenciales de administrador.
REM
REM Hace:
REM   1) Verifica MSSQL$SQL2025 y el usuario local ESTUDIANTE.
REM   2) Intenta configurar normalmente.
REM   3) Si el administrador actual NO es sysadmin:
REM        - detiene SQL Server Agent (si existe)
REM        - reinicia SQL2025 temporalmente con /mSQLCMD
REM        - agrega al administrador actual como sysadmin
REM        - crea EQUIPO\ESTUDIANTE
REM        - agrega ESTUDIANTE a dbcreator
REM        - reinicia SQL2025 en modo normal
REM   4) Verifica login + dbcreator.
REM   5) Prueba realmente CREATE DATABASE como ESTUDIANTE
REM      y elimina la base temporal.
REM
REM No elimina bases existentes.
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
set "LOG=%LOGDIR%\SQL2025_RECUPERAR_%COMPUTERNAME%.log"
set "RESULT=%LOGDIR%\SQL2025_RECUPERAR_resultado_%COMPUTERNAME%.txt"

if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1

cls
echo ============================================================
echo   SQL2025 - RECUPERAR ACCESO Y CONFIGURAR ESTUDIANTE
echo ============================================================
echo Equipo        : %COMPUTERNAME%
echo Servidor      : %SERVER%
echo Administrador : %ADMIN%
echo Estudiante    : %TARGET%
echo.
echo IMPORTANTE: durante la recuperacion SQL2025 se reiniciara.
echo Cierra SSMS y cualquier programa conectado a SQL2025.
echo.

>>"%LOG%" echo ============================================================
>>"%LOG%" echo %date% %time% - Inicio
>>"%LOG%" echo ADMIN=%ADMIN%
>>"%LOG%" echo TARGET=%TARGET%

REM ============================================================
REM 1/6 - VALIDACIONES
REM ============================================================
echo [1/6] Verificando SQL2025 y usuario ESTUDIANTE...

sc query "%SERVICE%" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] No existe el servicio %SERVICE%.
    >>"%LOG%" echo ERROR servicio no encontrado
    goto :FAIL
)

net user ESTUDIANTE >nul 2>&1
if errorlevel 1 (
    echo [ERROR] No existe el usuario local %TARGET%.
    >>"%LOG%" echo ERROR usuario ESTUDIANTE no encontrado
    goto :FAIL
)

powershell.exe -NoProfile -Command "Start-Service -Name '%SERVICE%' -ErrorAction SilentlyContinue" >nul 2>&1
timeout /t 3 /nobreak >nul

echo [OK] Servicio y usuario encontrados.
echo.

REM ============================================================
REM 2/6 - INTENTO NORMAL
REM ============================================================
echo [2/6] Comprobando si %ADMIN% ya es sysadmin...

set "PSFILE=%TEMP%\sql2025_normal_%RANDOM%.ps1"

> "%PSFILE%" echo $ErrorActionPreference='Stop'
>>"%PSFILE%" echo $server='%SERVER%'
>>"%PSFILE%" echo $admin='%ADMIN%'
>>"%PSFILE%" echo $target='%TARGET%'
>>"%PSFILE%" echo $cn=New-Object System.Data.SqlClient.SqlConnection("Server=$server;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;Connection Timeout=10")
>>"%PSFILE%" echo try {
>>"%PSFILE%" echo   $cn.Open()
>>"%PSFILE%" echo   $cmd=$cn.CreateCommand()
>>"%PSFILE%" echo   $cmd.CommandText="SELECT ISNULL(IS_SRVROLEMEMBER('sysadmin'),0)"
>>"%PSFILE%" echo   $isAdmin=[int]$cmd.ExecuteScalar()
>>"%PSFILE%" echo   if($isAdmin -ne 1){ exit 20 }
>>"%PSFILE%" echo   $safe=$target.Replace(']',']]')
>>"%PSFILE%" echo   $lit=$target.Replace(,'')
>>"%PSFILE%" echo   $cmd.CommandText="IF NOT EXISTS(SELECT 1 FROM sys.server_principals WHERE name=N'$lit') CREATE LOGIN [$safe] FROM WINDOWS;"
>>"%PSFILE%" echo   [void]$cmd.ExecuteNonQuery()
>>"%PSFILE%" echo   $cmd.CommandText="IF ISNULL(IS_SRVROLEMEMBER('dbcreator',N'$lit'),0) ^<^> 1 ALTER SERVER ROLE [dbcreator] ADD MEMBER [$safe];"
>>"%PSFILE%" echo   [void]$cmd.ExecuteNonQuery()
>>"%PSFILE%" echo   exit 0
>>"%PSFILE%" echo } catch { Write-Error $_; exit 21 } finally { if($cn.State -eq 'Open'){$cn.Close()} }

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PSFILE%" >>"%LOG%" 2>&1
set "NORMALRC=!errorlevel!"
del /q "%PSFILE%" >nul 2>&1

if "!NORMALRC!"=="0" (
    echo [OK] El administrador actual ya tenia sysadmin.
    echo [OK] ESTUDIANTE fue configurado sin recuperacion.
    goto :VERIFY_NORMAL
)

echo [INFO] El administrador actual NO tiene sysadmin.
echo Se iniciara recuperacion oficial en single-user mode.
echo.

REM ============================================================
REM 3/6 - PREPARAR SINGLE USER
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

echo [OK] Servicios detenidos.
echo.

REM ============================================================
REM 4/6 - RECUPERAR SYSADMIN
REM ============================================================
echo [4/6] Arrancando SQL2025 en single-user mode...

REM /mSQLCMD limita la unica conexion permitida a Application Name=SQLCMD.
net start "%SERVICE%" /mSQLCMD >>"%LOG%" 2>&1
if errorlevel 1 (
    echo [ERROR] No pude iniciar SQL2025 en single-user mode.
    goto :RESTORE_NORMAL_FAIL
)

timeout /t 5 /nobreak >nul

set "PSFILE=%TEMP%\sql2025_recovery_%RANDOM%.ps1"

> "%PSFILE%" echo $ErrorActionPreference='Stop'
>>"%PSFILE%" echo $server='%SERVER%'
>>"%PSFILE%" echo $admin='%ADMIN%'
>>"%PSFILE%" echo $target='%TARGET%'
>>"%PSFILE%" echo $cs="Server=$server;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;Connection Timeout=15;Application Name=SQLCMD"
>>"%PSFILE%" echo $cn=New-Object System.Data.SqlClient.SqlConnection($cs)
>>"%PSFILE%" echo $cn.Open()
>>"%PSFILE%" echo try {
>>"%PSFILE%" echo   $cmd=$cn.CreateCommand()
>>"%PSFILE%" echo   $safeAdmin=$admin.Replace(']',']]')
>>"%PSFILE%" echo   $litAdmin=$admin.Replace(,'')
>>"%PSFILE%" echo   $safeTarget=$target.Replace(']',']]')
>>"%PSFILE%" echo   $litTarget=$target.Replace(,'')
>>"%PSFILE%" echo   $cmd.CommandText="IF NOT EXISTS(SELECT 1 FROM sys.server_principals WHERE name=N'$litAdmin') CREATE LOGIN [$safeAdmin] FROM WINDOWS;"
>>"%PSFILE%" echo   [void]$cmd.ExecuteNonQuery()
>>"%PSFILE%" echo   $cmd.CommandText="IF ISNULL(IS_SRVROLEMEMBER('sysadmin',N'$litAdmin'),0) ^<^> 1 ALTER SERVER ROLE [sysadmin] ADD MEMBER [$safeAdmin];"
>>"%PSFILE%" echo   [void]$cmd.ExecuteNonQuery()
>>"%PSFILE%" echo   $cmd.CommandText="IF NOT EXISTS(SELECT 1 FROM sys.server_principals WHERE name=N'$litTarget') CREATE LOGIN [$safeTarget] FROM WINDOWS;"
>>"%PSFILE%" echo   [void]$cmd.ExecuteNonQuery()
>>"%PSFILE%" echo   $cmd.CommandText="IF ISNULL(IS_SRVROLEMEMBER('dbcreator',N'$litTarget'),0) ^<^> 1 ALTER SERVER ROLE [dbcreator] ADD MEMBER [$safeTarget];"
>>"%PSFILE%" echo   [void]$cmd.ExecuteNonQuery()
>>"%PSFILE%" echo } finally { $cn.Close() }

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PSFILE%" >>"%LOG%" 2>&1
set "RECOVERYRC=!errorlevel!"
del /q "%PSFILE%" >nul 2>&1

if not "!RECOVERYRC!"=="0" (
    echo [ERROR] La conexion single-user no pudo completar la recuperacion.
    goto :RESTORE_NORMAL_FAIL
)

echo [OK] %ADMIN% agregado a sysadmin.
echo [OK] %TARGET% agregado a dbcreator.
echo.

REM ============================================================
REM 5/6 - VOLVER A MODO NORMAL
REM ============================================================
echo [5/6] Devolviendo SQL2025 a modo normal...

powershell.exe -NoProfile -Command "Stop-Service -Name '%SERVICE%' -Force -ErrorAction SilentlyContinue" >nul 2>&1
timeout /t 3 /nobreak >nul
powershell.exe -NoProfile -Command "Start-Service -Name '%SERVICE%' -ErrorAction Stop" >>"%LOG%" 2>&1
if errorlevel 1 (
    echo [ERROR] No pude reiniciar SQL2025 en modo normal.
    goto :FAIL
)

timeout /t 5 /nobreak >nul

if "!AGENT_WAS_RUNNING!"=="1" (
    powershell.exe -NoProfile -Command "Start-Service -Name '%AGENT%' -ErrorAction SilentlyContinue" >nul 2>&1
)

echo [OK] SQL2025 nuevamente en modo normal.
echo.

REM ============================================================
REM 6/6 - VERIFICAR Y PROBAR
REM ============================================================
:VERIFY_NORMAL
echo [6/6] Verificando login, rol y CREATE DATABASE...

set "PSFILE=%TEMP%\sql2025_verify_%RANDOM%.ps1"

> "%PSFILE%" echo $ErrorActionPreference='Stop'
>>"%PSFILE%" echo $server='%SERVER%'
>>"%PSFILE%" echo $admin='%ADMIN%'
>>"%PSFILE%" echo $target='%TARGET%'
>>"%PSFILE%" echo $db='BAT_PRUEBA_' + (Get-Random)
>>"%PSFILE%" echo $cn=New-Object System.Data.SqlClient.SqlConnection("Server=$server;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;Connection Timeout=15")
>>"%PSFILE%" echo $cn.Open()
>>"%PSFILE%" echo try {
>>"%PSFILE%" echo   $cmd=$cn.CreateCommand()
>>"%PSFILE%" echo   $lit=$target.Replace(,'')
>>"%PSFILE%" echo   $cmd.CommandText="SELECT CASE WHEN EXISTS(SELECT 1 FROM sys.server_principals WHERE name=N'$lit') THEN 1 ELSE 0 END"
>>"%PSFILE%" echo   if([int]$cmd.ExecuteScalar() -ne 1){ throw 'Login ESTUDIANTE no existe' }
>>"%PSFILE%" echo   $cmd.CommandText="SELECT ISNULL(IS_SRVROLEMEMBER('dbcreator',N'$lit'),0)"
>>"%PSFILE%" echo   if([int]$cmd.ExecuteScalar() -ne 1){ throw 'ESTUDIANTE no pertenece a dbcreator' }
>>"%PSFILE%" echo   $cmd.CommandText="EXECUTE AS LOGIN=N'$lit';"
>>"%PSFILE%" echo   [void]$cmd.ExecuteNonQuery()
>>"%PSFILE%" echo   $cmd.CommandText="CREATE DATABASE [$db];"
>>"%PSFILE%" echo   [void]$cmd.ExecuteNonQuery()
>>"%PSFILE%" echo   $cmd.CommandText="REVERT;"
>>"%PSFILE%" echo   [void]$cmd.ExecuteNonQuery()
>>"%PSFILE%" echo   $cmd.CommandText="ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db];"
>>"%PSFILE%" echo   [void]$cmd.ExecuteNonQuery()
>>"%PSFILE%" echo } catch {
>>"%PSFILE%" echo   try {
>>"%PSFILE%" echo     $cleanup=$cn.CreateCommand()
>>"%PSFILE%" echo     $cleanup.CommandText="BEGIN TRY REVERT; END TRY BEGIN CATCH END CATCH; IF DB_ID(N'$db') IS NOT NULL BEGIN ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db]; END"
>>"%PSFILE%" echo     [void]$cleanup.ExecuteNonQuery()
>>"%PSFILE%" echo   } catch {}
>>"%PSFILE%" echo   throw
>>"%PSFILE%" echo } finally { $cn.Close() }

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PSFILE%" >>"%LOG%" 2>&1
set "VERIFYRC=!errorlevel!"
del /q "%PSFILE%" >nul 2>&1

if not "!VERIFYRC!"=="0" (
    echo [ERROR] La configuracion se hizo, pero fallo la prueba final.
    echo Revisa:
    echo   %LOG%
    goto :FAIL
)

>"%RESULT%" echo SQL2025 - RECUPERACION Y ESTUDIANTE
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
echo Ahora entra a Windows como ESTUDIANTE y conecta SSMS a:
echo   %SERVER%
echo con Autenticacion de Windows.
echo.
echo Resultado:
echo   %RESULT%
echo.
pause
exit /b 0


:RESTORE_NORMAL_FAIL
echo.
echo Intentando restaurar SQL2025 a modo normal...
powershell.exe -NoProfile -Command "Stop-Service -Name '%SERVICE%' -Force -ErrorAction SilentlyContinue" >nul 2>&1
timeout /t 2 /nobreak >nul
powershell.exe -NoProfile -Command "Start-Service -Name '%SERVICE%' -ErrorAction SilentlyContinue" >nul 2>&1
if "!AGENT_WAS_RUNNING!"=="1" powershell.exe -NoProfile -Command "Start-Service -Name '%AGENT%' -ErrorAction SilentlyContinue" >nul 2>&1
goto :FAIL


:FAIL
>"%RESULT%" echo SQL2025 - RECUPERACION Y ESTUDIANTE
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
echo SQL2025 se intento dejar nuevamente en modo normal.
echo.
echo Revisa:
echo   %LOG%
echo.
pause
exit /b 1
