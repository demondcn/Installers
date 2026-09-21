# Instalar-VMware-Automatico-v2.ps1
# Descarga e instala VMware Workstation Pro 26H1 automaticamente.
# NO actualiza VMware si ya esta instalado.
#
# Descarga: archivo historico en archive.org
# Seguridad:
#   - Verifica SHA-256 contra el hash publicado para VMware Workstation Pro 26H1.
#   - Verifica la firma digital del instalador (Broadcom/VMware).
#
# Version:
#   VMware Workstation Pro 26H1
#   Build 25388281

$ErrorActionPreference = "Stop"

$VmwareVersion = "26H1"
$VmwareBuild   = "25388281"

$DownloadUrl = "https://archive.org/download/vmwareworkstationarchive/26H1/VMware-Workstation-Full-26H1-25388281.exe"
$ExpectedHash = "a0ef9087607d9cad20b08139e73e41242e044ad5bd8cee141d3bad314586737f"

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Pause-Script {
    Write-Host ""
    Read-Host "Presione ENTER para cerrar"
}

function Get-InstalledVMwareWorkstation {
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($registryPath in $registryPaths) {
        if (-not (Test-Path $registryPath)) {
            continue
        }

        foreach ($entry in Get-ChildItem -LiteralPath $registryPath -ErrorAction SilentlyContinue) {
            try {
                $app = Get-ItemProperty -LiteralPath $entry.PSPath -ErrorAction SilentlyContinue

                if ($app.DisplayName -and $app.DisplayName -like "VMware Workstation*") {
                    return $app
                }
            }
            catch {
                # Ignorar entradas del Registro que no puedan leerse.
            }
        }
    }

    return $null
}

Write-Host ""
Write-Host "===================================================="
Write-Host "      INSTALADOR AUTOMATICO VMWARE WORKSTATION"
Write-Host "===================================================="
Write-Host ""

# Auto-elevacion
if (-not (Test-Administrator)) {
    Write-Host "Solicitando permisos de Administrador..." -ForegroundColor Yellow

    $self = $MyInvocation.MyCommand.Path

    try {
        Start-Process powershell.exe `
            -Verb RunAs `
            -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"$self`""
        exit
    }
    catch {
        Write-Host "ERROR: No fue posible obtener permisos de Administrador." -ForegroundColor Red
        Pause-Script
        exit 1
    }
}

# No actualizar si ya existe
$installed = Get-InstalledVMwareWorkstation

if ($null -ne $installed) {
    Write-Host "VMware Workstation ya esta instalado." -ForegroundColor Yellow

    if ($installed.DisplayVersion) {
        Write-Host "Version detectada: $($installed.DisplayVersion)"
    }

    Write-Host ""
    Write-Host "No se descargara ni actualizara nada." -ForegroundColor Green
    Pause-Script
    exit 0
}

$tempRoot = Join-Path $env:TEMP "VMwareWorkstationAuto"
$installer = Join-Path $tempRoot "VMware-Workstation-Full-$VmwareVersion-$VmwareBuild.exe"

try {
    if (Test-Path $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    Write-Host "VMware no esta instalado." -ForegroundColor Cyan
    Write-Host "Version a instalar: VMware Workstation Pro $VmwareVersion (Build $VmwareBuild)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Descargando automaticamente..." -ForegroundColor Yellow
    Write-Host "Tamano aproximado: 275 MB."
    Write-Host ""

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Primero BITS, que suele ser mas estable para archivos grandes.
    $bits = Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue

    if ($null -ne $bits) {
        try {
            Start-BitsTransfer `
                -Source $DownloadUrl `
                -Destination $installer `
                -DisplayName "VMware Workstation Pro $VmwareVersion" `
                -Description "Descargando instalador VMware"
        }
        catch {
            Write-Host "BITS no pudo completar la descarga. Probando metodo alternativo..." -ForegroundColor Yellow
            Invoke-WebRequest `
                -Uri $DownloadUrl `
                -OutFile $installer `
                -UseBasicParsing
        }
    }
    else {
        Invoke-WebRequest `
            -Uri $DownloadUrl `
            -OutFile $installer `
            -UseBasicParsing
    }

    if (-not (Test-Path $installer)) {
        throw "No se genero el archivo del instalador."
    }

    $sizeMB = [math]::Round((Get-Item $installer).Length / 1MB, 2)
    Write-Host "Descarga completada: $sizeMB MB" -ForegroundColor Green
    Write-Host ""

    # Verificacion SHA-256
    Write-Host "Verificando SHA-256..." -ForegroundColor Yellow

    $actualHash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()

    if ($actualHash -ne $ExpectedHash.ToLowerInvariant()) {
        throw @"
El SHA-256 NO coincide.
Instalacion cancelada por seguridad.

Esperado:
$ExpectedHash

Obtenido:
$actualHash
"@
    }

    Write-Host "SHA-256 correcto." -ForegroundColor Green

    # Verificacion de firma Authenticode
    Write-Host "Verificando firma digital..." -ForegroundColor Yellow

    $signature = Get-AuthenticodeSignature -LiteralPath $installer

    if ($signature.Status -ne "Valid") {
        throw "La firma digital no es valida. Estado: $($signature.Status). Instalacion cancelada."
    }

    $subject = $signature.SignerCertificate.Subject

    if ($subject -notmatch "Broadcom Inc" -and $subject -notmatch "VMware") {
        throw "El firmante no parece ser Broadcom/VMware. Firmante detectado: $subject"
    }

    Write-Host "Firma digital valida: $subject" -ForegroundColor Green
    Write-Host ""
    Write-Host "Instalando VMware Workstation Pro silenciosamente..." -ForegroundColor Yellow
    Write-Host "No cierre esta ventana."
    Write-Host ""

    # Sintaxis de instalacion silenciosa soportada por VMware Workstation.
    # Desde Workstation 17.5.2+ no se requiere SERIALNUMBER para la edicion gratuita.
    $silentArgs = '/s /v"/qn EULAS_AGREED=1 REBOOT=ReallySuppress AUTOSOFTWAREUPDATE=0 DATACOLLECTION=0"'

    $process = Start-Process `
        -FilePath $installer `
        -ArgumentList $silentArgs `
        -Wait `
        -PassThru

    $exitCode = $process.ExitCode

    Write-Host ""

    if ($exitCode -eq 0) {
        Write-Host "VMware Workstation Pro $VmwareVersion se instalo correctamente." -ForegroundColor Green
    }
    elseif ($exitCode -in @(3010, 1641)) {
        Write-Host "VMware Workstation Pro se instalo correctamente." -ForegroundColor Green
        Write-Host "Se recomienda reiniciar Windows para completar la instalacion." -ForegroundColor Yellow
    }
    else {
        throw "El instalador termino con el codigo $exitCode."
    }
}
catch {
    Write-Host ""
    Write-Host "ERROR:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
finally {
    Write-Host ""
    Write-Host "Limpiando archivos temporales..."

    if (Test-Path $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Pause-Script
