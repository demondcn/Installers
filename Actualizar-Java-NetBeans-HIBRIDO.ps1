param(
    [switch]$ElevatedStage,
    [string]$DownloadDir = ""
)

$ErrorActionPreference = "Stop"
$host.UI.RawUI.WindowTitle = "Actualizar Java 25 + NetBeans"

function Pause-End {
    Write-Host ""
    Read-Host "Presione ENTER para cerrar"
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Stop-WithError([string]$Message, [int]$Code = 1) {
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    Pause-End
    exit $Code
}

# ============================================================
# FASE 2: ADMINISTRADOR
# Aqui NO se usa Winget.
# Instala los archivos que ya descargo el usuario normal.
# ============================================================
if ($ElevatedStage) {
    if (-not (Test-IsAdmin)) {
        Stop-WithError "La fase de administrador no se ejecuto con privilegios elevados."
    }

    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "   JAVA 25 + NETBEANS - FASE ADMINISTRADOR (1 SOLA UAC)" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Winget NO se ejecutara en esta fase." -ForegroundColor Green
    Write-Host "Se usaran los instaladores descargados por el usuario normal." -ForegroundColor Green

    if (-not (Test-Path $DownloadDir)) {
        Stop-WithError "No existe la carpeta de descarga: $DownloadDir"
    }

    $jdkInstaller = Get-ChildItem -Path $DownloadDir -Recurse -File -Filter *.msi |
        Where-Object { $_.Name -match '(?i)(zulu|jdk|java)' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $jdkInstaller) {
        # Si Winget cambio el nombre, usar el unico MSI disponible.
        $jdkInstaller = Get-ChildItem -Path $DownloadDir -Recurse -File -Filter *.msi |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    }

    $netBeansInstaller = Get-ChildItem -Path $DownloadDir -Recurse -File -Filter *.exe |
        Where-Object { $_.Name -match '(?i)(netbeans|apache)' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $netBeansInstaller) {
        # Si Winget cambio el nombre, usar el unico EXE disponible.
        $netBeansInstaller = Get-ChildItem -Path $DownloadDir -Recurse -File -Filter *.exe |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    }

    if (-not $jdkInstaller) {
        Stop-WithError "No se encontro el instalador MSI de Azul Zulu JDK 25."
    }

    if (-not $netBeansInstaller) {
        Stop-WithError "No se encontro el instalador EXE de Apache NetBeans."
    }

    Write-Host ""
    Write-Host "[1/4] Instalando Azul Zulu JDK 25..." -ForegroundColor Yellow
    Write-Host "Archivo: $($jdkInstaller.Name)" -ForegroundColor DarkGray

    $jdkProcess = Start-Process -FilePath "msiexec.exe" `
        -ArgumentList @("/i", "`"$($jdkInstaller.FullName)`"", "/qn", "/norestart") `
        -Wait -PassThru

    if ($jdkProcess.ExitCode -notin @(0, 1641, 3010)) {
        Stop-WithError "El instalador de Java devolvio el codigo $($jdkProcess.ExitCode)." $jdkProcess.ExitCode
    }

    Write-Host "JDK 25 instalado/actualizado." -ForegroundColor Green

    # Localizar la instalacion real de Zulu 25
    Write-Host ""
    Write-Host "[2/4] Configurando JAVA_HOME y PATH..." -ForegroundColor Yellow

    $javaHome = "C:\Program Files\Zulu\zulu-25"

    if (-not (Test-Path "$javaHome\bin\java.exe")) {
        $candidate = Get-ChildItem "C:\Program Files\Zulu" -Directory -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -like "zulu-25*" -and
                (Test-Path (Join-Path $_.FullName "bin\java.exe"))
            } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($candidate) {
            $javaHome = $candidate.FullName
        } else {
            Stop-WithError "Java se instalo, pero no pude localizar la carpeta de Zulu JDK 25."
        }
    }

    [Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "Machine")

    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $javaBin = "$javaHome\bin"

    # Quitar entradas antiguas/duplicadas de Zulu antes de agregar la actual.
    $cleanParts = @(
        $machinePath -split ";" |
        Where-Object {
            $_ -and
            ($_ -notmatch '(?i)\\Zulu\\zulu-[^;]*\\bin\\?$')
        }
    )

    $newMachinePath = ($javaBin + ";" + ($cleanParts -join ";")).TrimEnd(";")
    [Environment]::SetEnvironmentVariable("Path", $newMachinePath, "Machine")

    # Refrescar solo esta consola para las comprobaciones.
    $env:JAVA_HOME = $javaHome
    $env:Path = "$javaBin;$env:Path"

    Write-Host "JAVA_HOME = $javaHome" -ForegroundColor Green
    Write-Host "Zulu en PATH:" -ForegroundColor Green
    [Environment]::GetEnvironmentVariable("Path", "Machine") -split ";" |
        Select-String "Zulu"

    Write-Host ""
    Write-Host "[3/4] Instalando / actualizando Apache NetBeans..." -ForegroundColor Yellow
    Write-Host "Archivo: $($netBeansInstaller.Name)" -ForegroundColor DarkGray

    # El manifiesto oficial de Winget para NetBeans usa --silent.
    $nbProcess = Start-Process -FilePath $netBeansInstaller.FullName `
        -ArgumentList @("--silent") `
        -Wait -PassThru

    if ($nbProcess.ExitCode -notin @(0, 1641, 3010)) {
        Stop-WithError "El instalador de NetBeans devolvio el codigo $($nbProcess.ExitCode)." $nbProcess.ExitCode
    }

    Write-Host "NetBeans instalado/actualizado." -ForegroundColor Green

    Write-Host ""
    Write-Host "[4/4] Verificando Java..." -ForegroundColor Yellow
    & "$javaHome\bin\java.exe" -version

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "                PROCESO COMPLETADO" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Java y NetBeans fueron instalados con UNA sola solicitud" -ForegroundColor Green
    Write-Host "de credenciales de administrador." -ForegroundColor Green

    Pause-End
    exit 0
}

