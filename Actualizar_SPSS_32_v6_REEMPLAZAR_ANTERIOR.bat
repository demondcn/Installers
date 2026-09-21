@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

title Actualizacion IBM SPSS Statistics 32

REM ============================================================
REM IBM SPSS Statistics 32 - REEMPLAZO AUTOMATICO v6
REM
REM Flujo:
REM   1) Doble clic -> solicita UAC automaticamente.
REM   2) Detecta versiones ANTERIORES de IBM SPSS Statistics.
REM   3) Desinstala silenciosamente versiones 1-31.
REM   4) Instala SPSS Statistics 32 si no esta instalado.
REM   5) Verifica que SPSS 32 exista y que no queden versiones viejas.
REM
REM Debe estar junto a:
REM   SPSSCLT64_v32_MWin_Multi.exe
REM ============================================================

set "PRODUCT_CODE_32={E81723D5-55A2-427D-AA9B-8E63F3F2C387}"
set "INSTALLER=%~dp0SPSSCLT64_v32_MWin_Multi.exe"
set "LOGDIR=C:\SPSS32_Logs"
set "INSTALLLOG=%LOGDIR%\Instalar_SPSS32_%COMPUTERNAME%.log"
set "RESULT=%LOGDIR%\resultado_%COMPUTERNAME%.csv"
set "SPSS_LOGDIR=%LOGDIR%"

REM Licenciamiento opcional. Dejar vacio si se configura despues.
set "LSHOST="
set "AUTHCODE="

REM ------------------------------------------------------------
REM AUTO-ELEVACION
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
echo      IBM SPSS Statistics 32 - REEMPLAZO AUTOMATICO
echo ============================================================
echo Equipo: %COMPUTERNAME%
echo.
echo Este proceso eliminara versiones ANTERIORES de IBM SPSS
echo Statistics y dejara instalada la version 32.
echo.

REM ------------------------------------------------------------
REM 1. DESINSTALAR VERSIONES ANTERIORES
REM ------------------------------------------------------------
echo [1/4] Buscando y eliminando versiones anteriores...
call :UNINSTALL_OLD
set "OLD_RC=!errorlevel!"

if not "!OLD_RC!"=="0" (
    echo.
    echo ============================================================
    echo [ERROR] No se pudieron eliminar todas las versiones antiguas.
    echo No se instalara SPSS 32 para evitar dejar dos versiones.
    echo ============================================================
    call :WRITE_RESULT "NO_VERIFICADA" "ERROR_DESINSTALANDO_VERSION_ANTERIOR" "!OLD_RC!"
    echo.
    echo Revisa los logs en:
    echo   %LOGDIR%
    echo.
    pause
    exit /b 10
)

echo.
echo [OK] No quedan versiones anteriores detectadas.
echo.

REM ------------------------------------------------------------
REM 2. COMPROBAR SPSS 32
REM ------------------------------------------------------------
echo [2/4] Comprobando IBM SPSS Statistics 32...
call :DETECT_SPSS32

