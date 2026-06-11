# Fix stuck Android emulator (package manager / install failures).
param(
  [string]$Device = ""
)

Set-Location $PSScriptRoot

$adb = Join-Path $env:ANDROID_HOME "platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
  Write-Error "adb not found. Set ANDROID_HOME."
  exit 1
}

function Get-EmulatorSerials {
  $serials = @()
  $lines = & $adb devices 2>$null
  foreach ($line in $lines) {
    $trimmed = "$line".Trim()
    if ($trimmed -match '^(emulator-\d+)\s+(\S+)') {
      $serials += [PSCustomObject]@{
        Serial = $Matches[1]
        State  = $Matches[2]
      }
    }
  }
  return $serials
}

function Show-ConnectedDevices {
  Write-Host ""
  Write-Host "Connected devices:"
  & $adb devices -l 2>$null
  Write-Host ""
}

function Resolve-TargetSerial {
  param([string]$Requested)

  if ($Requested) {
    return $Requested
  }

  $emulators = @(Get-EmulatorSerials)
  $online = @($emulators | Where-Object { $_.State -eq "device" })
  if ($online.Count -eq 1) {
    return $online[0].Serial
  }
  if ($online.Count -gt 1) {
    Write-Error "Multiple online emulators. Pass serial: ./fix_emulator.sh emulator-5554"
    exit 1
  }

  $offline = @($emulators | Where-Object { $_.State -eq "offline" })
  if ($offline.Count -gt 0) {
    Show-ConnectedDevices
    Write-Host "Emulator $($offline[0].Serial) is offline."
    Write-Host "Close it, then Android Studio -> Device Manager -> Cold Boot Now."
    Write-Host "Or: adb -s $($offline[0].Serial) emu kill   (then start the AVD again)"
    exit 1
  }

  Show-ConnectedDevices
  Write-Host "No emulator running."
  Write-Host "  1. Android Studio -> Device Manager -> Run your AVD"
  Write-Host "  2. Wait until: adb devices   shows emulator-5554   device"
  Write-Host "  3. Re-run: ./fix_emulator.sh"
  exit 1
}

$serial = Resolve-TargetSerial -Requested $Device.Trim()
Write-Host "Targeting emulator: $serial"

function Invoke-Adb {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
  & $adb -s $serial @Args
}

function Test-PackageManager {
  Invoke-Adb shell pm list packages 2>$null | Out-Null
  return $LASTEXITCODE -eq 0
}

if (Test-PackageManager) {
  Write-Host "Emulator looks healthy."
  Invoke-Adb reverse tcp:8000 tcp:8000 2>$null | Out-Null
  exit 0
}

Write-Host "Emulator package manager stuck. Rebooting $serial ..."
Invoke-Adb reboot 2>$null | Out-Null
& $adb -s $serial wait-for-device

for ($i = 0; $i -lt 24; $i++) {
  $raw = Invoke-Adb shell getprop sys.boot_completed 2>$null
  $boot = if ($null -ne $raw) { "$raw".Trim() } else { "" }
  if ($boot -eq "1") { break }
  Start-Sleep -Seconds 5
}

if (-not (Test-PackageManager)) {
  Write-Host "Still broken. Close the emulator and use AVD Manager -> Cold Boot Now."
  exit 1
}

Write-Host "Emulator recovered."
Invoke-Adb reverse tcp:8000 tcp:8000 2>$null | Out-Null
