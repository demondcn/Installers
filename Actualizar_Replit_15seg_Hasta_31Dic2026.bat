@echo off
setlocal
chcp 65001 >nul
title Replit - Instalar tarea hasta el 31-12-2026
echo.
echo ================================================
echo   REPLIT EN CHROME AL INICIAR SESION
 echo   Vigente hasta el 31 de diciembre de 2026
 echo ================================================
echo.
set "REPLIT_INSTALLER=%~f0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$content=[System.IO.File]::ReadAllText($env:REPLIT_INSTALLER); $marker='REM ##### INICIO_POWERSHELL #####'; $index=$content.LastIndexOf($marker); if($index -lt 0){throw 'No se encontro el instalador interno.'}; Invoke-Expression $content.Substring($index+$marker.Length)"
set "REPLIT_EXIT=%ERRORLEVEL%"
echo.
if not "%REPLIT_EXIT%"=="0" (
    echo [ERROR] No se pudo instalar la tarea. Mira el mensaje anterior.
    echo La cuenta puede tener bloqueado el Programador de tareas.
) else (
    echo [OK] Instalacion finalizada.
)
echo.
pause
exit /b %REPLIT_EXIT%
REM ##### INICIO_POWERSHELL #####
$ErrorActionPreference = 'Stop'
$taskName = 'Replit_Chrome_Hasta_31Dic2026'
$expires = [datetime]'2027-01-01T00:00:00'
$delay = 'PT15S'  # Espera 15 segundos tras el inicio de sesion.
$url = 'https://apps-script-frontend.replit.app/'

if ((Get-Date) -ge $expires) {
    Write-Host '[ERROR] Ya paso la fecha de vencimiento (31/12/2026).'
    exit 2
}

try {
    # Archivo permanente: no lo guardamos en Escritorio/Descargas/Documentos.
    $dir = Join-Path $env:LOCALAPPDATA 'Replit_Inicio_2026'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $runner = Join-Path $dir 'Ejecutar_Replit.ps1'

    $runnerContent = @'
$ErrorActionPreference = 'Stop'
$taskName = 'Replit_Chrome_Hasta_31Dic2026'
$expires = [datetime]'2027-01-01T00:00:00'
$url = 'https://apps-script-frontend.replit.app/'

if ((Get-Date) -ge $expires) {
    try {
        $service = New-Object -ComObject 'Schedule.Service'
        $service.Connect()
        $service.GetFolder('\').GetTask($taskName).Enabled = $false
    } catch {
        # El limite de fecha del desencadenador ya impide nuevas aperturas.
    }
    exit 0
}

$chromeLocations = @(
    (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'),
    (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe')
)
$chrome = $chromeLocations | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if ($chrome) {
    Start-Process -FilePath $chrome -ArgumentList $url
} else {
    $chromeCmd = Get-Command chrome.exe -ErrorAction SilentlyContinue
    if ($chromeCmd) {
        Start-Process -FilePath $chromeCmd.Source -ArgumentList $url
    } else {
        throw 'No se encontro Google Chrome en las rutas habituales.'
    }
}
'@

    Set-Content -LiteralPath $runner -Value $runnerContent -Encoding UTF8 -Force

    # Crear una tarea solo para el usuario que ejecuta el BAT, sin elevacion.
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $service = New-Object -ComObject 'Schedule.Service'
    $service.Connect()
    $folder = $service.GetFolder('\')
    $definition = $service.NewTask(0)
    $definition.RegistrationInfo.Description = 'Abre Replit en Chrome al iniciar sesion (15 segundos de espera). Caduca el 31-12-2026 y se deshabilita el 01-01-2027.'
    $definition.Principal.UserId = $sid
    $definition.Principal.LogonType = 3  # InteractiveToken: no pide contrasena
    $definition.Principal.RunLevel = 0   # LeastPrivilege: no administrador

    $definition.Settings.Enabled = $true
    $definition.Settings.StartWhenAvailable = $true
    $definition.Settings.DisallowStartIfOnBatteries = $false
    $definition.Settings.StopIfGoingOnBatteries = $false
    $definition.Settings.ExecutionTimeLimit = 'PT2M'
    $definition.Settings.MultipleInstances = 2 # IgnoreNew

    # Inicio de sesion, limitado hasta las 00:00 del 1 de enero.
    $atLogin = $definition.Triggers.Create(9) # TASK_TRIGGER_LOGON
    $atLogin.UserId = $sid
    $atLogin.StartBoundary = (Get-Date).AddMinutes(-1).ToString('yyyy-MM-ddTHH:mm:ss')
    $atLogin.EndBoundary = $expires.ToString('yyyy-MM-ddTHH:mm:ss')
    $atLogin.Delay = $delay
    $atLogin.Enabled = $true

    # Al comenzar el 2027, el mismo ejecutor se deshabilita a si mismo.
    # Si Windows esta apagado, StartWhenAvailable intenta ejecutarlo luego.
    $atExpiry = $definition.Triggers.Create(1) # TASK_TRIGGER_TIME
    $atExpiry.StartBoundary = $expires.ToString('yyyy-MM-ddTHH:mm:ss')
    $atExpiry.Enabled = $true

    $action = $definition.Actions.Create(0) # TASK_ACTION_EXEC
    $action.Path = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $action.Arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $runner + '"'

    $folder.RegisterTaskDefinition($taskName, $definition, 6, $null, $null, 3, $null) | Out-Null
    $installed = $folder.GetTask($taskName)
    Write-Host ('[OK] Tarea creada: ' + $taskName)
    Write-Host '[OK] Se ejecuta para el usuario actual al iniciar sesion.'
    Write-Host '[OK] Retraso: 15 segundos tras iniciar sesion.'
    Write-Host '[OK] Ultimo dia de apertura: 31/12/2026.'
    Write-Host '[OK] Desde 01/01/2027 no abre el sitio y busca deshabilitarse.'
    Write-Host ('[OK] Archivo de ejecucion: ' + $runner)
    Write-Host '[INFO] Puedes verla en Win+R > taskschd.msc'
    Write-Host ('[INFO] Para quitarla: schtasks /delete /tn "' + $taskName + '" /f')
} catch {
    Write-Host ('[ERROR] ' + $_.Exception.Message)
    exit 1
}
