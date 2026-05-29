# Reliable Android launch on Windows (avoids debug disconnects on emulator).
Set-Location $PSScriptRoot

$vmPort = 58162
$adb = Join-Path $env:ANDROID_HOME "platform-tools\adb.exe"

function Test-PackageManager {
  if (-not (Test-Path $adb)) { return $true }
  & $adb shell pm list packages 2>$null | Out-Null
  return $LASTEXITCODE -eq 0
}

if (Test-Path $adb) {
  if (-not (Test-PackageManager)) {
    Write-Host "Emulator package manager stuck. Rebooting..."
    & $adb reboot 2>$null
    & $adb wait-for-device
    for ($i = 0; $i -lt 24; $i++) {
      $boot = (& $adb shell getprop sys.boot_completed 2>$null).Trim()
      if ($boot -eq "1") { break }
      Start-Sleep -Seconds 5
    }
    if (-not (Test-PackageManager)) {
      Write-Error "Emulator still unhealthy. Use AVD Manager -> Cold Boot Now."
      exit 1
    }
  }
  & $adb reverse tcp:8000 tcp:8000 2>$null
}

$argsList = @(
  "--no-dds",
  "--host-vmservice-port=$vmPort",
  "--device-timeout=120",
  "--dart-define=USE_ADB_REVERSE=true"
)
if (Test-Path "env/dev.json") {
  $argsList += "--dart-define-from-file=env/dev.json"
}

& flutter run @argsList @args
