# Fix stuck Android emulator (package manager / install failures).
Set-Location $PSScriptRoot

$adb = Join-Path $env:ANDROID_HOME "platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
  Write-Error "adb not found. Set ANDROID_HOME."
  exit 1
}

function Test-PackageManager {
  & $adb shell pm list packages 2>$null | Out-Null
  return $LASTEXITCODE -eq 0
}

if (Test-PackageManager) {
  Write-Host "Emulator looks healthy."
  & $adb reverse tcp:8000 tcp:8000 2>$null
  exit 0
}

Write-Host "Emulator package manager stuck. Rebooting..."
& $adb reboot 2>$null
& $adb wait-for-device

for ($i = 0; $i -lt 24; $i++) {
  $boot = (& $adb shell getprop sys.boot_completed 2>$null).Trim()
  if ($boot -eq "1") { break }
  Start-Sleep -Seconds 5
}

if (-not (Test-PackageManager)) {
  Write-Host "Still broken. Close the emulator and use AVD Manager -> Cold Boot Now."
  exit 1
}

Write-Host "Emulator recovered."
& $adb reverse tcp:8000 tcp:8000 2>$null
