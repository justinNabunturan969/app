# scripts/check_inventory.ps1
# Diagnostic: snapshot equipment counts + open-borrowing counts + the
# discrepancy between them. READ-ONLY — no writes, no auth needed beyond
# the anon key.
#
# CREDENTIALS:
#   Reads SUPABASE_URL and SUPABASE_ANON_KEY from the process environment.
#   Previously hardcoded inline (git-tracked, public) — that was a
#   security issue (see docs/security-audit-2026-09-03.md §2.2 H1).
#
#   Two ways to set them:
#     1. Inline (PowerShell):
#          $env:SUPABASE_URL    = 'https://x.supabase.co'
#          $env:SUPABASE_ANON_KEY = 'eyJ...'
#          powershell -File scripts/check_inventory.ps1
#     2. From scripts/.env (use the template in scripts/.env.example):
#          Get-Content scripts/.env | ForEach-Object { ... }   # load into $env:
#          powershell -File scripts/check_inventory.ps1
#
# Usage:
#   powershell -File scripts/check_inventory.ps1

$ErrorActionPreference = 'Stop'

# Optional: load scripts/.env if present so the user can run the script
# with no extra setup. Lines starting with '#' and blanks are skipped.
$envFile = Join-Path $PSScriptRoot '.env'
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { return }
        if ($line -match '^([^=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim().Trim('"', "'")
            if (-not (Test-Path "Env:$name")) {
                Set-Item -Path "Env:$name" -Value $value
            }
        }
    }
}

if (-not $env:SUPABASE_URL -or -not $env:SUPABASE_ANON_KEY) {
    Write-Error "Missing credentials. Set SUPABASE_URL and SUPABASE_ANON_KEY in your environment, or create scripts/.env from scripts/.env.example."
}

$url  = $env:SUPABASE_URL
$anon = $env:SUPABASE_ANON_KEY
$hdrs = @{ 'apikey' = $anon; 'Authorization' = "Bearer $anon" }

function Get-RestJson($path) {
    return Invoke-RestMethod -Uri "$url$path" -Headers $hdrs -Method GET
}

Write-Host 'Reading equipment rows...' -ForegroundColor Cyan
$equipment = Get-RestJson '/rest/v1/equipment?select=id,code,name,available_count,total_count&order=code'
Write-Host ("  got {0} rows" -f $equipment.Count)

Write-Host 'Reading open borrowings (active / overdue / return_requested)...' -ForegroundColor Cyan
$openBorrowings = Get-RestJson '/rest/v1/borrowings?select=id,equipment_id,status,quantity&status=in.(active,overdue,return_requested)&limit=500'
Write-Host ("  got {0} rows" -f $openBorrowings.Count)

# Compute expected available_count per equipment id.
$openByEquip = @{}
foreach ($b in $openBorrowings) {
    $qty = if ($b.quantity) { $b.quantity } else { 1 }
    if ($openByEquip.ContainsKey($b.equipment_id)) {
        $openByEquip[$b.equipment_id] += $qty
    } else {
        $openByEquip[$b.equipment_id] = $qty
    }
}

# Build the drift report.
$drift = @()
foreach ($e in $equipment) {
    $out = if ($openByEquip.ContainsKey($e.id)) { $openByEquip[$e.id] } else { 0 }
    $expectedAvail = [Math]::Max(0, [Math]::Min($e.total_count, $e.total_count - $out))
    if ($e.available_count -ne $expectedAvail) {
        $drift += [pscustomobject]@{
            Code            = $e.code
            Name            = $e.name
            Total           = $e.total_count
            OpenUnits       = $out
            AvailableNow    = $e.available_count
            ShouldBe        = $expectedAvail
            Diff            = $e.available_count - $expectedAvail
        }
    }
}

Write-Host ''
Write-Host '=== Equipment with count drift ===' -ForegroundColor Yellow
if ($drift.Count -eq 0) {
    Write-Host '  (none — every available_count matches the open-borrowing count)' -ForegroundColor Green
} else {
    $drift | Format-Table -AutoSize
}

Write-Host ''
Write-Host '=== All equipment (current state) ===' -ForegroundColor Cyan
$equipment | ForEach-Object {
    [pscustomobject]@{
        Code      = $_.code
        Name      = $_.name
        Available = $_.available_count
        Total     = $_.total_count
    }
} | Format-Table -AutoSize
