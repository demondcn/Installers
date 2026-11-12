$ErrorActionPreference = 'Stop'
try {
    $dest = Join-Path $env:LOCALAPPDATA 'GimnasioAnuncios'
    $audioDest = Join-Path $dest 'Audio'
    New-Item -ItemType Directory -Force -Path $audioDest | Out-Null
    foreach ($h in @('0845','0855','0900')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Audio\$h.wav") -Destination (Join-Path $audioDest "$h.wav") -Force
    }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Reproducir.ps1') -Destination (Join-Path $dest 'Reproducir.ps1') -Force
    $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $principal = New-ScheduledTaskPrincipal -UserId $sid -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    foreach ($item in @(@('0845','20:45'),@('0855','20:55'),@('0900','21:00'))) {
        $h = $item[0]; $time = $item[1]
        $action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$dest\Reproducir.ps1`" -Hora $h" -WorkingDirectory $dest
        $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At $time
        Register-ScheduledTask -TaskName "Gimnasio_Anuncio_$h" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
        Write-Host "OK: Gimnasio_Anuncio_$h - lunes a viernes $time"
    }
    Write-Host "`nInstalacion completada. Archivos en: $dest" -ForegroundColor Green
    Write-Host 'IMPORTANTE: Mantener sesion iniciada, equipo despierto, bocinas activas y volumen adecuado.'
    Write-Host 'Para probar: ejecutar PROBAR_AUDIOS.bat en la carpeta extraida.'
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Si aparece Acceso denegado, ejecutar INSTALAR.bat como administrador desde la cuenta del gimnasio.'
    exit 1
}
