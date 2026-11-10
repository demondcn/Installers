[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Configure', 'Precheck', 'Install', 'License', 'Verify', 'FinalTest')]
    [string]$Action
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'
$BaseDir = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $BaseDir 'Configuracion.local.json'
$MediaDir = Join-Path $BaseDir 'MEDIA'
$LogDir = 'C:\Software_Logs\SOLIDWORKS'
$MinimumFreeGB = 25 # Politica local; la guia institucional no indica un minimo de disco.

function Write-Status([string]$Kind, [string]$Message) {
    Write-Host ('[{0}] {1}' -f $Kind, $Message)
}

function Ensure-LogDirectory {
    if (-not (Test-Path -LiteralPath $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
}

function Write-DeployLog([string]$Message) {
    Ensure-LogDirectory
    $line = '{0:u} {1}' -f (Get-Date), $Message
    Add-Content -LiteralPath (Join-Path $LogDir ('Despliegue_{0}.log' -f $env:COMPUTERNAME)) -Value $line -Encoding UTF8
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ValidatedServerEntries([string]$ServerList) {
    if ([string]::IsNullOrWhiteSpace($ServerList)) { throw 'El servidor de licencias esta vacio.' }
    $entries = @($ServerList -split '[;,]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($entries.Count -eq 0) { throw 'No se encontro ningun servidor de licencias.' }
    foreach ($entry in $entries) {
        if ($entry -notmatch '^(?<Port>\d{1,5})@(?<Host>[A-Za-z0-9][A-Za-z0-9.-]*)$') {
            throw 'Formato invalido. Use puerto@servidor; por ejemplo, 25734@servidor.'
        }
        $port = [int]$Matches.Port
        if ($port -lt 1 -or $port -gt 65535) { throw 'El puerto debe estar entre 1 y 65535.' }
        [pscustomobject]@{ Port = $port; HostName = $Matches.Host; Display = $entry }
    }
}

function Get-Configuration([switch]$WithSerial) {
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw 'Falta Configuracion.local.json. Ejecute primero 00_Preparar_Configuracion.bat.'
    }
    $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    [void](Get-ValidatedServerEntries $config.LicenseServer)
    if ($WithSerial) {
        if ([string]::IsNullOrWhiteSpace($config.EncryptedSerial)) { throw 'La configuracion no contiene serial.' }
        try {
            $secure = ConvertTo-SecureString -String $config.EncryptedSerial
            $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
            try { $config | Add-Member -NotePropertyName Serial -NotePropertyValue ([Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)) }
            finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
        } catch {
            throw 'No se pudo descifrar el serial. Ejecute 00 con la misma cuenta de Windows que usara para instalar.'
        }
    }
    return $config
}

function Find-SolidWorksExecutable {
    $roots = @("$env:ProgramFiles\SOLIDWORKS Corp", "${env:ProgramFiles(x86)}\SOLIDWORKS Corp") | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
    foreach ($root in $roots) {
        $found = Get-ChildItem -LiteralPath $root -Filter SLDWORKS.exe -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
        if ($found) { return $found }
    }
    return $null
}

function Test-LicenseConnectivity($Config) {
    $allOk = $true
    foreach ($entry in @(Get-ValidatedServerEntries $Config.LicenseServer)) {
        $ok = Test-NetConnection -ComputerName $entry.HostName -Port $entry.Port -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($ok) { Write-Status 'OK' ('Puerto SolidNetWork accesible ({0}).' -f $entry.Port) }
        else { Write-Status 'ERROR' ('No hay conexion TCP con el servidor SolidNetWork en el puerto {0}.' -f $entry.Port); $allOk = $false }
    }
    return $allOk
}

function Invoke-Precheck {
    $config = Get-Configuration
    $failed = $false
    Write-Host '=== REQUISITOS SOLIDWORKS 2026 ==='

    if (Test-IsAdministrator) { Write-Status 'OK' 'La consola tiene permisos administrativos.' }
    else { Write-Status 'ERROR' 'Ejecute este BAT como administrador.'; $failed = $true }

    $os = Get-CimInstance Win32_OperatingSystem
    $build = [int]$os.BuildNumber
    if ($os.Caption -match 'Windows 11') { Write-Status 'OK' ("Sistema compatible: {0}, build {1}." -f $os.Caption, $build) }
    elseif ($os.Caption -match 'Windows 10' -and $build -in 19044, 19045) { Write-Status 'OK' ("Windows 10 compatible segun la guia: build {0}." -f $build) }
    else { Write-Status 'ERROR' ("Sistema no contemplado por la guia: {0}, build {1}." -f $os.Caption, $build); $failed = $true }

    $computer = Get-CimInstance Win32_ComputerSystem
    $ramGB = [math]::Round($computer.TotalPhysicalMemory / 1GB, 1)
    if ($ramGB -ge 15.0) { Write-Status 'OK' ("Memoria fisica instalada: {0} GB (clase 16 GB o superior)." -f $ramGB) }
    else { Write-Status 'ERROR' ("Memoria: {0} GB; la guia exige minimo 16 GB." -f $ramGB); $failed = $true }

    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    if ($cpu.NumberOfCores -ge 4 -and $cpu.MaxClockSpeed -ge 3300) { Write-Status 'OK' ("CPU: {0} nucleos, {1} MHz maximos." -f $cpu.NumberOfCores, $cpu.MaxClockSpeed) }
    else { Write-Status 'AVISO' ("CPU por debajo de la preferencia de la guia: {0} nucleos, {1} MHz." -f $cpu.NumberOfCores, $cpu.MaxClockSpeed) }

    $driveName = ([IO.Path]::GetPathRoot($env:ProgramFiles)).TrimEnd('\')
    $drive = Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $driveName)
    $freeGB = [math]::Round($drive.FreeSpace / 1GB, 1)
    if ($freeGB -ge $MinimumFreeGB) { Write-Status 'OK' ("Espacio libre: {0} GB (politica local: {1} GB)." -f $freeGB, $MinimumFreeGB) }
    else { Write-Status 'ERROR' ("Espacio libre insuficiente: {0} GB; politica local: {1} GB." -f $freeGB, $MinimumFreeGB); $failed = $true }

    $ethernet = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object {
        $_.Status -eq 'Up' -and $_.Name -notmatch 'Wi-?Fi|Wireless|WLAN' -and $_.InterfaceDescription -notmatch 'Wi-?Fi|Wireless|WLAN'
    })
    if ($ethernet.Count -gt 0) { Write-Status 'OK' ('Ethernet cableado activo: {0}.' -f (($ethernet.Name) -join ', ')) }
    else { Write-Status 'ERROR' 'No se detecto un adaptador Ethernet fisico activo.'; $failed = $true }

    if (-not (Test-LicenseConnectivity $config)) { $failed = $true }
    if ($failed) { Write-DeployLog 'Precheck: ERROR.'; return 10 }
    Write-DeployLog 'Precheck: OK.'
    return 0
}

function Quote-ProcessArgument([string]$Value) {
    return '"' + ($Value -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
}

function Invoke-Install {
    if (-not (Test-IsAdministrator)) { Write-Status 'ERROR' 'La instalacion requiere administrador.'; return 5 }
    $precheck = Invoke-Precheck
    if ($precheck -ne 0) { Write-Status 'ERROR' 'Instalacion cancelada por requisitos no cumplidos.'; return $precheck }
    if (Find-SolidWorksExecutable) { Write-Status 'OK' 'SOLIDWORKS ya esta instalado. No se reinstalara.'; return 0 }

    $startSw = Get-ChildItem -LiteralPath $MediaDir -Filter StartSWInstall.exe -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Directory.Name -ne 'sldim' } | Select-Object -First 1
    if ($startSw) {
        Write-Status 'INFO' 'Imagen administrativa detectada. Iniciando despliegue oficial con progreso visible.'
        Write-DeployLog 'Inicio por StartSWInstall.exe.'
        $p = Start-Process -FilePath $startSw.FullName -ArgumentList '/install', '/showui', '/now' -Wait -PassThru
        Write-DeployLog ("Fin de StartSWInstall.exe. Codigo {0}." -f $p.ExitCode)
        if ($p.ExitCode -notin 0, 3010) { Write-Status 'ERROR' ("El despliegue fallo con codigo {0}." -f $p.ExitCode); return $p.ExitCode }
        if ($p.ExitCode -eq 3010) { Write-Status 'REINICIO' 'Instalacion correcta; Windows requiere reinicio.' }
    } else {
        $msi = Get-ChildItem -LiteralPath $MediaDir -Filter SOLIDWORKS.msi -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '[\\/]64bit[\\/]SOLIDWORKS[\\/]SOLIDWORKS\.msi$' } | Select-Object -First 1
        if ($msi) {
            $config = Get-Configuration -WithSerial
            Write-Status 'INFO' 'MSI de imagen administrativa detectado. La barra de progreso permanecera visible.'
            Write-DeployLog 'Inicio por MSI de imagen administrativa.'
            $args = @(
                '/i', (Quote-ProcessArgument $msi.FullName),
                (Quote-ProcessArgument ('INSTALLDIR={0}' -f $config.InstallDirectory)),
                (Quote-ProcessArgument ('SOLIDWORKSSERIALNUMBER={0}' -f $config.Serial)),
                'ENABLEPERFORMANCE=0',
                (Quote-ProcessArgument 'ADDLOCAL=SolidWorks,SolidWorksToolbox'),
                (Quote-ProcessArgument ('TOOLBOXFOLDER={0}' -f $config.ToolboxDirectory)),
                (Quote-ProcessArgument ('SERVERLIST={0}' -f $config.LicenseServer)),
                '/qb', '/norestart'
            )
            $p = Start-Process -FilePath msiexec.exe -ArgumentList ($args -join ' ') -Wait -PassThru
            $config.Serial = $null
            Write-DeployLog ("Fin de MSI. Codigo {0}." -f $p.ExitCode)
            if ($p.ExitCode -notin 0, 3010) { Write-Status 'ERROR' ("MSI fallo con codigo {0}. Revise el medio y los logs oficiales del Installation Manager." -f $p.ExitCode); return $p.ExitCode }
            if ($p.ExitCode -eq 3010) { Write-Status 'REINICIO' 'Instalacion correcta; Windows requiere reinicio.' }
        } else {
            $setup = Get-ChildItem -LiteralPath $MediaDir -Filter setup.exe -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $setup) { $setup = Get-ChildItem -LiteralPath $MediaDir -Filter SolidWorksSetup.exe -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 }
            if (-not $setup) { Write-Status 'ERROR' 'No se encontro imagen administrativa, setup.exe ni SolidWorksSetup.exe dentro de MEDIA.'; return 20 }
            Write-Status 'MANUAL' 'El bootstrapper no documenta instalacion ni descarga silenciosa. Complete Installation Manager; el BAT verificara el resultado al cerrarlo.'
            Write-DeployLog 'Inicio del Installation Manager interactivo.'
            $p = Start-Process -FilePath $setup.FullName -Wait -PassThru
            Write-DeployLog ("Installation Manager interactivo termino. Codigo {0}." -f $p.ExitCode)
            if ($p.ExitCode -notin 0, 3010) { Write-Status 'ERROR' ("Installation Manager termino con codigo {0}." -f $p.ExitCode); return $p.ExitCode }
        }
    }
    if (-not (Find-SolidWorksExecutable)) { Write-Status 'ERROR' 'El instalador termino, pero no se encontro SLDWORKS.exe. No se continuara silenciosamente.'; return 30 }
    return Invoke-License
}

function Invoke-License {
    if (-not (Test-IsAdministrator)) { Write-Status 'ERROR' 'La configuracion de licencia requiere administrador.'; return 5 }
    $config = Get-Configuration
    [Environment]::SetEnvironmentVariable('SW_D_LICENSE_FILE', [string]$config.LicenseServer, 'Machine')
    $env:SW_D_LICENSE_FILE = [string]$config.LicenseServer
    $saved = [Environment]::GetEnvironmentVariable('SW_D_LICENSE_FILE', 'Machine')
    if ($saved -ne $config.LicenseServer) { Write-Status 'ERROR' 'No se pudo guardar SW_D_LICENSE_FILE a nivel de equipo.'; return 40 }
    Write-Status 'OK' 'Cliente SolidNetWork configurado mediante SW_D_LICENSE_FILE a nivel de equipo.'
    Write-DeployLog 'SW_D_LICENSE_FILE configurado (valor omitido).'
    if (-not (Test-LicenseConnectivity $config)) { return 41 }
    return 0
}

function Invoke-Verify {
    $config = Get-Configuration
    Ensure-LogDirectory
    $resultPath = Join-Path $LogDir ('Resultado_{0}.txt' -f $env:COMPUTERNAME)
    $result = [System.Collections.Generic.List[string]]::new()
    $failed = $false
    $exe = Find-SolidWorksExecutable
    if ($exe) {
        $version = [Diagnostics.FileVersionInfo]::GetVersionInfo($exe).ProductVersion
        Write-Status 'OK' ("SOLIDWORKS instalado: {0}" -f $exe)
        Write-Status 'OK' ("Version: {0}" -f $version)
        $result.Add('Instalado=OK'); $result.Add("Ejecutable=$exe"); $result.Add("Version=$version")
    } else {
        Write-Status 'ERROR' 'No se encontro SLDWORKS.exe.'; $result.Add('Instalado=ERROR'); $failed = $true
    }
    if (Test-LicenseConnectivity $config) { $result.Add('ConectividadSolidNetWork=OK') }
    else { $result.Add('ConectividadSolidNetWork=ERROR'); $failed = $true }

    $machineServer = [Environment]::GetEnvironmentVariable('SW_D_LICENSE_FILE', 'Machine')
    if ($machineServer -eq $config.LicenseServer) { Write-Status 'OK' 'SW_D_LICENSE_FILE coincide con la configuracion local.'; $result.Add('ConfiguracionLicencia=OK') }
    else { Write-Status 'ERROR' 'SW_D_LICENSE_FILE no coincide con la configuracion local.'; $result.Add('ConfiguracionLicencia=ERROR'); $failed = $true }

    $services = @(Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'SolidWorks|FlexNet' -or $_.DisplayName -match 'SOLIDWORKS|FlexNet' })
    if ($services.Count) {
        foreach ($service in $services) { Write-Status 'INFO' ("Servicio detectado: {0} [{1}]." -f $service.DisplayName, $service.Status) }
        $result.Add('ServiciosDetectados=' + (($services | ForEach-Object { '{0}:{1}' -f $_.Name, $_.Status }) -join ','))
    } else {
        Write-Status 'INFO' 'No hay servicio SolidNetWork cliente obligatorio; las licencias flotantes se consumen desde la aplicacion.'
        $result.Add('ServiciosDetectados=Ninguno; no obligatorio en cliente')
    }
    $state = if ($failed) { 'ERROR' } else { 'OK' }
    $result.Insert(0, "Resultado=$state")
    $result.Insert(1, "Equipo=$env:COMPUTERNAME")
    $result | Set-Content -LiteralPath $resultPath -Encoding UTF8
    Write-Host ("RESULTADO FINAL: {0}" -f $state)
    Write-Host ("Informe: {0}" -f $resultPath)
    if ($failed) { return 1 }
    return 0
}

