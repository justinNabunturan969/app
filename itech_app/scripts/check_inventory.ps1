# scripts/check_inventory.ps1
# Diagnostic: snapshot equipment counts + open-borrowing counts + the
# discrepancy between them. READ-ONLY — no writes, no auth needed beyond
# the anon key already in supabase.json.
#
# Usage:  powershell -File scripts/check_inventory.ps1
#         (or just open in VS Code and run)

$ErrorActionPreference = 'Stop'

$url    = 'https://obwdgxcfxxixnuqsjfpu.supabase.co'
$anon   = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9id2RneGNmeHhpeG51cXNqZnB1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU2MzkwMjYsImV4cCI6MjEwMTIxNTAyNn0.Nb1VQlS13rmOlbziFSRzVJR80S069yZtb4G-1VqM3WI'
$hdrs   = @{ 'apikey' = $anon; 'Authorization' = "Bearer $anon" }

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
