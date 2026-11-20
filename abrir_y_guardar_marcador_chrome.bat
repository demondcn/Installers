@echo off
setlocal
set "URL=https://apps-script-frontend.replit.app/"
set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%LocalAppData%\Google\Chrome\Application\chrome.exe"

if not exist "%CHROME%" (
    echo No se encontro Google Chrome en las rutas habituales.
    pause
    exit /b 1
)

echo Abriendo la pagina en Google Chrome...
start "" "%CHROME%" --new-window "%URL%"
timeout /t 5 /nobreak >nul

powershell -NoProfile -Command "$ws = New-Object -ComObject WScript.Shell; if ($ws.AppActivate('Google Chrome')) { Start-Sleep -Milliseconds 500; $ws.SendKeys('^d'); Start-Sleep -Milliseconds 900; $ws.SendKeys('{ENTER}'); Write-Host 'Listo: se intento guardar la pagina en Marcadores.' } else { Write-Host 'La pagina se abrio, pero no se pudo activar Chrome. Para guardarla, pulsa Ctrl+D y luego Enter.' }"

echo.
echo Comprueba que el marcador aparezca en Chrome.
pause
endlocal
