# verify-response.ps1
# Validates that all health/metrics endpoints return the correct response shape.
# Run from backend folder: powershell -ExecutionPolicy Bypass -File verify-response.ps1

$BASE = "http://localhost:8080"
$script:PASS = 0
$script:FAIL = 0

function Check-Envelope {
  param([string]$Label, [string]$Url, [string]$Method = "GET", [hashtable]$Body = $null)
  try {
    $params = @{ Uri = $Url; Method = $Method; ErrorAction = "Stop" }
    if ($Body) {
      $params.Body    = ($Body | ConvertTo-Json)
      $params.Headers = @{ "Content-Type" = "application/json" }
    }
    $r = Invoke-RestMethod @params
    $hasOk      = $null -ne $r.ok
    $hasSuccess = $null -ne $r.success
    $hasData    = $null -ne $r.data
    $hasMessage = $null -ne $r.message
    if ($hasOk -and $hasSuccess -and $hasData -and $hasMessage) {
      Write-Host "  [PASS] $Label  =>  ok=$($r.ok)  '$($r.message)'" -ForegroundColor Green
      $script:PASS++
    } else {
      Write-Host "  [FAIL] $Label  =>  missing fields: ok=$hasOk success=$hasSuccess data=$hasData message=$hasMessage" -ForegroundColor Red
      $script:FAIL++
    }
  } catch {
    Write-Host "  [FAIL] $Label  =>  $($_.Exception.Message)" -ForegroundColor Red
    $script:FAIL++
  }
}

function Check-Raw {
  param([string]$Label, [string]$Url, [string]$ExpectedField)
  try {
    $r = Invoke-RestMethod -Uri $Url -Method GET -ErrorAction Stop
    if ($null -ne $r.$ExpectedField) {
      Write-Host "  [PASS] $Label  =>  raw '$ExpectedField'='$($r.$ExpectedField)'" -ForegroundColor Green
      $script:PASS++
    } else {
      Write-Host "  [FAIL] $Label  =>  expected raw field '$ExpectedField' missing" -ForegroundColor Red
      $script:FAIL++
    }
  } catch {
    Write-Host "  [FAIL] $Label  =>  $($_.Exception.Message)" -ForegroundColor Red
    $script:FAIL++
  }
}

function Check-PrometheusText {
  param([string]$Label, [string]$Url)
  try {
    $raw = Invoke-WebRequest -Uri $Url -Method GET -ErrorAction Stop
    $ct  = [string]$raw.Headers["Content-Type"]
    if ($ct -match "text/plain" -and $raw.Content -match "# HELP") {
      Write-Host "  [PASS] $Label  =>  Prometheus text/plain confirmed" -ForegroundColor Green
      $script:PASS++
    } else {
      Write-Host "  [FAIL] $Label  =>  unexpected content-type or body (ct=$ct)" -ForegroundColor Red
      $script:FAIL++
    }
  } catch {
    Write-Host "  [FAIL] $Label  =>  $($_.Exception.Message)" -ForegroundColor Red
    $script:FAIL++
  }
}

Write-Host ""
Write-Host "=== Meatvo Response Verification ===" -ForegroundColor Cyan
Write-Host "Target: $BASE"
Write-Host ""

Write-Host "--- Root /health (standard envelope) ---"
Check-Envelope "GET /health"               "$BASE/health"

Write-Host ""
Write-Host "--- Detailed health sub-routes (standard envelope) ---"
Check-Envelope "GET /health/"              "$BASE/health/"
Check-Envelope "GET /health/db"            "$BASE/health/db"
Check-Envelope "GET /health/redis"         "$BASE/health/redis"

Write-Host ""
Write-Host "--- Kubernetes probes (raw JSON, no envelope) ---"
Check-Raw      "GET /health/ready"         "$BASE/health/ready"  "status"
Check-Raw      "GET /health/live"          "$BASE/health/live"   "status"

Write-Host ""
Write-Host "--- Prometheus scrape endpoint (raw text/plain) ---"
Check-PrometheusText "GET /metrics"        "$BASE/metrics"

Write-Host ""
Write-Host "--- Metrics JSON snapshot (standard envelope) ---"
Check-Envelope "GET /metrics/json"         "$BASE/metrics/json"

Write-Host ""
Write-Host "--- Metrics business events (standard envelope) ---"
Check-Envelope "POST /metrics/business/order-created"   "$BASE/metrics/business/order-created"   "POST"
Check-Envelope "POST /metrics/business/order-completed" "$BASE/metrics/business/order-completed" "POST"
Check-Envelope "POST /metrics/business/user-registered" "$BASE/metrics/business/user-registered" "POST"
Check-Envelope "POST /metrics/backup/success"           "$BASE/metrics/backup/success"           "POST"
Check-Envelope "POST /metrics/reset (dev)"              "$BASE/metrics/reset"                    "POST"

Write-Host ""
Write-Host "--- Auth endpoint (standard envelope) ---"
try {
  $otpRes = Invoke-RestMethod -Uri "$BASE/api/auth/send-otp" `
    -Method POST `
    -Body (@{ phone = "+919000000001" } | ConvertTo-Json) `
    -Headers @{ "Content-Type" = "application/json" } `
    -ErrorAction Stop
  if ($otpRes.ok -and $null -ne $otpRes.data.devOTP) {
    Write-Host "  [PASS] POST /api/auth/send-otp  =>  devOTP=$($otpRes.data.devOTP)" -ForegroundColor Green
    $script:PASS++
  } else {
    Write-Host "  [FAIL] POST /api/auth/send-otp  =>  unexpected response" -ForegroundColor Red
    $script:FAIL++
  }
} catch {
  Write-Host "  [SKIP] POST /api/auth/send-otp  =>  $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "======================================="
Write-Host "  PASSED : $($script:PASS)" -ForegroundColor Green
if ($script:FAIL -gt 0) {
  Write-Host "  FAILED : $($script:FAIL)" -ForegroundColor Red
} else {
  Write-Host "  FAILED : $($script:FAIL)" -ForegroundColor Green
}
Write-Host "======================================="
Write-Host ""

if ($script:FAIL -gt 0) { exit 1 } else { exit 0 }
