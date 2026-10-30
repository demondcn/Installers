@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title Configurar ESTUDIANTE en SQL Server 2025

REM ============================================================
REM Configura COMPUTERNAME\ESTUDIANTE en localhost\SQL2025
REM - Auto-elevacion
REM - Verifica servicio MSSQL$SQL2025
REM - Verifica que exista el usuario local ESTUDIANTE
REM - Crea LOGIN de Windows si hace falta
REM - Agrega el login al rol dbcreator
REM - Verifica permisos
REM - Prueba REAL: crea y elimina una base temporal como ESTUDIANTE
REM ============================================================

fltmc >nul 2>&1
if not "%errorlevel%"=="0" (
    echo Solicitando permisos de administrador...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "SERVER=localhost\SQL2025"
set "SERVICE=MSSQL$SQL2025"
set "TARGET=%COMPUTERNAME%\ESTUDIANTE"
set "LOGDIR=C:\Software_Logs"
set "LOG=%LOGDIR%\SQL2025_ESTUDIANTE_%COMPUTERNAME%.log"
set "RESULT=%LOGDIR%\SQL2025_ESTUDIANTE_resultado_%COMPUTERNAME%.txt"

if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1

cls
echo ============================================================
echo  SQL SERVER 2025 - CONFIGURAR USUARIO ESTUDIANTE
echo ============================================================
echo Equipo   : %COMPUTERNAME%
echo Servidor : %SERVER%
echo Usuario  : %TARGET%
echo.

>>"%LOG%" echo ============================================================
>>"%LOG%" echo %date% %time% - Inicio
>>"%LOG%" echo Servidor=%SERVER%
>>"%LOG%" echo Usuario=%TARGET%

REM ---------------- 1/5 SERVICIO ----------------
echo [1/5] Verificando servicio SQL2025...

sc query "%SERVICE%" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] No existe el servicio %SERVICE%.
    >>"%LOG%" echo ERROR - Servicio %SERVICE% no encontrado
    goto :FAIL
)

powershell.exe -NoProfile -Command "Start-Service -Name '%SERVICE%' -ErrorAction SilentlyContinue" >nul 2>&1
timeout /t 3 /nobreak >nul

set "STATUS="
for /f "usebackq delims=" %%S in (`powershell.exe -NoProfile -Command "(Get-Service -Name '%SERVICE%' -ErrorAction SilentlyContinue).Status"`) do set "STATUS=%%S"

echo Estado: !STATUS!
if /I not "!STATUS!"=="Running" (
    echo [ERROR] SQL2025 no esta en estado Running.
    >>"%LOG%" echo ERROR - Servicio estado !STATUS!
    goto :FAIL
)

echo [OK] Servicio funcionando.
echo.

REM ---------------- 2/5 USUARIO WINDOWS ----------------
echo [2/5] Verificando usuario local ESTUDIANTE...

net user ESTUDIANTE >nul 2>&1
if errorlevel 1 (
    echo [ERROR] No existe el usuario local:
    echo   %TARGET%
    echo.
    echo Este BAT no crea usuarios de Windows.
    >>"%LOG%" echo ERROR - Usuario Windows %TARGET% no existe
    goto :FAIL
)

echo [OK] Usuario encontrado: %TARGET%
echo.

REM ---------------- 3/5 LOGIN + DBCREATOR ----------------
echo [3/5] Creando/verificando login y rol dbcreator...

set "PSFILE=%TEMP%\sql2025_config_%RANDOM%.ps1"

> "%PSFILE%" echo $ErrorActionPreference='Stop'
>>"%PSFILE%" echo $server='%SERVER%'
>>"%PSFILE%" echo $login='%TARGET%'
>>"%PSFILE%" echo $cn=New-Object System.Data.SqlClient.SqlConnection("Server=$server;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;Connection Timeout=15")
>>"%PSFILE%" echo $cn.Open()
>>"%PSFILE%" echo try {
>>"%PSFILE%" echo   $safe=$login.Replace(']',']]')
>>"%PSFILE%" echo   $lit=$login.Replace(,'')
>>"%PSFILE%" echo   $cmd=$cn.CreateCommand()
>>"%PSFILE%" echo   $cmd.CommandText="IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name=N'$lit') CREATE LOGIN [$safe] FROM WINDOWS;"
>>"%PSFILE%" echo   [void]$cmd.ExecuteNonQuery()
>>"%PSFILE%" echo   $cmd.CommandText="IF ISNULL(IS_SRVROLEMEMBER('dbcreator',N'$lit'),0) ^<^> 1 ALTER SERVER ROLE [dbcreator] ADD MEMBER [$safe];"
>>"%PSFILE%" echo   [void]$cmd.ExecuteNonQuery()
>>"%PSFILE%" echo } finally { $cn.Close() }

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PSFILE%" >>"%LOG%" 2>&1
set "CFGRC=!errorlevel!"
del /q "%PSFILE%" >nul 2>&1

if not "!CFGRC!"=="0" (
    echo [ERROR] No pude configurar el login en SQL Server.
    echo.
    echo La cuenta usada para ejecutar este BAT debe tener permisos
    echo sysadmin en localhost\SQL2025.
    echo.
    echo Log:
    echo   %LOG%
    goto :FAIL
)

echo [OK] Login y dbcreator configurados.
echo.

REM ---------------- 4/5 VERIFICAR ----------------
echo [4/5] Verificando permisos...

