# İP ATLA — tüm testleri ve simülasyonları koşar.
# Kullanım:  powershell -File tests\run_all.ps1  [-Quick]
#   -Quick : yalnız birim testleri (tek Godot süreci, ~2 sn)
#   varsayılan: birim testleri + balans/denetim/replay simülasyonları
param([switch]$Quick)

$godot = "C:\Godot\godot.exe"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$fail = 0

Write-Host "=== BİRİM TESTLERİ (tek süreç) ===" -ForegroundColor Cyan
$out = & $godot --headless "scenes/dev/run_tests.tscn" 2>&1 | Out-String
foreach ($line in ($out -split "`n")) {
  if ($line -match " OK|FAILED|GEÇTİ|BAŞARISIZ|ATLANDI") { Write-Host "  $($line.Trim())" }
}
if ($out -match "BAŞARISIZ") { $fail++ }

if (-not $Quick) {
  $sims = @("sim_audit_f8", "sim_audit_f10", "sim_replay", "sim_balance")
  Write-Host "=== SİMÜLASYON / DENETİM ===" -ForegroundColor Cyan
  foreach ($s in $sims) {
    $o = & $godot --headless "scenes/dev/$s.tscn" 2>&1 | Out-String
    if ($o -match "FAILED|FAIL:") { $fail++; Write-Host "  FAIL  $s" -ForegroundColor Red }
    else {
      Write-Host "  ok    $s" -ForegroundColor Green
      foreach ($line in ($o -split "`n")) {
        if ($line -match "^\s{2}\S" -and $line -notmatch "WARNING|ERROR|at:|\[") {
          Write-Host "        $($line.Trim())" -ForegroundColor DarkGray
        }
      }
    }
  }
}

Write-Host ""
if ($fail -eq 0) { Write-Host "TÜMÜ GEÇTİ" -ForegroundColor Green; exit 0 }
else { Write-Host "$fail BÖLÜM BAŞARISIZ" -ForegroundColor Red; exit 1 }
