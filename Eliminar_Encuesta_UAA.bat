@echo off
setlocal

echo Eliminando la tarea programada de la encuesta UAA...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Unregister-ScheduledTask -TaskName 'Encuesta_UAA_Satisfaccion' -Confirm:$false -ErrorAction Stop"
if errorlevel 1 (
    echo.
    echo No se encontro la tarea o no se pudo eliminar. Revise el mensaje anterior.
    pause
    exit /b 1
)

echo.
echo Listo. La tarea fue eliminada.
pause
