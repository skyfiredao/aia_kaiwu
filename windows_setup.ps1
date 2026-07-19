[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = "Stop"
$SRC = $PSScriptRoot
$DST = Split-Path -LiteralPath $SRC -Parent

try {
  if (& git -C $SRC status --porcelain) { Write-Warning "aia_kaiwu checkout has local changes; generated config will include them" }
  Write-Host "git pull: $SRC"
  & git -C $SRC pull
  if ($LASTEXITCODE -ne 0) { Write-Warning "git pull exit $LASTEXITCODE; using existing checkout" }
} catch {
  Write-Warning "git pull failed; using existing checkout"
}
$revision = & git -C $SRC rev-parse --short HEAD 2>$null
if ($LASTEXITCODE -eq 0) { Write-Host "Source revision: $revision" }

if (-not (Test-Path -LiteralPath (Join-Path $SRC "AGENTS.md"))) { throw "Source missing AGENTS.md: $SRC" }
if (-not (Test-Path -LiteralPath (Join-Path $SRC "skills"))) { throw "Source missing skills: $SRC" }
if ($SRC -eq $DST) { throw "Source equals destination: $DST" }
if ([System.IO.Path]::GetPathRoot($DST).TrimEnd('\') -eq $DST.TrimEnd('\')) { throw "Destination cannot be a drive root: $DST" }
if (Test-Path -LiteralPath (Join-Path $DST ".git")) { throw "Destination is a git repo: $DST" }

$generated = @(
  (Join-Path $DST "AGENTS.md"), (Join-Path $DST "CLAUDE.md"),
  (Join-Path $DST "skills"), (Join-Path $DST ".claude\agents"),
  (Join-Path $DST ".cursor\agents"), (Join-Path $DST ".opencode\skills"),
  (Join-Path $DST ".cursor\rules\agents.mdc")
)
$existing = $generated | Where-Object { Test-Path -LiteralPath $_ }
Write-Host "Destination: $DST"
if ($existing.Count -gt 0 -and -not $Force) {
  Write-Warning "Generated workspace config will be replaced."
  $existing | ForEach-Object { Write-Warning $_ }
  if ((Read-Host "Continue? [y/N]") -notmatch '^[Yy]') { throw "Aborted by user" }
}

@("skills", ".claude\agents", ".cursor\agents", ".opencode\skills") | ForEach-Object {
  $path = Join-Path $DST $_
  if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
}
$bridge = Join-Path $DST ".cursor\rules\agents.mdc"
if (Test-Path -LiteralPath $bridge) { Remove-Item -LiteralPath $bridge -Force }

Copy-Item -LiteralPath (Join-Path $SRC "AGENTS.md") -Destination (Join-Path $DST "AGENTS.md") -Force
Copy-Item -LiteralPath (Join-Path $SRC "AGENTS.md") -Destination (Join-Path $DST "CLAUDE.md") -Force
Copy-Item -LiteralPath (Join-Path $SRC "skills") -Destination $DST -Recurse -Force
New-Item -ItemType Directory -Force -Path (Join-Path $DST ".cursor\rules") | Out-Null
if (Test-Path -LiteralPath (Join-Path $SRC ".cursor\rules")) {
  Copy-Item -Path (Join-Path $SRC ".cursor\rules\*") -Destination (Join-Path $DST ".cursor\rules\") -Force
}

New-Item -ItemType Directory -Force -Path `
  (Join-Path $DST ".claude\agents"), `
  (Join-Path $DST ".cursor\agents"), `
  (Join-Path $DST ".opencode\skills") | Out-Null
Get-ChildItem -LiteralPath (Join-Path $DST "skills") -Filter *.md | ForEach-Object {
  Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $DST ".claude\agents\$($_.Name)") -Force
  Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $DST ".cursor\agents\$($_.Name)") -Force
  $slugDir = Join-Path $DST ".opencode\skills\$($_.BaseName)"
  New-Item -ItemType Directory -Force -Path $slugDir | Out-Null
  Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $slugDir "SKILL.md") -Force
}

Write-Host "Configured: $DST"
