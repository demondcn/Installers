@echo off
setlocal
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "PROGRAMS=%APPDATA%\Microsoft\Windows\Start Menu\Programs"
del /Q "%STARTUP%\Replit_Abrir_Despues.vbs" 2>nul
del /Q "%PROGRAMS%\Replit.url" 2>nul
echo Se han eliminado el inicio automatico y el acceso de Replit.
echo No se ha tocado Limpieza.bat.
pause
