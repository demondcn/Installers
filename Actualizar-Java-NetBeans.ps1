# ============================================================
# INSTALADOR AUTOMATICO
# Zulu JDK 25 + JAVA_HOME + PATH + Apache NetBeans
# ============================================================

# ------------------------------------------------------------
# 1. Comprobar si PowerShell está ejecutándose como administrador
# ------------------------------------------------------------

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)

$esAdmin = $principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

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
# 2. Winget
# ------------------------------------------------------------

Write-Host "[1/6] Restaurando fuentes de Winget..." -ForegroundColor Yellow

winget source reset --force

Write-Host ""
Write-Host "[2/6] Actualizando fuentes de Winget..." -ForegroundColor Yellow

winget source update


# ------------------------------------------------------------
# 3. Instalar Zulu JDK 25
# ------------------------------------------------------------

Write-Host ""
Write-Host "[3/6] Instalando Azul Zulu JDK 25..." -ForegroundColor Yellow

winget install `
    --id Azul.Zulu.25.JDK `
    --exact `
    --silent `
    --accept-package-agreements `
    --accept-source-agreements


# ------------------------------------------------------------
# 4. Detectar automáticamente la carpeta del JDK
# ------------------------------------------------------------

Write-Host ""
Write-Host "[4/6] Buscando instalación de Java 25..." -ForegroundColor Yellow

$zulu = Get-ChildItem "C:\Program Files\Zulu" -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "zulu-25*" } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $zulu) {

    Write-Host ""
    Write-Host "ERROR: No se encontró Zulu JDK 25." -ForegroundColor Red
    Write-Host "Revise si Winget pudo instalar Java correctamente."
    pause
    exit 1
}

$javaHome = $zulu.FullName

Write-Host "Java encontrado en:" -ForegroundColor Green
Write-Host $javaHome -ForegroundColor White


# ------------------------------------------------------------
# 5. JAVA_HOME y PATH
# ------------------------------------------------------------

Write-Host ""
Write-Host "[5/6] Configurando JAVA_HOME y PATH..." -ForegroundColor Yellow

[Environment]::SetEnvironmentVariable(
    "JAVA_HOME",
    $javaHome,
    "Machine"
)

$machinePath = [Environment]::GetEnvironmentVariable(
    "Path",
    "Machine"
)

$javaBin = "$javaHome\bin"

# Evitar agregar Java repetidamente al PATH
$pathPartes = $machinePath -split ";"

if ($pathPartes -notcontains $javaBin) {

    $nuevoPath = "$javaBin;$machinePath"

    [Environment]::SetEnvironmentVariable(
        "Path",
        $nuevoPath,
        "Machine"
    )

    Write-Host "Java agregado al PATH." -ForegroundColor Green

}
else {

    Write-Host "Java ya estaba agregado al PATH." -ForegroundColor Green
}


# También actualizar variables de ESTA ventana
$env:JAVA_HOME = $javaHome
$env:Path = "$javaBin;$env:Path"


# ------------------------------------------------------------
# 6. Instalar NetBeans
# ------------------------------------------------------------

Write-Host ""
Write-Host "[6/6] Instalando / actualizando Apache NetBeans..." -ForegroundColor Yellow

winget install `
    --id Apache.NetBeans `
    --exact `
    --silent `
    --accept-package-agreements `
    --accept-source-agreements


# ------------------------------------------------------------
# Verificación
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

java -version

Write-Host ""
Write-Host "Zulu encontrado en PATH:" -ForegroundColor Yellow

[Environment]::GetEnvironmentVariable("Path", "Machine") `
    -split ";" |
    Select-String "Zulu"

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host " PROCESO TERMINADO" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

Write-Host ""
Write-Host "Puedes cerrar esta ventana." -ForegroundColor White
Write-Host ""

pause