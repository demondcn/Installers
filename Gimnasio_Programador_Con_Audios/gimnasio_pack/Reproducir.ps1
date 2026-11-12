param([ValidateSet('0845','0855','0900')][string]$Hora)
$ErrorActionPreference = 'Stop'
$audio = Join-Path $PSScriptRoot "Audio\$Hora.wav"
if (-not (Test-Path -LiteralPath $audio)) { throw "No existe el audio: $audio" }
$player = New-Object System.Media.SoundPlayer($audio)
$player.Load()
$player.PlaySync()
