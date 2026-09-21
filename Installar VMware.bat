@echo off
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Instalar-VMware-Automatico-v2(2).ps1"

pause