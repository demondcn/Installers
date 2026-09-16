@echo off
title Actualizador de Node.js
color 0A

echo ==========================================
echo        ACTUALIZANDO NODE.JS
echo ==========================================
echo.

echo [1/3] Actualizando fuentes de Winget...
winget source update

echo.
echo [2/3] Actualizando Node.js LTS...
winget upgrade --id OpenJS.NodeJS.LTS -e --silent --accept-package-agreements --accept-source-agreements

if %errorlevel% neq 0 (
    echo.
    echo Node.js LTS no esta instalado o no se pudo actualizar.
    echo Intentando instalar la ultima version LTS...
    winget install --id OpenJS.NodeJS.LTS -e --silent --accept-package-agreements --accept-source-agreements
)

echo.
echo [3/3] Verificando instalacion...
echo.

where node >nul 2>&1
if %errorlevel% equ 0 (
    echo Node:
    node --version
    echo.
    echo NPM:
    npm --version
    echo.
    echo ==========================================
    echo      NODE.JS ACTUALIZADO CORRECTAMENTE
    echo ==========================================
) else (
    echo ==========================================
    echo ERROR: Node no aparece en el PATH.
    echo Puede ser necesario cerrar y abrir la terminal.
    echo ==========================================
)

echo.
pause