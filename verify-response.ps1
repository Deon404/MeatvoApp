<#
.SYNOPSIS
    MeatvoApp API Response Consistency Verifier
.DESCRIPTION
    Verifies that every tested endpoint always returns the standard JSON envelope:
        Success  → { ok: true,  success: true,  data: {...}, message: "..." }
        Failure  → { ok: false, success: false, error: {...}, data: {...}, message: "..." }

    Rules checked per response
      ✔  "success" field exists
      ✔  "ok"      field exists
      ✔  "data"    OR "error" field exists
      ✔  success === ok  (they must never diverge)
      ✔  Failure responses contain an "error" object with a "message" key

.PARAMETER BaseUrl
    API base URL.  Default: http://localhost:8080

.PARAMETER Token
    Optional JWT Bearer token.
    When supplied: protected-endpoint happy-path tests are also executed.
    When omitted:  only failure/unauthenticated tests run for protected routes.

.PARAMETER TestPhone
    Phone number used for OTP tests.  Default: +919000000001

.EXAMPLE
    # Basic run (no live auth)
    .\verify-response.ps1

.EXAMPLE
    # Full run with a valid JWT
    .\verify-response.ps1 -Token "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

.EXAMPLE
    # Custom base URL
    .\verify-response.ps1 -BaseUrl "http://192.168.1.10:8080" -TestPhone "+919876543210"
#>

