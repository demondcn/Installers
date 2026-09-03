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
# FASE 2 - ADMINISTRADOR
# NO usa Winget.
# Instala lo descargado previamente por el usuario normal.
# ============================================================
if ($ElevatedStage) {
    if (-not (Test-IsAdmin)) {
        Stop-WithError "La fase de administrador no obtuvo privilegios elevados."
    }

    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " JAVA 25 + NETBEANS - FASE ADMINISTRADOR (1 SOLA UAC)" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Winget NO se ejecutara en esta fase." -ForegroundColor Green
    Write-Host "Se usaran los instaladores descargados por Estudiante." -ForegroundColor Green

    if (-not (Test-Path $DownloadDir)) {
        Stop-WithError "No existe la carpeta de descarga: $DownloadDir"
    }

    # ----------------------------
    # Encontrar instaladores
    # ----------------------------
    $jdkInstaller = Get-ChildItem -Path $DownloadDir -Recurse -File -Filter *.msi |
        Where-Object { $_.Name -match '(?i)(zulu|jdk|java)' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $jdkInstaller) {
        $jdkInstaller = Get-ChildItem -Path $DownloadDir -Recurse -File -Filter *.msi |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    }

    $netBeansInstaller = Get-ChildItem -Path $DownloadDir -Recurse -File -Filter *.exe |
        Where-Object { $_.Name -match '(?i)(netbeans|apache)' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $netBeansInstaller) {
        $netBeansInstaller = Get-ChildItem -Path $DownloadDir -Recurse -File -Filter *.exe |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    }

    if (-not $jdkInstaller) {
        Stop-WithError "No se encontro el MSI de Azul Zulu JDK 25."
    }

    if (-not $netBeansInstaller) {
        Stop-WithError "No se encontro el EXE de Apache NetBeans."
    }

    # ----------------------------
    # Instalar JDK
    # Winget usa ADDLOCAL=ALL para este paquete.
    # ----------------------------
    Write-Host ""
    Write-Host "[1/4] Instalando / actualizando Azul Zulu JDK 25..." -ForegroundColor Yellow
    Write-Host "Archivo: $($jdkInstaller.Name)" -ForegroundColor DarkGray

    $msiLog = Join-Path $env:TEMP "Zulu-JDK25-install.log"

    $jdkArgs = @(
        "/i"
        "`"$($jdkInstaller.FullName)`""
        "ADDLOCAL=ALL"
        "/qn"
        "/norestart"
        "/l*v"
        "`"$msiLog`""
    )

    $jdkProcess = Start-Process -FilePath "msiexec.exe" `
        -ArgumentList $jdkArgs `
        -Wait `
        -PassThru

    if ($jdkProcess.ExitCode -notin @(0, 1641, 3010)) {
        Write-Host ""
        Write-Host "El MSI de Java devolvio codigo $($jdkProcess.ExitCode)." -ForegroundColor Red
        Write-Host "Log MSI: $msiLog" -ForegroundColor Yellow

        # Si el producto ya esta instalado, comprobar si Java 25 existe
        # antes de considerar esto un fallo fatal.
        $existingJava = Get-ChildItem "C:\Program Files\Zulu" -Directory -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -like "zulu-25*" -and
                (Test-Path (Join-Path $_.FullName "bin\java.exe"))
            } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($existingJava) {
            Write-Host "Zulu JDK 25 ya existe en: $($existingJava.FullName)" -ForegroundColor Green
            Write-Host "Se continuara con JAVA_HOME, PATH y NetBeans." -ForegroundColor Green
        } else {
            Stop-WithError "No se pudo instalar Azul Zulu JDK 25. Revise el log indicado." $jdkProcess.ExitCode
        }
    } else {
        Write-Host "JDK 25 instalado/actualizado correctamente." -ForegroundColor Green
    }

    # ----------------------------
    # JAVA_HOME + PATH
    # ----------------------------
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
            Stop-WithError "No pude localizar la instalacion de Zulu JDK 25."
        }
    }

    [Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "Machine")

    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $javaBin = "$javaHome\bin"

    # Eliminar entradas Zulu antiguas/duplicadas del PATH.
    $cleanParts = @(
        $machinePath -split ";" |
        Where-Object {
            $_ -and
            ($_ -notmatch '(?i)\\Zulu\\zulu-[^;]*\\bin\\?$')
        }
    )

    $newMachinePath = ($javaBin + ";" + ($cleanParts -join ";")).TrimEnd(";")
    [Environment]::SetEnvironmentVariable("Path", $newMachinePath, "Machine")

    # Refrescar esta consola para comprobar.
    $env:JAVA_HOME = $javaHome
    $env:Path = "$javaBin;$env:Path"

    Write-Host "JAVA_HOME = $javaHome" -ForegroundColor Green
    Write-Host "Zulu en PATH:" -ForegroundColor Green
    [Environment]::GetEnvironmentVariable("Path", "Machine") -split ";" |
        Select-String "Zulu"

    # ----------------------------
    # Instalar NetBeans
    # El manifiesto Winget usa --silent.
    # ----------------------------
    Write-Host ""
    Write-Host "[3/4] Instalando / actualizando Apache NetBeans..." -ForegroundColor Yellow
    Write-Host "Archivo: $($netBeansInstaller.Name)" -ForegroundColor DarkGray

    $nbProcess = Start-Process -FilePath $netBeansInstaller.FullName `
        -ArgumentList @("--silent") `
        -Wait `
        -PassThru

    if ($nbProcess.ExitCode -notin @(0, 1641, 3010)) {
        Stop-WithError "El instalador de NetBeans devolvio codigo $($nbProcess.ExitCode)." $nbProcess.ExitCode
    }

    Write-Host "NetBeans instalado/actualizado correctamente." -ForegroundColor Green

    # ----------------------------
    # Verificacion
    # ----------------------------
    Write-Host ""
    Write-Host "[4/4] Verificando Java..." -ForegroundColor Yellow

    & "$javaHome\bin\java.exe" -version

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "                 PROCESO COMPLETADO" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Solo se utilizo una elevacion UAC para instalar y configurar." -ForegroundColor Green

    Pause-End
    exit 0
}

