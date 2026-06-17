# Pack Meatvo repo for VPS upload (run on Windows from repo root)
# Usage: powershell -ExecutionPolicy Bypass -File scripts/vps-pack-deploy.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Out = Join-Path $Root "meatvo-deploy.tar.gz"

if (Test-Path $Out) {
  Remove-Item $Out -Force
}

Push-Location $Root
try {
  tar -czf $Out `
    --exclude=.git `
    --exclude=node_modules `
    --exclude=frontend `
    --exclude=backend/node_modules `
    --exclude=backend/uploads `
    --exclude=backend/.env `
    --exclude=meatvo-deploy.tar.gz `
    .
  Write-Host "Created: $Out"
  Write-Host ""
  Write-Host "Upload to VPS (new Windows terminal):"
  Write-Host "  scp `"$Out`" root@187.127.179.95:/root/"
  Write-Host ""
  Write-Host "On VPS:"
  Write-Host "  mkdir -p /opt/meatvo && tar -xzf /root/meatvo-deploy.tar.gz -C /opt/meatvo"
  Write-Host "  cp /opt/meatvo/backend/.env.vps.example /opt/meatvo/backend/.env"
  Write-Host "  nano /opt/meatvo/backend/.env"
  Write-Host "  bash /opt/meatvo/scripts/vps-phase2-deploy.sh"
}
finally {
  Pop-Location
}
