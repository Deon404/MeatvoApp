# Allow inbound TCP 8080 for Wi‑Fi physical device testing. Run as Administrator.
# Right-click PowerShell → Run as administrator, then:
#   cd frontend\scripts
#   .\setup-firewall.ps1

$ruleName = "Meatvo Backend Dev 8080"
$existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Firewall rule already exists: $ruleName"
} else {
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8080 | Out-Null
    Write-Host "Added firewall rule: $ruleName (TCP 8080 inbound)"
}
Write-Host "Set API_BASE_URL=http://YOUR_PC_IP:8080 in assets/env.defaults (ipconfig → Wi-Fi IPv4)"