# ============================================================
# FASE 1: USUARIO NORMAL
# Winget se ejecuta SOLO aqui.
# NO instala: solamente actualiza fuentes y descarga instaladores.
# ============================================================
Clear-Host
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "       ACTUALIZACION JAVA 25 + APACHE NETBEANS" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "FASE 1: usuario normal." -ForegroundColor Green
Write-Host "Winget solo actualizara fuentes y descargara los instaladores." -ForegroundColor Green
Write-Host "La contraseña de administrador se pedira UNA sola vez despues." -ForegroundColor Green
Write-Host ""

if (Test-IsAdmin) {
    Write-Host "ADVERTENCIA: Este archivo fue abierto como administrador." -ForegroundColor Yellow
    Write-Host "Cierralo y ejecutalo como usuario normal para que Winget use" -ForegroundColor Yellow
    Write-Host "el perfil Estudiante, que es el que ya comprobamos que funciona." -ForegroundColor Yellow
    Pause-End
    exit 2
}

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if (-not $winget) {
    Stop-WithError "Winget no esta disponible para el usuario actual."
}

# Comprobar que esta version de Winget tenga el comando download.
$downloadHelp = (& winget download --help 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0 -or $downloadHelp -notmatch '(?i)download') {
    Stop-WithError "Esta version de Winget no soporta 'winget download'. Actualiza App Installer y vuelve a intentarlo."
}

# Carpeta temporal propia de esta ejecucion.
$DownloadDir = Join-Path $env:TEMP ("JavaNetBeans-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null

Write-Host "[1/4] Actualizando fuentes de Winget..." -ForegroundColor Yellow
winget source update
if ($LASTEXITCODE -ne 0) {
    Stop-WithError "winget source update devolvio el codigo $LASTEXITCODE."
}

Write-Host ""
Write-Host "[2/4] Descargando Azul Zulu JDK 25 (sin instalar)..." -ForegroundColor Yellow
winget download `
    --id Azul.Zulu.25.JDK `
    --exact `
    --architecture x64 `
    --download-directory "$DownloadDir" `
    --skip-dependencies `
    --accept-package-agreements `
    --accept-source-agreements `
    --disable-interactivity

if ($LASTEXITCODE -ne 0) {
    Stop-WithError "No se pudo descargar Azul Zulu JDK 25. Winget devolvio $LASTEXITCODE."
}

Write-Host ""
Write-Host "[3/4] Descargando Apache NetBeans (sin instalar)..." -ForegroundColor Yellow
winget download `
    --id Apache.NetBeans `
    --exact `
    --architecture x64 `
    --download-directory "$DownloadDir" `
    --skip-dependencies `
    --accept-package-agreements `
    --accept-source-agreements `
    --disable-interactivity

if ($LASTEXITCODE -ne 0) {
    Stop-WithError "No se pudo descargar Apache NetBeans. Winget devolvio $LASTEXITCODE."
}

$msiCount = @(Get-ChildItem $DownloadDir -Recurse -File -Filter *.msi).Count
$exeCount = @(Get-ChildItem $DownloadDir -Recurse -File -Filter *.exe).Count

if ($msiCount -lt 1) {
    Stop-WithError "Winget termino, pero no aparece el MSI de Java en la carpeta temporal."
}
if ($exeCount -lt 1) {
    Stop-WithError "Winget termino, pero no aparece el EXE de NetBeans en la carpeta temporal."
}

Write-Host ""
Write-Host "[4/4] Descargas listas." -ForegroundColor Green
Write-Host "Ahora se pediran credenciales de administrador UNA sola vez." -ForegroundColor Yellow
Write-Host ""
Write-Host "IMPORTANTE: desde la ventana elevada NO se ejecutara Winget." -ForegroundColor Cyan
Write-Host ""

# Relanzar ESTE MISMO script elevado, pero solo para la fase local.
$argList = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$PSCommandPath`"",
    "-ElevatedStage",
    "-DownloadDir", "`"$DownloadDir`""
)

try {
    $adminProcess = Start-Process -FilePath "powershell.exe" `
        -Verb RunAs `
        -ArgumentList $argList `
        -Wait `
        -PassThru

    if ($adminProcess.ExitCode -ne 0) {
        Write-Host ""
        Write-Host "La fase de administrador termino con codigo $($adminProcess.ExitCode)." -ForegroundColor Red
    }
} catch {
    Write-Host ""
    Write-Host "No se concedieron permisos de administrador o la elevacion fallo." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

# Limpieza de los instaladores descargados.
try {
    Remove-Item -Path $DownloadDir -Recurse -Force -ErrorAction SilentlyContinue
} catch {}

Write-Host ""
Write-Host "Proceso finalizado." -ForegroundColor Cyan
Pause-End