[CmdletBinding()]
param(
    [string] $BaseUrl   = "http://localhost:8080",
    [string] $Token     = "",
    [string] $TestPhone = "+919000000001"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─────────────────────────────────────────────────────────────────
#  State
# ─────────────────────────────────────────────────────────────────
$script:PassCount = 0
$script:FailCount = 0
$script:Results   = [System.Collections.Generic.List[PSCustomObject]]::new()

# ─────────────────────────────────────────────────────────────────
#  UI helpers
# ─────────────────────────────────────────────────────────────────
function Write-Banner([string]$Title) {
    $pad  = "─" * 62
    Write-Host ""
    Write-Host $pad                       -ForegroundColor Cyan
    Write-Host ("  " + $Title)           -ForegroundColor Cyan
    Write-Host $pad                       -ForegroundColor Cyan
}

function Record-Result {
    param(
        [string] $TestName,
        [bool]   $Passed,
        [string] $Detail = ""
    )
    if ($Passed) {
        $script:PassCount++
        Write-Host ("  [PASS] " + $TestName) -ForegroundColor Green
    } else {
        $script:FailCount++
        Write-Host ("  [FAIL] " + $TestName) -ForegroundColor Red
    }
    if ($Detail) {
        Write-Host ("         " + $Detail)   -ForegroundColor DarkGray
    }
    $script:Results.Add([PSCustomObject]@{
        Test   = $TestName
        Result = if ($Passed) { "PASS" } else { "FAIL" }
        Detail = $Detail
    })
}

# ─────────────────────────────────────────────────────────────────
#  HTTP helper — swallows 4xx/5xx so we can inspect the body
# ─────────────────────────────────────────────────────────────────
function Invoke-Api {
    param(
        [string]    $Method,
        [string]    $Path,
        [hashtable] $Body        = $null,
        [string]    $BearerToken = ""
    )

    $uri     = $BaseUrl + $Path
    $headers = @{
        "Content-Type" = "application/json"
        "Accept"       = "application/json"
    }
    if ($BearerToken) {
        $headers["Authorization"] = "Bearer $BearerToken"
    }

    $params = @{
        Method          = $Method
        Uri             = $uri
        Headers         = $headers
        UseBasicParsing = $true
        TimeoutSec      = 15
        ErrorAction     = "Stop"
    }
    if ($null -ne $Body) {
        $params["Body"] = ($Body | ConvertTo-Json -Depth 10 -Compress)
    }

    try {
        $resp = Invoke-WebRequest @params
        return [PSCustomObject]@{
            StatusCode = [int]$resp.StatusCode
            Body       = ($resp.Content | ConvertFrom-Json -ErrorAction SilentlyContinue)
            Raw        = $resp.Content
            Error      = $null
        }
    }
    catch [System.Net.WebException] {
        $httpResp   = $_.Exception.Response
        $statusCode = if ($httpResp) { [int]$httpResp.StatusCode } else { 0 }
        $raw        = ""
        if ($httpResp) {
            try {
                $stream = $httpResp.GetResponseStream()
                $reader = [System.IO.StreamReader]::new($stream)
                $raw    = $reader.ReadToEnd()
                $reader.Close()
            } catch {}
        }
        $parsed = $null
        if ($raw) {
            try { $parsed = $raw | ConvertFrom-Json -ErrorAction SilentlyContinue } catch {}
        }
        return [PSCustomObject]@{
            StatusCode = $statusCode
            Body       = $parsed
            Raw        = $raw
            Error      = $_.Exception.Message
        }
    }
    catch {
        return [PSCustomObject]@{
            StatusCode = 0
            Body       = $null
            Raw        = ""
            Error      = $_.Exception.Message
        }
    }
}

# ─────────────────────────────────────────────────────────────────
#  Core validator — checks the standard Meatvo envelope
#
#  $ExpectSuccess = $true  → expects success=true  (2xx response)
#  $ExpectSuccess = $false → expects success=false (4xx/5xx response)
#  $ExpectSuccess = $null  → only checks fields exist, ignores value
# ─────────────────────────────────────────────────────────────────
function Assert-Envelope {
    param(
        [string]  $TestName,
        [object]  $Response,
        [nullable[bool]] $ExpectSuccess = $null
    )

    # ── Connection-level failure ──────────────────────────────────
    if ($Response.StatusCode -eq 0) {
        Record-Result -TestName $TestName -Passed $false `
            -Detail "Connection failed — is the server running? ($($Response.Error))"
        return $false
    }

    $body = $Response.Body

    # ── Non-JSON response ─────────────────────────────────────────
    if ($null -eq $body) {
        Record-Result -TestName $TestName -Passed $false `
            -Detail "HTTP $($Response.StatusCode) — empty or non-JSON body"
        return $false
    }

    $props      = $body.PSObject.Properties.Name
    $hasSuccess = $props -contains "success"
    $hasOk      = $props -contains "ok"
    $hasData    = $props -contains "data"
    $hasError   = $props -contains "error"

    # ── Required fields ───────────────────────────────────────────
    if (-not $hasSuccess) {
        Record-Result -TestName $TestName -Passed $false -Detail "Missing field: 'success'"
        return $false
    }
    if (-not $hasOk) {
        Record-Result -TestName $TestName -Passed $false -Detail "Missing field: 'ok'"
        return $false
    }
    if (-not $hasData -and -not $hasError) {
        Record-Result -TestName $TestName -Passed $false -Detail "Neither 'data' nor 'error' field present"
        return $false
    }

    # ── success must equal ok ─────────────────────────────────────
    $sv = [bool]$body.success
    $ov = [bool]$body.ok
    if ($sv -ne $ov) {
        Record-Result -TestName $TestName -Passed $false `
            -Detail "Divergence: success=$sv but ok=$ov (must be identical)"
        return $false
    }

    # ── Expected success value ────────────────────────────────────
    if ($null -ne $ExpectSuccess) {
        if ($ExpectSuccess -and -not $sv) {
            Record-Result -TestName $TestName -Passed $false `
                -Detail "Expected success=true but got success=false (HTTP $($Response.StatusCode))"
            return $false
        }
        if (-not $ExpectSuccess -and $sv) {
            Record-Result -TestName $TestName -Passed $false `
                -Detail "Expected success=false but got success=true (HTTP $($Response.StatusCode))"
            return $false
        }
    }

    # ── Error responses must have error.message ───────────────────
    if (-not $sv) {
        if (-not $hasError) {
            Record-Result -TestName $TestName -Passed $false `
                -Detail "Failure response missing 'error' field"
            return $false
        }
        $errMsg = $body.error.PSObject.Properties.Name -contains "message"
        if (-not $errMsg) {
            Record-Result -TestName $TestName -Passed $false `
                -Detail "'error' object missing 'message' key"
            return $false
        }
    }

    $successLabel = if ($sv) { "success=true" } else { "success=false" }
    Record-Result -TestName $TestName -Passed $true `
        -Detail "HTTP $($Response.StatusCode) | $successLabel | ok=$ov | fields valid"
    return $true
}

# Helper: assert a specific HTTP status code
function Assert-StatusCode {
    param([string]$TestName, [object]$Response, [int[]]$Expected)
    $got    = $Response.StatusCode
    $passed = $Expected -contains $got
    $label  = $Expected -join " or "
    Record-Result -TestName $TestName -Passed $passed `
        -Detail "Expected HTTP $label, got HTTP $got"
}

# ═══════════════════════════════════════════════════════════════════
#  SERVER REACHABILITY
# ═══════════════════════════════════════════════════════════════════
Write-Banner "Server reachability  →  $BaseUrl"

$health = Invoke-Api -Method GET -Path "/health"
if ($health.StatusCode -eq 0) {
    Write-Host "  [WARN] Server not reachable at $BaseUrl — remaining tests may fail" `
        -ForegroundColor Yellow
} else {
    Write-Host "  [INFO] Server responded with HTTP $($health.StatusCode)" `
        -ForegroundColor DarkGray
}

# ═══════════════════════════════════════════════════════════════════
#  1. POST /api/auth/send-otp
# ═══════════════════════════════════════════════════════════════════
Write-Banner "POST /api/auth/send-otp"

#  1-A  Valid phone — envelope must be correct whatever HTTP code comes back
$r_sendOtp_valid = Invoke-Api -Method POST -Path "/api/auth/send-otp" `
    -Body @{ phone = $TestPhone }
$expectSend = if ($r_sendOtp_valid.StatusCode -in 200, 429) { [nullable[bool]]$null } else { [nullable[bool]]$false }
Assert-Envelope -TestName "send-otp | valid phone → envelope present" `
    -Response $r_sendOtp_valid -ExpectSuccess $expectSend

if ($r_sendOtp_valid.StatusCode -eq 200) {
    # dev OTP should be present since OTP_LOG_TO_CONSOLE=true
    $hasDevOtp = $r_sendOtp_valid.Body.data.PSObject.Properties.Name -contains "devOTP"
    Record-Result -TestName "send-otp | 200 response has devOTP (dev mode)" -Passed $hasDevOtp `
        -Detail "Useful for CI — grab from data.devOTP for next test"
}
if ($r_sendOtp_valid.StatusCode -eq 429) {
    Assert-Envelope -TestName "send-otp | 429 rate-limit still has valid error envelope" `
        -Response $r_sendOtp_valid -ExpectSuccess $false
}

#  1-B  Missing phone field
$r_sendOtp_noPhone = Invoke-Api -Method POST -Path "/api/auth/send-otp" -Body @{}
Assert-Envelope -TestName "send-otp | missing phone → error envelope" `
    -Response $r_sendOtp_noPhone -ExpectSuccess $false
Assert-StatusCode -TestName "send-otp | missing phone → HTTP 400" `
    -Response $r_sendOtp_noPhone -Expected @(400, 422)

#  1-C  No body at all
$r_sendOtp_nobody = Invoke-Api -Method POST -Path "/api/auth/send-otp"
Assert-Envelope -TestName "send-otp | no body → error envelope" `
    -Response $r_sendOtp_nobody -ExpectSuccess $false

#  1-D  Invalid phone format (letters instead of digits)
$r_sendOtp_badFmt = Invoke-Api -Method POST -Path "/api/auth/send-otp" `
    -Body @{ phone = "not-a-phone" }
Assert-Envelope -TestName "send-otp | invalid phone format → error envelope" `
    -Response $r_sendOtp_badFmt -ExpectSuccess $false

# ═══════════════════════════════════════════════════════════════════
#  2. POST /api/auth/verify-otp
# ═══════════════════════════════════════════════════════════════════
Write-Banner "POST /api/auth/verify-otp"

#  2-A  Missing otp field
$r_verifyOtp_noOtp = Invoke-Api -Method POST -Path "/api/auth/verify-otp" `
    -Body @{ phone = $TestPhone }
Assert-Envelope -TestName "verify-otp | missing otp → error envelope" `
    -Response $r_verifyOtp_noOtp -ExpectSuccess $false
Assert-StatusCode -TestName "verify-otp | missing otp → HTTP 400/422" `
    -Response $r_verifyOtp_noOtp -Expected @(400, 422)

#  2-B  Missing phone field
$r_verifyOtp_noPhone = Invoke-Api -Method POST -Path "/api/auth/verify-otp" `
    -Body @{ otp = "1234" }
Assert-Envelope -TestName "verify-otp | missing phone → error envelope" `
    -Response $r_verifyOtp_noPhone -ExpectSuccess $false

#  2-C  No body at all
$r_verifyOtp_nobody = Invoke-Api -Method POST -Path "/api/auth/verify-otp"
Assert-Envelope -TestName "verify-otp | no body → error envelope" `
    -Response $r_verifyOtp_nobody -ExpectSuccess $false

#  2-D  Wrong OTP for a phone that has no pending OTP in Redis
$r_verifyOtp_wrong = Invoke-Api -Method POST -Path "/api/auth/verify-otp" `
    -Body @{ phone = "+910000000099"; otp = "0000" }
Assert-Envelope -TestName "verify-otp | non-existent OTP session → error envelope" `
    -Response $r_verifyOtp_wrong -ExpectSuccess $false

#  2-E  OTP with invalid format (too short)
$r_verifyOtp_short = Invoke-Api -Method POST -Path "/api/auth/verify-otp" `
    -Body @{ phone = $TestPhone; otp = "12" }
Assert-Envelope -TestName "verify-otp | otp too short → error envelope" `
    -Response $r_verifyOtp_short -ExpectSuccess $false

# ═══════════════════════════════════════════════════════════════════
#  3. GET /api/products  (optionalAuth — public)
# ═══════════════════════════════════════════════════════════════════
Write-Banner "GET /api/products  (public)"

#  3-A  No auth — must succeed
$r_products_public = Invoke-Api -Method GET -Path "/api/products"
Assert-Envelope -TestName "products | no auth → success envelope" `
    -Response $r_products_public -ExpectSuccess $true
Assert-StatusCode -TestName "products | no auth → HTTP 200" `
    -Response $r_products_public -Expected @(200)

if ($r_products_public.StatusCode -eq 200) {
    $data      = $r_products_public.Body.data
    $hasProds  = ($null -ne $data) -and (
        ($data.PSObject.Properties.Name -contains "products") -or
        ($data -is [array])
    )
    Record-Result -TestName "products | data contains products collection" -Passed $hasProds `
        -Detail ("data type: " + $(if ($null -ne $data) { $data.GetType().Name } else { "null" }))
}

#  3-B  With valid token (optional — products endpoint uses optionalAuth)
if ($Token) {
    $r_products_auth = Invoke-Api -Method GET -Path "/api/products" -BearerToken $Token
    Assert-Envelope -TestName "products | valid token → success envelope" `
        -Response $r_products_auth -ExpectSuccess $true
}

#  3-C  Pagination params
$r_products_paged = Invoke-Api -Method GET -Path "/api/products?page=1&limit=5"
Assert-Envelope -TestName "products | pagination params → envelope valid" `
    -Response $r_products_paged -ExpectSuccess $true

# ═══════════════════════════════════════════════════════════════════
#  4. GET /api/orders  (protect — requires auth)
# ═══════════════════════════════════════════════════════════════════
Write-Banner "GET /api/orders  (protected)"

#  4-A  No Authorization header → must fail 401
$r_orders_noToken = Invoke-Api -Method GET -Path "/api/orders"
Assert-Envelope -TestName "orders | no token → 401 error envelope" `
    -Response $r_orders_noToken -ExpectSuccess $false
Assert-StatusCode -TestName "orders | no token → HTTP 401" `
    -Response $r_orders_noToken -Expected @(401)

#  4-B  Malformed token (garbage string)
$r_orders_garbage = Invoke-Api -Method GET -Path "/api/orders" `
    -BearerToken "garbage.token.value"
Assert-Envelope -TestName "orders | malformed token → error envelope" `
    -Response $r_orders_garbage -ExpectSuccess $false
Assert-StatusCode -TestName "orders | malformed token → HTTP 401/403" `
    -Response $r_orders_garbage -Expected @(401, 403)

#  4-C  Structurally-valid JWT with bad signature (wrong secret)
$fakeJwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" +
           ".eyJpZCI6OTk5OTk5LCJpYXQiOjE2MDAwMDAwMDAsImV4cCI6MTYwMDAwMDAwMX0" +
           ".AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
$r_orders_fakeJwt = Invoke-Api -Method GET -Path "/api/orders" `
    -BearerToken $fakeJwt
Assert-Envelope -TestName "orders | fake JWT (bad signature) → error envelope" `
    -Response $r_orders_fakeJwt -ExpectSuccess $false
Assert-StatusCode -TestName "orders | fake JWT → HTTP 401/403" `
    -Response $r_orders_fakeJwt -Expected @(401, 403)

#  4-D  Expired JWT (exp=1 in the past)
$expiredJwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" +
              ".eyJpZCI6MSwiZXhwIjoxfQ" +
              ".AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
$r_orders_expiredJwt = Invoke-Api -Method GET -Path "/api/orders" `
    -BearerToken $expiredJwt
Assert-Envelope -TestName "orders | expired JWT → error envelope" `
    -Response $r_orders_expiredJwt -ExpectSuccess $false

#  4-E  Valid token happy path (only when -Token is supplied)
if ($Token) {
    $r_orders_valid = Invoke-Api -Method GET -Path "/api/orders" -BearerToken $Token
    Assert-Envelope -TestName "orders | valid token → success envelope" `
        -Response $r_orders_valid -ExpectSuccess $true
    Assert-StatusCode -TestName "orders | valid token → HTTP 200" `
        -Response $r_orders_valid -Expected @(200)

    if ($r_orders_valid.StatusCode -eq 200) {
        $ordData    = $r_orders_valid.Body.data
        $hasOrders  = ($null -ne $ordData)
        Record-Result -TestName "orders | data field present in 200 response" -Passed $hasOrders
    }
}

# ═══════════════════════════════════════════════════════════════════
#  5. Cross-endpoint envelope consistency
# ═══════════════════════════════════════════════════════════════════
Write-Banner "Cross-endpoint field consistency"

$crossCheck = @(
    @{ Label = "send-otp (missing phone)";          R = $r_sendOtp_noPhone }
    @{ Label = "verify-otp (missing otp)";          R = $r_verifyOtp_noOtp }
    @{ Label = "verify-otp (invalid session)";      R = $r_verifyOtp_wrong }
    @{ Label = "products (public)";                 R = $r_products_public }
    @{ Label = "orders (no token)";                 R = $r_orders_noToken }
    @{ Label = "orders (malformed token)";          R = $r_orders_garbage }
    @{ Label = "orders (fake JWT)";                 R = $r_orders_fakeJwt }
)

foreach ($entry in $crossCheck) {
    $b = $entry.R.Body
    if ($null -eq $b) { continue }

    $props      = $b.PSObject.Properties.Name
    $hasBoth    = ($props -contains "success") -and ($props -contains "ok")
    $consistent = $hasBoth -and ([bool]$b.success -eq [bool]$b.ok)
    $hasMsgKey  = $props -contains "message"

    Record-Result -TestName "$($entry.Label) | success === ok" `
        -Passed $consistent `
        -Detail ("success=" + $b.success + "  ok=" + $b.ok)

    Record-Result -TestName "$($entry.Label) | 'message' field present" `
        -Passed $hasMsgKey `
        -Detail $(if (-not $hasMsgKey) { "message field missing" } else { "OK" })
}

# ═══════════════════════════════════════════════════════════════════
#  SUMMARY
# ═══════════════════════════════════════════════════════════════════
$total  = $script:PassCount + $script:FailCount
$border = "═" * 62

Write-Host ""
Write-Host $border                                          -ForegroundColor White
Write-Host "  RESULTS SUMMARY"                             -ForegroundColor White
Write-Host $border                                         -ForegroundColor White
Write-Host ("  Total  : " + $total)
Write-Host ("  Passed : " + $script:PassCount)             -ForegroundColor Green
$failColor = if ($script:FailCount -gt 0) { "Red" } else { "Green" }
Write-Host ("  Failed : " + $script:FailCount)             -ForegroundColor $failColor
Write-Host $border                                         -ForegroundColor White

if ($script:FailCount -gt 0) {
    Write-Host ""
    Write-Host "  Failed tests:" -ForegroundColor Red
    $script:Results |
        Where-Object { $_.Result -eq "FAIL" } |
        ForEach-Object {
            Write-Host ("    • " + $_.Test) -ForegroundColor Red
            if ($_.Detail) {
                Write-Host ("      " + $_.Detail) -ForegroundColor DarkGray
            }
        }
}

if (-not $Token) {
    Write-Host ""
    Write-Host "  NOTE: Run with -Token <jwt> to also execute authenticated happy-path tests." `
        -ForegroundColor Yellow
}

Write-Host ""
exit $(if ($script:FailCount -gt 0) { 1 } else { 0 })
