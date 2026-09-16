@echo off
title FlushDNS x8

for /L %%i in (1,1,8) do (
    echo Ejecutando FlushDNS %%i de 8...
    ipconfig /flushdns
    echo.
)

echo Listo. Se ejecuto ipconfig /flushdns 8 veces.
pause