# ============================================================
# FASE 1 - USUARIO NORMAL
# Winget SOLO se ejecuta aqui.
# ============================================================
Clear-Host
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "       ACTUALIZACION JAVA 25 + APACHE NETBEANS" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "FASE 1: usuario normal." -ForegroundColor Green
Write-Host "Winget descargara Java y NetBeans SIN instalarlos." -ForegroundColor Green
Write-Host "Luego se pedira la contraseña de administrador UNA sola vez." -ForegroundColor Green
Write-Host ""

if (Test-IsAdmin) {
    Write-Host "ADVERTENCIA: Se ejecuto como administrador." -ForegroundColor Yellow
    Write-Host "Cierre esta ventana y abra el CMD normalmente." -ForegroundColor Yellow
    Write-Host "Winget debe ejecutarse con el perfil Estudiante." -ForegroundColor Yellow
    Pause-End
    exit 2
}

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if (-not $winget) {
    Stop-WithError "Winget no esta disponible para el usuario actual."
}

# Confirmar soporte de winget download.
$downloadHelp = (& winget download --help 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0 -or $downloadHelp -notmatch '(?i)download') {
    Stop-WithError "Esta version de Winget no soporta 'winget download'."
}

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
    Stop-WithError "No aparece el MSI de Java en la carpeta temporal."
}
if ($exeCount -lt 1) {
    Stop-WithError "No aparece el EXE de NetBeans en la carpeta temporal."
}

Write-Host ""
Write-Host "[4/4] Descargas listas." -ForegroundColor Green
Write-Host "Ahora se pediran credenciales de administrador UNA sola vez." -ForegroundColor Yellow
Write-Host ""
Write-Host "La fase elevada NO ejecutara Winget." -ForegroundColor Cyan
Write-Host ""

$argList = @(
    "-NoProfile"
    "-ExecutionPolicy", "Bypass"
    "-File", "`"$PSCommandPath`""
    "-ElevatedStage"
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
    Write-Host "No se concedieron permisos o la elevacion fallo." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

try {
    Remove-Item -Path $DownloadDir -Recurse -Force -ErrorAction SilentlyContinue
} catch {}

Write-Host ""
Write-Host "Proceso finalizado." -ForegroundColor Cyan
Pause-End