if defined SPSS32_VERSION (
    echo [OK] SPSS 32 ya esta instalado. Version: !SPSS32_VERSION!
    echo No es necesario reinstalarlo.
) else (
    echo [INFO] SPSS 32 no esta instalado. Se instalara ahora.
    echo.

    if not exist "%INSTALLER%" (
        set "INSTALLER="
        for %%I in ("%~dp0*SPSSCLT64*v32*MWin*Multi*.exe") do (
            if exist "%%~fI" set "INSTALLER=%%~fI"
        )
    )

    if not defined INSTALLER (
        echo [ERROR] No encuentro SPSSCLT64_v32_MWin_Multi.exe
        echo Debe estar en la misma carpeta que este BAT.
        call :WRITE_RESULT "NO_INSTALADA" "FALTA_INSTALADOR" "2"
        echo.
        pause
        exit /b 2
    )

    if not exist "%INSTALLER%" (
        echo [ERROR] No existe el instalador:
        echo   %INSTALLER%
        call :WRITE_RESULT "NO_INSTALADA" "FALTA_INSTALADOR" "2"
        echo.
        pause
        exit /b 2
    )

    echo Instalador:
    echo   %INSTALLER%
    echo.

    REM --------------------------------------------------------
    REM 3. INSTALAR SPSS 32
    REM --------------------------------------------------------
    echo [3/4] Instalando IBM SPSS Statistics 32...
    echo Esto puede tardar varios minutos. NO cierre esta ventana.
    echo.

    taskkill /IM stats.exe /F >nul 2>&1
    taskkill /IM spssengine.exe /F >nul 2>&1
    taskkill /IM statisticsb.exe /F >nul 2>&1

    set "MSIARGS=/qn /norestart /L*v %INSTALLLOG%"

    if defined LSHOST (
        set "MSIARGS=!MSIARGS! LICENSETYPE=Network LSHOST=%LSHOST%"
    )

    if defined AUTHCODE (
        set "MSIARGS=!MSIARGS! AUTHCODE=%AUTHCODE%"
    )

    start /wait "" "%INSTALLER%" /s /v"!MSIARGS!"
    set "INSTALL_RC=!errorlevel!"

    echo Instalador finalizo con codigo: !INSTALL_RC!

    if not "!INSTALL_RC!"=="0" if not "!INSTALL_RC!"=="3010" (
        echo.
        echo ============================================================
        echo [ERROR] SPSS 32 no pudo instalarse.
        echo Codigo: !INSTALL_RC!
        echo ============================================================
        call :WRITE_RESULT "NO_INSTALADA" "ERROR_INSTALACION" "!INSTALL_RC!"
        echo.
        echo Log:
        echo   %INSTALLLOG%
        echo.
        pause
        exit /b 3
    )

    timeout /t 3 /nobreak >nul
)

REM ------------------------------------------------------------
REM 4. VERIFICACION FINAL
REM ------------------------------------------------------------
echo.
echo [4/4] Verificacion final...
call :DETECT_SPSS32

if not defined SPSS32_VERSION (
    echo.
    echo ============================================================
    echo [ERROR] No se pudo confirmar IBM SPSS Statistics 32.
    echo ============================================================
    call :WRITE_RESULT "NO_DETECTADA" "ERROR_VERIFICACION_SPSS32" "4"
    echo.
    echo Revisa:
    echo   %LOGDIR%
    echo.
    pause
    exit /b 4
)

call :HAS_OLD
set "HAS_OLD_RC=!errorlevel!"

if "!HAS_OLD_RC!"=="1" (
    echo.
    echo ============================================================
    echo [ERROR] SPSS 32 esta instalado, pero aun queda una
    echo version anterior de IBM SPSS Statistics.
    echo ============================================================
    call :WRITE_RESULT "!SPSS32_VERSION!" "SPSS32_OK_PERO_QUEDA_VERSION_ANTERIOR" "5"
    echo.
    pause
    exit /b 5
)

echo.
echo ============================================================
echo [OK] ACTUALIZACION COMPLETADA
echo.
echo IBM SPSS Statistics: !SPSS32_VERSION!
echo Versiones anteriores: ELIMINADAS
echo ============================================================

set "FINALCODE=0"
if defined INSTALL_RC set "FINALCODE=!INSTALL_RC!"

if "!FINALCODE!"=="3010" (
    echo.
    echo [AVISO] Windows recomienda reiniciar el equipo.
    call :WRITE_RESULT "!SPSS32_VERSION!" "ACTUALIZADO_OK_REINICIO_PENDIENTE" "!FINALCODE!"
) else (
    call :WRITE_RESULT "!SPSS32_VERSION!" "ACTUALIZADO_OK" "!FINALCODE!"
)

echo.
echo Resultado:
echo   %RESULT%
echo.
pause
exit /b 0


REM ============================================================
REM DETECTAR SPSS 32 POR PRODUCTCODE
REM ============================================================
:DETECT_SPSS32
set "SPSS32_VERSION="

for /f "usebackq delims=" %%V in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; $wi=New-Object -ComObject WindowsInstaller.Installer; try{$v=$wi.ProductInfo('%PRODUCT_CODE_32%','VersionString'); if($v){[Console]::WriteLine($v)}}catch{}" 2^>nul`) do (
    set "SPSS32_VERSION=%%V"
)

if defined SPSS32_VERSION exit /b 0

for /f "tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\%PRODUCT_CODE_32%" /v DisplayVersion 2^>nul ^| findstr /I /C:"DisplayVersion"') do (
    set "SPSS32_VERSION=%%B"
)

