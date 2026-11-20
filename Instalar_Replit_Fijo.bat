@echo off
setlocal
set "BASE=%~dp0"
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
title Configurar Replit sin cambiar Limpieza.bat
echo.
echo Configurando marcador permanente y apertura de Chrome...
echo.
if not exist "%BASE%Marcador_Replit.reg" (
 echo ERROR: Falta Marcador_Replit.reg en la misma carpeta.
 pause
 exit /b 1
)
if not exist "%BASE%Abrir_Replit_Despues_Limpieza.vbs" (
 echo ERROR: Falta Abrir_Replit_Despues_Limpieza.vbs.
 pause
 exit /b 1
)
reg query "HKCU\Software\Policies\Google\Chrome" /v ManagedBookmarks >nul 2>&1
if not errorlevel 1 (
 echo AVISO: Ya existe una politica de marcadores administrados.
 echo Por seguridad NO se reemplazara. Se instalara solo la apertura automatica.
) else (
 reg import "%BASE%Marcador_Replit.reg"
 if errorlevel 1 (
  echo ERROR: No se pudo configurar el marcador.
 ) else (
  echo OK: Politica de marcador configurada.
 )
)
if not exist "%STARTUP%" (
 echo ERROR: No se encuentra la carpeta Inicio de Windows.
 pause
 exit /b 1
)
copy /y "%BASE%Abrir_Replit_Despues_Limpieza.vbs" "%STARTUP%\Abrir_Replit_Despues_Limpieza.vbs" >nul
if errorlevel 1 (
 echo ERROR: No se pudo programar el inicio automatico.
 pause
 exit /b 1
)
echo.
echo LISTO: no se ha cambiado ni eliminado Limpieza.bat.
echo Chrome abrira Replit unos 10 minutos despues del siguiente inicio de sesion.
echo Abre chrome://policy para comprobar ManagedBookmarks.
echo OJO: No se preservan cookies ni sesiones borradas por el limpiador.
echo.
pause