function Invoke-FinalTest {
    $exe = Find-SolidWorksExecutable
    if (-not $exe) { Write-Status 'ERROR' 'No se encontro SLDWORKS.exe.'; return 1 }
    $existing = Get-Process SLDWORKS -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($existing) { Write-Status 'INFO' 'SOLIDWORKS ya estaba abierto.'; $process = $existing }
    else { $process = Start-Process -FilePath $exe -PassThru }
    Write-Status 'INFO' 'Esperando 30 segundos para comprobar que el proceso permanece activo...'
    Start-Sleep -Seconds 30
    $process.Refresh()
    if ($process.HasExited) { Write-Status 'ERROR' 'SOLIDWORKS se cerro durante el inicio. Revise el mensaje de licencia y los logs.'; return 2 }
    Write-Status 'OK' 'SLDWORKS.exe permanece en ejecucion.'
    Write-Status 'VALIDACION' 'Confirme visualmente que la ventana abrio sin error de licencia. Esa comprobacion humana es obligatoria.'
    return 0
}

try {
    switch ($Action) {
        'Configure' {
            Write-Host '=== CONFIGURACION LOCAL (NO SE SUBE A GIT) ==='
            $secureSerial = Read-Host 'Serial de SOLIDWORKS (entrada oculta)' -AsSecureString
            $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureSerial)
            try {
                $plainLength = ([Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)).Length
                if ($plainLength -lt 16) { throw 'El serial parece demasiado corto.' }
            } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
            $encryptedSerial = ConvertFrom-SecureString -SecureString $secureSerial
            $server = (Read-Host 'Servidor SolidNetWork (puerto@host)').Trim()
            [void](Get-ValidatedServerEntries $server)
            $config = [ordered]@{
                SchemaVersion = 1
                EncryptedSerial = $encryptedSerial
                LicenseServer = $server
                InstallDirectory = 'C:\Program Files\SOLIDWORKS Corp\SOLIDWORKS'
                ToolboxDirectory = 'C:\SOLIDWORKS Data'
            }
            $config | ConvertTo-Json | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
            Write-Status 'OK' 'Configuracion local creada. El serial quedo cifrado con DPAPI para esta cuenta de Windows.'
            exit 0
        }
        'Precheck' { exit (Invoke-Precheck) }
        'Install' { exit (Invoke-Install) }
        'License' { exit (Invoke-License) }
        'Verify' { exit (Invoke-Verify) }
        'FinalTest' { exit (Invoke-FinalTest) }
    }
} catch {
    Write-Status 'ERROR' $_.Exception.Message
    try { Write-DeployLog ('Error: ' + $_.Exception.Message) } catch { }
    exit 99
}