set "VF=%TEMP%\sql2025_verify_%RANDOM%.txt"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $login='%TARGET%'; $cn=New-Object System.Data.SqlClient.SqlConnection('Server=%SERVER%;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;Connection Timeout=15'); $cn.Open(); $cmd=$cn.CreateCommand(); $cmd.CommandText='SELECT CASE WHEN EXISTS(SELECT 1 FROM sys.server_principals WHERE name=@n) THEN 1 ELSE 0 END, ISNULL(IS_SRVROLEMEMBER(''dbcreator'',@n),0)'; [void]$cmd.Parameters.Add('@n',[System.Data.SqlDbType]::NVarChar,256); $cmd.Parameters['@n'].Value=$login; $r=$cmd.ExecuteReader(); if($r.Read()){Set-Content -LiteralPath '%VF%' -Value ($r.GetInt32(0).ToString()+'|'+$r.GetInt32(1).ToString()) -Encoding ASCII}; $r.Close(); $cn.Close()" >>"%LOG%" 2>&1

if errorlevel 1 goto :FAIL
if not exist "%VF%" goto :FAIL

set "CHECK="
set /p CHECK=<"%VF%"
del /q "%VF%" >nul 2>&1

for /f "tokens=1,2 delims=|" %%A in ("!CHECK!") do (
    set "LOGINOK=%%A"
    set "ROLEOK=%%B"
)

echo Login existe : !LOGINOK!
echo dbcreator     : !ROLEOK!

if not "!LOGINOK!"=="1" goto :FAIL
if not "!ROLEOK!"=="1" goto :FAIL

echo [OK] Permisos confirmados.
echo.

REM ---------------- 5/5 PRUEBA REAL ----------------
echo [5/5] Probando CREATE DATABASE como ESTUDIANTE...

set "TESTDB=BAT_PRUEBA_%RANDOM%_%RANDOM%"
set "PSFILE=%TEMP%\sql2025_test_%RANDOM%.ps1"

> "%PSFILE%" echo $ErrorActionPreference='Stop'
>>"%PSFILE%" echo $server='%SERVER%'
>>"%PSFILE%" echo $login='%TARGET%'
>>"%PSFILE%" echo $db='%TESTDB%'
>>"%PSFILE%" echo $cn=New-Object System.Data.SqlClient.SqlConnection("Server=$server;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;Connection Timeout=15")
>>"%PSFILE%" echo $cn.Open()
>>"%PSFILE%" echo try {
>>"%PSFILE%" echo   $lit=$login.Replace(,'')
>>"%PSFILE%" echo   $cmd=$cn.CreateCommand()
>>"%PSFILE%" echo   $cmd.CommandText="EXECUTE AS LOGIN = N'$lit';"
>>"%PSFILE%" echo   [void]$cmd.ExecuteNonQuery()
>>"%PSFILE%" echo   $cmd.CommandText="CREATE DATABASE [$db];"
>>"%PSFILE%" echo   [void]$cmd.ExecuteNonQuery()
>>"%PSFILE%" echo   $cmd.CommandText="REVERT;"
>>"%PSFILE%" echo   [void]$cmd.ExecuteNonQuery()
>>"%PSFILE%" echo   $cmd.CommandText="ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db];"
>>"%PSFILE%" echo   [void]$cmd.ExecuteNonQuery()
>>"%PSFILE%" echo } catch {
>>"%PSFILE%" echo   try {
>>"%PSFILE%" echo     $c=$cn.CreateCommand()
>>"%PSFILE%" echo     $c.CommandText="BEGIN TRY REVERT; END TRY BEGIN CATCH END CATCH; IF DB_ID(N'$db') IS NOT NULL BEGIN ALTER DATABASE [$db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$db]; END"
>>"%PSFILE%" echo     [void]$c.ExecuteNonQuery()
>>"%PSFILE%" echo   } catch {}
>>"%PSFILE%" echo   throw
>>"%PSFILE%" echo } finally { $cn.Close() }

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PSFILE%" >>"%LOG%" 2>&1
set "TESTRC=!errorlevel!"
del /q "%PSFILE%" >nul 2>&1

if not "!TESTRC!"=="0" (
    echo [ERROR] El login tiene dbcreator, pero fallo la prueba real.
    echo Revisa:
    echo   %LOG%
    goto :FAIL
)

echo [OK] ESTUDIANTE pudo crear una base temporal.
echo [OK] La base temporal fue eliminada.
echo.

REM ---------------- RESULTADO ----------------
>"%RESULT%" echo SQL2025 - CONFIGURACION ESTUDIANTE
>>"%RESULT%" echo Equipo=%COMPUTERNAME%
>>"%RESULT%" echo Estado=OK
>>"%RESULT%" echo Servidor=%SERVER%
>>"%RESULT%" echo Login=%TARGET%
>>"%RESULT%" echo dbcreator=SI
>>"%RESULT%" echo PruebaCreateDatabase=OK
>>"%RESULT%" echo Log=%LOG%

echo ============================================================
echo [OK] ESTUDIANTE LISTO PARA SQL SERVER 2025
echo ============================================================
echo.
echo Servidor:
echo   %SERVER%
echo.
echo Login SQL : OK
echo dbcreator : OK
echo Crear BD  : OK
echo.
echo Inicia sesion como ESTUDIANTE y en SSMS conecta a:
echo   %SERVER%
echo.
echo Autenticacion:
echo   Windows Authentication
echo.
echo Resultado:
echo   %RESULT%
echo.
pause
exit /b 0

:FAIL
>"%RESULT%" echo SQL2025 - CONFIGURACION ESTUDIANTE
>>"%RESULT%" echo Equipo=%COMPUTERNAME%
>>"%RESULT%" echo Estado=ERROR
>>"%RESULT%" echo Servidor=%SERVER%
>>"%RESULT%" echo Login=%TARGET%
>>"%RESULT%" echo Log=%LOG%

echo.
echo ============================================================
echo [ERROR] NO SE PUDO CONFIGURAR ESTUDIANTE
echo ============================================================
echo.
echo Revisa:
echo   %LOG%
echo.
pause
exit /b 1
