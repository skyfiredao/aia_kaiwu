$ErrorActionPreference = "Stop"
$SRC = $PSScriptRoot
$DST = [System.IO.Directory]::GetParent($SRC).FullName

Write-Host "git pull for latest version..."
try {
  & git -C $SRC pull
  if ($LASTEXITCODE -ne 0) { Write-Warning "git pull exit $LASTEXITCODE; using existing checkout" }
} catch {
  Write-Warning "git pull failed; using existing checkout"
}

Write-Host "replace AGENTS.md and CLAUDE.md..."
copy "$SRC\AGENTS.md" "$DST\AGENTS.md" -Force
copy "$SRC\AGENTS.md" "$DST\CLAUDE.md" -Force

foreach ($t in ".claude\agents", ".cursor\agents", ".opencode\skills") {
  Write-Host "copy skills to $t..."
  robocopy "$SRC\skills" "$DST\$t" /MIR /NFL /NDL /NJH /NJS | Out-Null
}

Write-Host "aia_kaiwu setup complete: $DST" -ForegroundColor Green
