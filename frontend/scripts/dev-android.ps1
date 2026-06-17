# Run Flutter on a physical Android device with backend port forwarding.
# USB: adb reverse maps phone localhost:8080 → PC localhost:8080.
# Wi‑Fi: set API_BASE_URL in assets/env.defaults to your PC LAN IP (ipconfig).

$ErrorActionPreference = "Stop"
$frontendRoot = Split-Path $PSScriptRoot -Parent
$adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"

if (Test-Path $adb) {
    & $adb reverse tcp:8080 tcp:8080 | Out-Null
    Write-Host "adb reverse tcp:8080 tcp:8080 (phone 127.0.0.1:8080 -> PC backend)"
    & $adb reverse --list
} else {
    Write-Warning "adb not found. USB debugging needs Android SDK platform-tools."
    Write-Warning "Wi-Fi dev: set API_BASE_URL=http://YOUR_PC_IP:8080 in assets/env.defaults"
}

Set-Location $frontendRoot
flutter run @args
