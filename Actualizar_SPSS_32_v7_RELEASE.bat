@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

title Actualizacion IBM SPSS Statistics 32

REM ============================================================
REM IBM SPSS Statistics 32 - REEMPLAZO AUTOMATICO v7 RELEASE
REM
REM Flujo:
REM   1) Doble clic -> solicita UAC automaticamente.
REM   2) Detecta versiones ANTERIORES de IBM SPSS Statistics.
REM   3) Desinstala silenciosamente versiones 1-31.
REM   4) Si SPSS 32 no esta instalado, descarga el instalador
REM      desde GitHub Releases en ESTA MISMA carpeta.
REM   5) Instala SPSS Statistics 32.
REM   6) Verifica que SPSS 32 exista y que no queden versiones viejas.
REM ============================================================

set "PRODUCT_CODE_32={E81723D5-55A2-427D-AA9B-8E63F3F2C387}"
set "INSTALLER=%~dp0SPSSCLT64_v32_MWin_Multi.exe"
set "INSTALLER_URL=https://github.com/demondcn/Installers/releases/latest/download/SPSSCLT64_v32_MWin_Multi.exe"
set "MIN_INSTALLER_BYTES=800000000"
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

    REM --------------------------------------------------------
    REM DESCARGAR INSTALADOR DESDE GITHUB RELEASE SI HACE FALTA
    REM Se guarda junto a este BAT, dentro de Installers.
    REM --------------------------------------------------------
    call :ENSURE_INSTALLER
    set "DOWNLOAD_RC=!errorlevel!"

    if not "!DOWNLOAD_RC!"=="0" (
        echo.
        echo ============================================================
        echo [ERROR] No se pudo obtener un instalador completo de SPSS 32.
        echo ============================================================
        call :WRITE_RESULT "NO_INSTALADA" "ERROR_DESCARGA_INSTALADOR" "!DOWNLOAD_RC!"
        echo.
        echo Puedes volver a ejecutar este BAT para reintentar.
        echo.
        pause
        exit /b 2
    )

    echo Instalador listo:
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
REM ASEGURAR INSTALADOR SPSS 32
REM
REM - Usa el EXE local si ya existe y tiene un tamano razonable.
REM - Si falta o esta incompleto, lo descarga desde GitHub Release.
REM - curl reintenta automaticamente ante errores transitorios.
REM ============================================================
:ENSURE_INSTALLER
set "INSTALLER_OK="

if exist "%INSTALLER%" (
    for %%A in ("%INSTALLER%") do set "INSTALLER_SIZE=%%~zA"
    echo [INFO] Instalador local detectado: !INSTALLER_SIZE! bytes

    if !INSTALLER_SIZE! GEQ %MIN_INSTALLER_BYTES% (
        echo [OK] El instalador local parece completo. No se descargara otra vez.
        set "INSTALLER_OK=1"
    ) else (
        echo [AVISO] El instalador local esta incompleto. Se volvera a descargar.
        del /f /q "%INSTALLER%" >nul 2>&1
    )
)

if defined INSTALLER_OK exit /b 0

where curl.exe >nul 2>&1
if not "%errorlevel%"=="0" (
    echo [ERROR] Windows no encuentra curl.exe.
    exit /b 20
)

echo.
echo ============================================================
echo [DESCARGA] IBM SPSS Statistics 32
echo Archivo aproximado: 830 MB
echo NO CIERRE ESTA VENTANA.
echo ============================================================
echo Origen:
echo   %INSTALLER_URL%
echo Destino:
echo   %INSTALLER%
echo.

REM --retry-all-errors ayuda cuando hay cortes/intermitencia de red.
REM El archivo .part evita confundir una descarga incompleta con el EXE final.
set "PARTIAL=%INSTALLER%.part"
if exist "%PARTIAL%" del /f /q "%PARTIAL%" >nul 2>&1

curl.exe -L --fail --retry 10 --retry-delay 5 --retry-all-errors ^
    --connect-timeout 30 ^
    -o "%PARTIAL%" ^
    "%INSTALLER_URL%"

set "CURL_RC=%errorlevel%"

if not "%CURL_RC%"=="0" (
    echo.
    echo [ERROR] curl finalizo con codigo %CURL_RC%.
    if exist "%PARTIAL%" del /f /q "%PARTIAL%" >nul 2>&1
    exit /b %CURL_RC%
)

if not exist "%PARTIAL%" (
    echo [ERROR] curl termino, pero no se encontro el archivo descargado.
    exit /b 21
)

for %%A in ("%PARTIAL%") do set "INSTALLER_SIZE=%%~zA"
echo.
echo [INFO] Tamano descargado: !INSTALLER_SIZE! bytes

if !INSTALLER_SIZE! LSS %MIN_INSTALLER_BYTES% (
    echo [ERROR] La descarga parece incompleta.
    del /f /q "%PARTIAL%" >nul 2>&1
    exit /b 22
)

move /y "%PARTIAL%" "%INSTALLER%" >nul
if not "%errorlevel%"=="0" (
    echo [ERROR] No se pudo convertir la descarga en el instalador final.
    exit /b 23
)

echo [OK] Instalador descargado correctamente.
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
