# Production APK - points at https://meatvo.com (Hostinger VPS backend).
# Usage (from frontend/):  .\scripts\build-apk-production.ps1
# Output: build/app/outputs/flutter-apk/app-release.apk

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

if (-not (Test-Path "env.production.json")) {
    Write-Error "Missing env.production.json - copy env.production.example.json and set your domain."
}

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

Write-Host "Building production APK (API -> https://meatvo.com) ..."
flutter build apk --release @defines

Write-Host ""
Write-Host "Done: build/app/outputs/flutter-apk/app-release.apk"
Write-Host "Share this APK with users - it connects to the live server at meatvo.com."
