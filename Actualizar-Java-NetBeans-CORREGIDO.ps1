# ============================================================
# ACTUALIZADOR AUTOMATICO
# Zulu JDK 25 + JAVA_HOME + PATH + Apache NetBeans
# ============================================================

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# 1. Elevar a administrador
# ------------------------------------------------------------
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$esAdmin   = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $esAdmin) {
    Write-Host "Solicitando permisos de administrador..." -ForegroundColor Yellow

    Start-Process powershell.exe `
        -Verb RunAs `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""

    exit
}

Clear-Host
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " ACTUALIZACION JAVA 25 + NETBEANS" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# 2. Comprobar Winget
# ------------------------------------------------------------
Write-Host "[1/6] Comprobando Winget..." -ForegroundColor Yellow

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if (-not $winget) {
    Write-Host "" 
    Write-Host "ERROR: Winget no esta instalado o no esta disponible en PATH." -ForegroundColor Red
    Write-Host "Instale/actualice App Installer de Microsoft y vuelva a intentar." -ForegroundColor White
    pause
    exit 1
}

Write-Host "Winget encontrado." -ForegroundColor Green

# ------------------------------------------------------------
# 3. Reparar SOLO la fuente winget
#    No usamos msstore para evitar solicitudes de region/acuerdos.
# ------------------------------------------------------------
Write-Host ""
Write-Host "[2/6] Reparando fuente oficial de Winget..." -ForegroundColor Yellow

# Primero intentamos actualizar solo la fuente winget.
# Si falla, restauramos las fuentes y volvemos a actualizar solo winget.
& winget source update --name winget
$sourceExit = $LASTEXITCODE

if ($sourceExit -ne 0) {
    Write-Host "La fuente winget fallo al actualizar. Intentando repararla..." -ForegroundColor Yellow
    & winget source reset --force
    & winget source update --name winget

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "ERROR: No fue posible reparar la fuente 'winget'." -ForegroundColor Red
        Write-Host "Codigo de salida: $LASTEXITCODE" -ForegroundColor Red
        pause
        exit 1
    }
}

Write-Host "Fuente winget lista." -ForegroundColor Green

# ------------------------------------------------------------
# 4. Instalar / actualizar Zulu JDK 25
# ------------------------------------------------------------
Write-Host ""
Write-Host "[3/6] Instalando / actualizando Azul Zulu JDK 25..." -ForegroundColor Yellow

& winget install `
    --id Azul.Zulu.25.JDK `
    --exact `
    --source winget `
    --silent `
    --accept-package-agreements `
    --accept-source-agreements `
    --disable-interactivity

$javaInstallExit = $LASTEXITCODE

# Winget suele devolver 0 si instala/actualiza correctamente.
# Si devuelve otro codigo, comprobamos igualmente si Java 25 quedo instalado.
if ($javaInstallExit -ne 0) {
    Write-Host "Winget devolvio el codigo $javaInstallExit. Se verificara la instalacion..." -ForegroundColor Yellow
}

# ------------------------------------------------------------
# 5. Detectar automaticamente la carpeta del JDK
# ------------------------------------------------------------
Write-Host ""
Write-Host "[4/6] Buscando instalacion de Java 25..." -ForegroundColor Yellow

$zuluRoots = @(
    "C:\Program Files\Zulu",
    "C:\Program Files\Azul Systems"
)

$zulu = $null

foreach ($root in $zuluRoots) {
    if (Test-Path $root) {
        $candidate = Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -match "(?i)zulu.*25|jdk.*25" -and
                (Test-Path (Join-Path $_.FullName "bin\java.exe"))
            } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($candidate) {
            $zulu = $candidate
            break
        }
    }
}

# Fallback: buscar java.exe de Zulu 25 dentro de Program Files.
if (-not $zulu) {
    $javaExe = Get-ChildItem "C:\Program Files" -Filter java.exe -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "(?i)zulu.*25.*\\bin\\java\.exe$" } |
        Select-Object -First 1

    if ($javaExe) {
        $zulu = Get-Item (Split-Path (Split-Path $javaExe.FullName -Parent) -Parent)
    }
}

if (-not $zulu) {
    Write-Host ""
    Write-Host "ERROR: No se encontro Zulu JDK 25." -ForegroundColor Red
    Write-Host "Winget no logro instalar el paquete Azul.Zulu.25.JDK desde la fuente winget." -ForegroundColor White
    Write-Host "Codigo de Winget: $javaInstallExit" -ForegroundColor White
    pause
    exit 1
}

$javaHome = $zulu.FullName

Write-Host "Java encontrado en:" -ForegroundColor Green
Write-Host $javaHome -ForegroundColor White

# ------------------------------------------------------------
# 6. JAVA_HOME y PATH
# ------------------------------------------------------------
Write-Host ""
Write-Host "[5/6] Configurando JAVA_HOME y PATH..." -ForegroundColor Yellow

[Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "Machine")

$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$javaBin = Join-Path $javaHome "bin"
$pathPartes = @($machinePath -split ";" | Where-Object { $_ -and $_.Trim() })

# Quitar entradas antiguas de Zulu del PATH para no acumular versiones.
$pathLimpio = @($pathPartes | Where-Object { $_ -notmatch "(?i)\\Zulu\\.*\\bin$" })

if ($pathLimpio -notcontains $javaBin) {
    $pathLimpio = @($javaBin) + $pathLimpio
}

$nuevoPath = ($pathLimpio -join ";")
[Environment]::SetEnvironmentVariable("Path", $nuevoPath, "Machine")

# Actualizar variables de esta ventana.
$env:JAVA_HOME = $javaHome
$env:Path = "$javaBin;" + (($env:Path -split ";" | Where-Object { $_ -notmatch "(?i)\\Zulu\\.*\\bin$" }) -join ";")

Write-Host "JAVA_HOME y PATH configurados." -ForegroundColor Green

# ------------------------------------------------------------
# 7. Instalar / actualizar NetBeans
# ------------------------------------------------------------
Write-Host ""
Write-Host "[6/6] Instalando / actualizando Apache NetBeans..." -ForegroundColor Yellow

& winget install `
    --id Apache.NetBeans `
    --exact `
    --source winget `
    --silent `
    --accept-package-agreements `
    --accept-source-agreements `
    --disable-interactivity

$netbeansExit = $LASTEXITCODE

if ($netbeansExit -ne 0) {
    Write-Host "Winget devolvio el codigo $netbeansExit para NetBeans." -ForegroundColor Yellow
}

# ------------------------------------------------------------
# Verificacion
# ------------------------------------------------------------
Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " VERIFICACION" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "JAVA_HOME:" -ForegroundColor Yellow
Write-Host ([Environment]::GetEnvironmentVariable("JAVA_HOME", "Machine"))

Write-Host ""
Write-Host "Version de Java:" -ForegroundColor Yellow
& "$javaBin\java.exe" -version

Write-Host ""
Write-Host "NetBeans en Winget:" -ForegroundColor Yellow
& winget list --id Apache.NetBeans --exact --source winget --accept-source-agreements

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host " PROCESO TERMINADO" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Puedes cerrar esta ventana." -ForegroundColor White
Write-Host ""

pause
