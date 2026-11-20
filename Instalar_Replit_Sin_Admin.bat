@echo off
setlocal
chcp 65001 >nul
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "PROGRAMS=%APPDATA%\Microsoft\Windows\Start Menu\Programs"
set "DEST=%STARTUP%\Replit_Abrir_Despues.vbs"
set "ACCESO=%PROGRAMS%\Replit.url"

echo ================================================
echo  INSTALAR REPLIT - SIN ADMINISTRADOR
 echo  No modifica Limpieza.bat ni el Registro.
echo ================================================
echo.
if not exist "%STARTUP%" mkdir "%STARTUP%" 2>nul
if not exist "%STARTUP%" (
  echo [ERROR] No hay acceso a la carpeta Inicio del usuario.
  pause
  exit /b 1
)
if not exist "%~dp0Replit_Abrir_Despues.vbs" (
  echo [ERROR] Falta Replit_Abrir_Despues.vbs junto al instalador.
  pause
  exit /b 1
)
copy /Y "%~dp0Replit_Abrir_Despues.vbs" "%DEST%" >nul
if errorlevel 1 (
  echo [ERROR] Windows no permitio configurar el inicio automatico.
  pause
  exit /b 1
)
> "%ACCESO%" echo [InternetShortcut]
>> "%ACCESO%" echo URL=https://apps-script-frontend.replit.app/
if not exist "%ACCESO%" (
  echo [ADVERTENCIA] Se instalo la apertura automatica, pero no el acceso en Inicio.
) else (
  echo [OK] Acceso a Replit creado en el menu Inicio de Windows.
)
echo [OK] Apertura automatica configurada para este usuario.
echo Chrome intentara abrir Replit 10 minutos despues del inicio de sesion.
echo.
echo No crea un marcador interno de Chrome. La opcion en Inicio sobrevivira
 echo siempre que los scripts de limpieza no borren esa carpeta.
echo.
pause