if defined SPSS32_VERSION exit /b 0

for /f "tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\%PRODUCT_CODE_32%" /v DisplayVersion 2^>nul ^| findstr /I /C:"DisplayVersion"') do (
    set "SPSS32_VERSION=%%B"
)

exit /b 0


REM ============================================================
REM DESINSTALAR SOLO EL PRODUCTO PRINCIPAL DE SPSS < 32
REM
REM Evita Get-ItemProperty. Usa Microsoft.Win32.RegistryKey para
REM no fallar por entradas defectuosas del registro.
REM
REM Solo acepta nombres:
REM   IBM SPSS Statistics
REM   IBM SPSS Statistics 29
REM   IBM SPSS Statistics 30.0
REM etc.
REM No toca plugins, Python Essentials, R, License Manager, etc.
REM ============================================================
:UNINSTALL_OLD
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; $failed=$false; $found=$false; $seen=@{}; $views=@([Microsoft.Win32.RegistryView]::Registry64,[Microsoft.Win32.RegistryView]::Registry32); foreach($view in $views){ try{$base=[Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$view);$root=$base.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall');if($root){foreach($sub in $root.GetSubKeyNames()){try{$k=$root.OpenSubKey($sub);$name=[string]$k.GetValue('DisplayName','');$ver=[string]$k.GetValue('DisplayVersion','');$un=[string]$k.GetValue('UninstallString','');$k.Close();$m=[regex]::Match($ver,'^\d+');if($name -match '^IBM SPSS Statistics( [0-9]+(\.[0-9]+)*)?$' -and $m.Success -and [int]$m.Value -lt 32){$guid=$null;if($sub -match '^\{[0-9A-Fa-f-]{36}\}$'){$guid=$sub}elseif($un -match '\{[0-9A-Fa-f-]{36}\}'){$guid=$Matches[0]};if($guid -and -not $seen.ContainsKey($guid)){$seen[$guid]=$true;$found=$true;Write-Host ('  - Eliminando: {0} [{1}]' -f $name,$ver);$safeVer=($ver -replace '[^0-9A-Za-z._-]','_');$log=Join-Path $env:SPSS_LOGDIR ('Desinstalar_SPSS_'+$safeVer+'_'+$env:COMPUTERNAME+'.log');$p=Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/x',$guid,'/qn','/norestart','/L*v',$log) -Wait -PassThru;Write-Host ('    Codigo de desinstalacion: {0}' -f $p.ExitCode);if($p.ExitCode -notin @(0,1605,1614,3010)){$failed=$true}}elseif(-not $guid){Write-Host ('  [ERROR] No se encontro ProductCode MSI para {0} [{1}]' -f $name,$ver);$failed=$true}}}catch{}};$root.Close()};$base.Close()}catch{}};if(-not $found){Write-Host '  - No se encontraron versiones anteriores.'};if($failed){exit 10}else{exit 0}"
exit /b %errorlevel%


REM ============================================================
REM COMPROBAR SI QUEDA ALGUN SPSS PRINCIPAL < 32
REM Retorna 1 si encuentra alguno.
REM ============================================================
:HAS_OLD
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue';$found=$false;$seen=@{};$views=@([Microsoft.Win32.RegistryView]::Registry64,[Microsoft.Win32.RegistryView]::Registry32);foreach($view in $views){try{$base=[Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$view);$root=$base.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall');if($root){foreach($sub in $root.GetSubKeyNames()){try{$k=$root.OpenSubKey($sub);$name=[string]$k.GetValue('DisplayName','');$ver=[string]$k.GetValue('DisplayVersion','');$k.Close();$m=[regex]::Match($ver,'^\d+');if($name -match '^IBM SPSS Statistics( [0-9]+(\.[0-9]+)*)?$' -and $m.Success -and [int]$m.Value -lt 32){$key=$name+'|'+$ver;if(-not $seen.ContainsKey($key)){$seen[$key]=$true;Write-Host ('  - Aun instalada: {0} [{1}]' -f $name,$ver);$found=$true}}}catch{}};$root.Close()};$base.Close()}catch{}};if($found){exit 1}else{exit 0}"
exit /b %errorlevel%


REM ============================================================
REM RESULTADO CSV
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
