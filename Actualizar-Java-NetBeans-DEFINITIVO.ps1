param(
    [switch]$AdminPhase
)

# ============================================================
# ACTUALIZADOR AUTOMATICO
# Azul Zulu JDK 25 + Apache NetBeans + JAVA_HOME + PATH
#
# FASE 1 - USUARIO NORMAL:
#   winget source update
#   winget install Azul.Zulu.25.JDK
#   winget install Apache.NetBeans
#
# FASE 2 - ADMINISTRADOR:
#   Configura JAVA_HOME y PATH a nivel Machine
# ============================================================

$ErrorActionPreference = 'Continue'

function Pause-And-Exit([int]$Code = 0) {
    Write-Host ""
    Read-Host "Presione ENTER para cerrar"
    exit $Code
}

# ------------------------------------------------------------
# FASE 2 - SOLO ADMINISTRADOR
# ------------------------------------------------------------
if ($AdminPhase) {

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $esAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $esAdmin) {
        Write-Host "ERROR: Esta fase necesita permisos de administrador." -ForegroundColor Red
        Pause-And-Exit 1
    }

    Clear-Host
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host " CONFIGURACION JAVA 25 - ADMINISTRADOR" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""

    $javaHome = "C:\Program Files\Zulu\zulu-25"
    $javaBin  = "$javaHome\bin"

    if (-not (Test-Path $javaHome)) {
        Write-Host "ERROR: No existe la carpeta:" -ForegroundColor Red
        Write-Host $javaHome -ForegroundColor White
        Write-Host ""
        Write-Host "Compruebe que Azul Zulu JDK 25 se haya instalado correctamente." -ForegroundColor Yellow
        Pause-And-Exit 1
    }

    Write-Host "[1/3] Configurando JAVA_HOME..." -ForegroundColor Yellow
    [Environment]::SetEnvironmentVariable(
        "JAVA_HOME",
        "C:\Program Files\Zulu\zulu-25",
        "Machine"
    )
    Write-Host "JAVA_HOME configurado correctamente." -ForegroundColor Green

    Write-Host ""
    Write-Host "[2/3] Configurando PATH del sistema..." -ForegroundColor Yellow

    $path = [Environment]::GetEnvironmentVariable("Path", "Machine")

    # Eliminar entradas anteriores de Zulu para no duplicarlas.
    $pathLimpio = ($path -split ';' |
        Where-Object {
            $_ -and ($_ -notmatch '(?i)\\Zulu\\zulu-25[^;]*\\bin$')
        }) -join ';'

    [Environment]::SetEnvironmentVariable(
        "Path",
        "C:\Program Files\Zulu\zulu-25\bin;" + $pathLimpio,
        "Machine"
    )

    # Actualizar también esta consola para poder verificar inmediatamente.
    $env:JAVA_HOME = $javaHome
    if ($env:Path -notlike "*$javaBin*") {
        $env:Path = "$javaBin;$env:Path"
    }

    Write-Host "PATH configurado correctamente." -ForegroundColor Green

    Write-Host ""
    Write-Host "[3/3] Verificando configuracion..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "JAVA_HOME:" -ForegroundColor Cyan
    Write-Host ([Environment]::GetEnvironmentVariable("JAVA_HOME", "Machine"))

    Write-Host ""
    Write-Host "Entradas Zulu en PATH:" -ForegroundColor Cyan
    [Environment]::GetEnvironmentVariable("Path", "Machine") -split ";" | Select-String "Zulu"

    Write-Host ""
    Write-Host "Version de Java:" -ForegroundColor Cyan
    & "$javaBin\java.exe" -version

    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host " JAVA 25 Y VARIABLES CONFIGURADOS" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
    Pause-And-Exit 0
}

# ------------------------------------------------------------
# FASE 1 - USUARIO NORMAL
# ------------------------------------------------------------
Clear-Host
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " ACTUALIZACION JAVA 25 + NETBEANS" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Esta primera fase se ejecuta como usuario normal." -ForegroundColor Gray
Write-Host "Los permisos de administrador se pediran SOLO al configurar JAVA_HOME y PATH." -ForegroundColor Gray
Write-Host ""

# Comprobar Winget
if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Winget no esta disponible en este equipo." -ForegroundColor Red
    Pause-And-Exit 1
}

Write-Host "[1/4] Actualizando fuentes de Winget..." -ForegroundColor Yellow
winget source update

Write-Host ""
Write-Host "[2/4] Instalando / actualizando Azul Zulu JDK 25..." -ForegroundColor Yellow
winget install --id Azul.Zulu.25.JDK --exact --silent --accept-package-agreements --accept-source-agreements
$javaExit = $LASTEXITCODE

Write-Host ""
Write-Host "[3/4] Instalando / actualizando Apache NetBeans..." -ForegroundColor Yellow
winget install --id Apache.NetBeans --exact --silent --accept-package-agreements --accept-source-agreements
$netbeansExit = $LASTEXITCODE

Write-Host ""
Write-Host "[4/4] Comprobando Java 25..." -ForegroundColor Yellow
$javaHome = "C:\Program Files\Zulu\zulu-25"

if (-not (Test-Path "$javaHome\bin\java.exe")) {
    Write-Host ""
    Write-Host "ERROR: No se encontro Java 25 en:" -ForegroundColor Red
    Write-Host $javaHome -ForegroundColor White
    Write-Host ""
    Write-Host "Codigo devuelto por Winget para Java: $javaExit" -ForegroundColor Yellow
    Write-Host "Revise la salida de Winget antes de continuar." -ForegroundColor Yellow
    Pause-And-Exit 1
}

Write-Host "Zulu JDK 25 encontrado correctamente." -ForegroundColor Green

Write-Host ""
Write-Host "Solicitando permisos de administrador para configurar JAVA_HOME y PATH..." -ForegroundColor Yellow

$argumentos = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', ('"{0}"' -f $PSCommandPath),
    '-AdminPhase'
) -join ' '

try {
    $proc = Start-Process powershell.exe -Verb RunAs -ArgumentList $argumentos -Wait -PassThru
    if ($proc.ExitCode -ne 0) {
        Write-Host ""
        Write-Host "La fase de administrador termino con codigo $($proc.ExitCode)." -ForegroundColor Red
        Pause-And-Exit $proc.ExitCode
    }
}
catch {
    Write-Host ""
    Write-Host "ERROR: No se pudieron obtener permisos de administrador." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Pause-And-Exit 1
}

Write-Host ""
Write-Host "Proceso completado." -ForegroundColor Green
Pause-And-Exit 0
