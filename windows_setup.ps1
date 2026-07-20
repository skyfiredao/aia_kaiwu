$ErrorActionPreference = "Stop"
$SRC = $PSScriptRoot
$DST = [System.IO.Directory]::GetParent($SRC).FullName

try {
  & git -C $SRC pull
  if ($LASTEXITCODE -ne 0) { Write-Warning "git pull exit $LASTEXITCODE; using existing checkout" }
} catch {
  Write-Warning "git pull failed; using existing checkout"
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
