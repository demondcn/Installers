@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title SQL Server 2025 + SSMS - Automatico v5

fltmc >nul 2>&1
if not "%errorlevel%"=="0" (
  echo Solicitando permisos de administrador...
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

set "LOGDIR=C:\Software_Logs"
set "LOG=%LOGDIR%\SQLServer2025_%COMPUTERNAME%.log"
set "RESULT=%LOGDIR%\SQLServer2025_resultado_%COMPUTERNAME%.txt"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1

cls
echo ============================================================
echo      SQL SERVER 2025 + SSMS - AUTOMATICO v5
echo ============================================================
echo Equipo: %COMPUTERNAME%
echo.

echo [1/6] Comprobando WinGet...
where winget.exe >nul 2>&1
if errorlevel 1 goto :FAIL
for /f "delims=" %%V in ('winget --version 2^>nul') do set "WINGET_VER=%%V"
echo [OK] WinGet !WINGET_VER!
echo.

echo [2/6] Comprobando motor SQL Server...
call :FIND_SQL
if defined SQL_SERVICE (
  echo [OK] Ya existe un motor SQL Server.
  echo      Servicio: !SQL_SERVICE!
  echo      Se omitira su instalacion/actualizacion.
) else (
  echo [INFO] No existe motor SQL. Instalando SQL Server 2025 Developer...
  winget install --id Microsoft.SQLServer.2025.Developer -e --silent --disable-interactivity --no-upgrade --accept-package-agreements --accept-source-agreements
  timeout /t 5 /nobreak >nul
  call :FIND_SQL
  if not defined SQL_SERVICE goto :FAIL
)
echo.

echo [3/6] Comprobando SSMS...
call :FIND_SSMS
if defined SSMS_EXE (
  echo [OK] SSMS ya esta instalado:
  echo      !SSMS_EXE!
) else (
  echo Instalando SSMS 22...
  winget install --id Microsoft.SQLServerManagementStudio.22 -e --silent --disable-interactivity --no-upgrade --accept-package-agreements --accept-source-agreements
  timeout /t 3 /nobreak >nul
  call :FIND_SSMS
)
echo.

echo [4/6] Verificando servicio SQL...
call :FIND_SQL
if not defined SQL_SERVICE goto :FAIL

for /f "usebackq delims=" %%S in (`powershell.exe -NoProfile -Command "(Get-Service -Name '!SQL_SERVICE!' -ErrorAction SilentlyContinue).Status"`) do set "SQL_STATUS=%%S"

if /I not "!SQL_STATUS!"=="Running" (
  powershell.exe -NoProfile -Command "Start-Service -Name '!SQL_SERVICE!' -ErrorAction SilentlyContinue" >nul 2>&1
  timeout /t 5 /nobreak >nul
  for /f "usebackq delims=" %%S in (`powershell.exe -NoProfile -Command "(Get-Service -Name '!SQL_SERVICE!' -ErrorAction SilentlyContinue).Status"`) do set "SQL_STATUS=%%S"
)

echo Servicio: !SQL_SERVICE!
echo Estado  : !SQL_STATUS!
if /I not "!SQL_STATUS!"=="Running" goto :FAIL
echo.

echo [5/6] Probando conexion SQL real...
set "SERVER=localhost"
if /I not "!SQL_SERVICE!"=="MSSQLSERVER" (
  set "INSTANCE=!SQL_SERVICE:MSSQL$=!"
  set "SERVER=localhost\!INSTANCE!"
)

set "VERIFY=%TEMP%\sql_verify_%RANDOM%.txt"
if exist "%VERIFY%" del /q "%VERIFY%" >nul 2>&1

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $cs='Server=!SERVER!;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;Connection Timeout=15'; $cn=New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open(); $cmd=$cn.CreateCommand(); $cmd.CommandText='SELECT CAST(SERVERPROPERTY(''ProductVersion'') AS nvarchar(50)) + ''@@@'' + CAST(SERVERPROPERTY(''Edition'') AS nvarchar(150)) + ''@@@'' + CAST(SERVERPROPERTY(''ProductLevel'') AS nvarchar(50))'; $r=$cmd.ExecuteScalar(); $cn.Close(); Set-Content -LiteralPath '%VERIFY%' -Value $r -Encoding ASCII" >>"%LOG%" 2>&1
if errorlevel 1 goto :FAIL

set "VERIFY_LINE="
set /p VERIFY_LINE=<"%VERIFY%"
del /q "%VERIFY%" >nul 2>&1

for /f "tokens=1,* delims=@" %%A in ("!VERIFY_LINE!") do (
  set "SQL_VERSION=%%A"
  set "REST=%%B"
)
for /f "tokens=1,* delims=@" %%A in ("!REST!") do (
  set "SQL_EDITION=%%A"
  set "SQL_LEVEL=%%B"
)

echo [OK] Conexion SQL correcta.
echo      Servidor : !SERVER!
echo      Version  : !SQL_VERSION!
echo      Edicion  : !SQL_EDITION!
echo      Nivel    : !SQL_LEVEL!
echo.

echo [6/6] Verificando SSMS...
call :FIND_SSMS
if defined SSMS_EXE (set "SSMS_FINAL=OK") else (set "SSMS_FINAL=REVISAR")

>"%RESULT%" echo SQL SERVER - RESULTADO
>>"%RESULT%" echo Equipo=%COMPUTERNAME%
>>"%RESULT%" echo Estado=OK
>>"%RESULT%" echo Servidor=!SERVER!
>>"%RESULT%" echo Servicio=!SQL_SERVICE!
>>"%RESULT%" echo Version=!SQL_VERSION!
>>"%RESULT%" echo Edicion=!SQL_EDITION!
>>"%RESULT%" echo ProductLevel=!SQL_LEVEL!
>>"%RESULT%" echo SSMS=!SSMS_FINAL!
>>"%RESULT%" echo SSMSPath=!SSMS_EXE!

echo.
echo ============================================================
echo [OK] SQL SERVER QUEDO FUNCIONAL
echo ============================================================
echo Servicio : !SQL_SERVICE!
echo Estado   : Running
echo Conexion : OK
echo Version  : !SQL_VERSION!
echo Edicion  : !SQL_EDITION!
echo Nivel    : !SQL_LEVEL!
echo SSMS     : !SSMS_FINAL!
echo.
echo Resultado:
echo   %RESULT%
echo Log:
echo   %LOG%
echo.
pause
exit /b 0

:FIND_SQL
set "SQL_SERVICE="
for /f "usebackq delims=" %%S in (`powershell.exe -NoProfile -Command "$s=Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'MSSQLSERVER' -or $_.Name -like 'MSSQL$*' } | Sort-Object Name | Select-Object -First 1; if($s){$s.Name}"`) do if not defined SQL_SERVICE set "SQL_SERVICE=%%S"
exit /b 0

:FIND_SSMS
set "SSMS_EXE="
for /f "usebackq delims=" %%F in (`powershell.exe -NoProfile -Command "$roots=@($env:ProgramFiles,${env:ProgramFiles(x86)}); foreach($r in $roots){if($r){$f=Get-ChildItem -Path $r -Filter 'Ssms.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1; if($f){$f.FullName;break}}}"`) do if not defined SSMS_EXE set "SSMS_EXE=%%F"
exit /b 0

:FAIL
>"%RESULT%" echo SQL SERVER - RESULTADO
>>"%RESULT%" echo Equipo=%COMPUTERNAME%
>>"%RESULT%" echo Estado=ERROR
>>"%RESULT%" echo Servicio=!SQL_SERVICE!
>>"%RESULT%" echo Log=%LOG%
echo.
echo ============================================================
echo [ERROR] SQL SERVER NO QUEDO VERIFICADO
echo ============================================================
if defined SQL_SERVICE (
  echo El motor SI fue detectado:
  echo   !SQL_SERVICE!
)
echo.
echo Revisa:
echo   %LOG%
echo.
pause
exit /b 1
