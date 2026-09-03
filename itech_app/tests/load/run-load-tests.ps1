# tests/load/run-load-tests.ps1
#
# PowerShell runner for the k6 load tests. Reads Supabase URL and
# anon key from a local .env file (NOT tracked in git) or from
# environment variables, and runs each scenario.
#
# Why this exists:
#   - k6 is the only test runner that natively handles 800+ VUs in
#     a single process and produces the metrics you need for the
#     thesis.
#   - We don't want to commit SUPABASE_URL / SUPABASE_ANON_KEY in
#     any tracked file (see security-audit-2026-09-03.md §2.2 H1).
#   - PowerShell keeps the invocation one-liner-friendly on Windows
#     without forcing you through WSL.
#
# Prerequisites:
#   1. Install k6:  winget install k6 --source winget
#      (or download from https://k6.io/docs/getting-started/installation/)
#   2. Copy tests/load/.env.example to tests/load/.env and fill in:
#        SUPABASE_URL
#        SUPABASE_ANON_KEY
#        STUDENT_DOMAIN         (default: pup.edu.ph)
#        STUDENT_EMAIL          (for scenario 02)
#        STUDENT_PASSWORD       (for scenario 02)
#        LEGIT_EMAIL            (optional, for scenario 03c)
#        LEGIT_PASSWORD         (optional, for scenario 03c)
#
# Usage:
#   .\tests\load\run-load-tests.ps1 -Scenario 1
#   .\tests\load\run-load-tests.ps1 -Scenario 2
#   .\tests\load\run-load-tests.ps1 -Scenario 3
#   .\tests\load\run-load-tests.ps1 -Scenario all
#
# Each scenario writes its summary to tests/load/results/<date>/<n>.json
# for inclusion in the thesis appendix.

[CmdletBinding()]
param(
    [ValidateSet('1', '2', '3', 'all')]
    [string]$Scenario = '1',

    [string]$EnvFile = "$PSScriptRoot\.env"
)

$ErrorActionPreference = 'Stop'

# ── 1. Verify k6 is installed ───────────────────────────────────────
$k6 = Get-Command k6 -ErrorAction SilentlyContinue
if (-not $k6) {
    Write-Error "k6 not found. Install it:  winget install k6 --source winget`nSee https://k6.io/docs/getting-started/installation/"
}
Write-Host "==> Using k6 at $($k6.Source)" -ForegroundColor Cyan

# ── 2. Load .env into the current process ───────────────────────────
if (Test-Path $EnvFile) {
    Write-Host "==> Loading env from $EnvFile" -ForegroundColor Cyan
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }
        if ($_ -match '^\s*([^=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            # Strip optional surrounding quotes
            $value = $value.Trim('"', "'")
            Set-Item -Path "Env:$name" -Value $value
        }
    }
} else {
    Write-Warning "No .env file at $EnvFile. Falling back to existing process env. Copy .env.example to .env and fill in values."
}

# ── 3. Sanity-check required vars ───────────────────────────────────
$required = @('SUPABASE_URL', 'SUPABASE_ANON_KEY')
foreach ($var in $required) {
    $val = Get-Item "Env:$var" -ErrorAction SilentlyContinue
    if (-not $val -or [string]::IsNullOrWhiteSpace($val.Value) -or $val.Value -like '*YOUR*') {
        Write-Error "Required env var `$env:$var is missing or still has the placeholder. Update $EnvFile."
    }
}

# ── 4. Prepare results directory ────────────────────────────────────
$date = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$resultsDir = Join-Path $PSScriptRoot "results\$date"
New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null
Write-Host "==> Results dir: $resultsDir" -ForegroundColor Cyan

# ── 5. Run the requested scenario(s) ────────────────────────────────
function Invoke-K6 {
    param(
        [string]$Name,
        [string]$Script
    )
    $summaryJson = Join-Path $resultsDir "$Name-summary.json"
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Yellow
    Write-Host "  Scenario: $Name" -ForegroundColor Yellow
    Write-Host "  Script:   $Script" -ForegroundColor Yellow
    Write-Host "  Output:   $summaryJson" -ForegroundColor Yellow
    Write-Host "================================================================" -ForegroundColor Yellow

    # k6 supports -e KEY=value for env vars and --summary-export for JSON
    k6 run `
        --summary-export "$summaryJson" `
        -e SUPABASE_URL=$env:SUPABASE_URL `
        -e SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY `
        -e STUDENT_DOMAIN=$env:STUDENT_DOMAIN `
        -e STUDENT_EMAIL=$env:STUDENT_EMAIL `
        -e STUDENT_PASSWORD=$env:STUDENT_PASSWORD `
        -e LEGIT_EMAIL=$env:LEGIT_EMAIL `
        -e LEGIT_PASSWORD=$env:LEGIT_PASSWORD `
        $Script
}

switch ($Scenario) {
    '1'   { Invoke-K6 -Name '01-login-burst'     -Script "$PSScriptRoot\scenarios\01-login-burst.js" }
    '2'   { Invoke-K6 -Name '02-realtime-live'   -Script "$PSScriptRoot\scenarios\02-realtime-live-tab.js" }
    '3'   { Invoke-K6 -Name '03-rpc-under-load'  -Script "$PSScriptRoot\scenarios\03-rpc-under-load.js" }
    'all' {
        Invoke-K6 -Name '01-login-burst'     -Script "$PSScriptRoot\scenarios\01-login-burst.js"
        Invoke-K6 -Name '02-realtime-live'   -Script "$PSScriptRoot\scenarios\02-realtime-live-tab.js"
        # Wait at least 15 minutes between scenarios 1 and 3 to let the
        # per-IP rate-limit window expire (15 min from migration 0022),
        # otherwise scenario 3 inherits a locked IP from scenario 1.
        if ($env:STUDENT_EMAIL) {
            Invoke-K6 -Name '03-rpc-under-load' -Script "$PSScriptRoot\scenarios\03-rpc-under-load.js"
        } else {
            Write-Warning "Skipping scenario 03 — it requires STUDENT_EMAIL / STUDENT_PASSWORD to be set."
        }
    }
}

Write-Host ""
Write-Host "==> All done. Summaries in $resultsDir" -ForegroundColor Green
