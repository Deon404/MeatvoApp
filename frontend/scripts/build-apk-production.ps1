# Production APK - points at https://meatvo.com (Hostinger VPS backend).
# Usage (from frontend/):  .\scripts\build-apk-production.ps1
# Output: build/app/outputs/flutter-apk/app-release.apk

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

if (-not (Test-Path "env.production.json")) {
    Write-Error "Missing env.production.json - copy env.production.example.json and set your domain."
}

Write-Host "Validating env.production.json ..."
dart run tool/validate_env.dart --production
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$mapsKey = ""
$secretsProps = Join-Path "android" "secrets.properties"
if (Test-Path $secretsProps) {
    Get-Content $secretsProps | ForEach-Object {
        if ($_ -match '^\s*GOOGLE_MAPS_API_KEY=(.+)$') {
            $mapsKey = $Matches[1].Trim()
        }
    }
}
if (-not $mapsKey -and (Test-Path ".env")) {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^\s*GOOGLE_MAPS_API_KEY=(.+)$') {
            $mapsKey = $Matches[1].Trim().Trim('"')
        }
    }
}

$defines = @("--dart-define-from-file=env.production.json")
if ($mapsKey) {
    $defines += "--dart-define=GOOGLE_MAPS_API_KEY=$mapsKey"
    Write-Host "Using GOOGLE_MAPS_API_KEY from android/secrets.properties or .env"
} else {
    Write-Warning "GOOGLE_MAPS_API_KEY not found - maps/Places may not work in release APK."
}

# assets/env.local is bundled in pubspec — strip dev LAN URL so release cannot pick it up.
$envLocal = Join-Path "assets" "env.local"
$envLocalBackup = Join-Path "assets" "env.local.build-backup"
$envLocalStripped = $false
if (Test-Path $envLocal) {
    Copy-Item $envLocal $envLocalBackup -Force
    $envLocalStripped = $true
    @(
        "# Stripped for production build — API_BASE_URL comes from env.production.json only.",
        "APP_ENV=production"
    ) | Set-Content $envLocal -Encoding utf8
    Write-Host "Stripped dev API_BASE_URL from assets/env.local for this build."
}

try {
    Write-Host "Building production APK (API -> https://meatvo.com) ..."
    flutter build apk --release @defines
} finally {
    if ($envLocalStripped -and (Test-Path $envLocalBackup)) {
        Move-Item $envLocalBackup $envLocal -Force
        Write-Host "Restored assets/env.local"
    }
}

Write-Host ""
Write-Host "Done: build/app/outputs/flutter-apk/app-release.apk"
Write-Host "Share this APK with users - it connects to the live server at meatvo.com."
