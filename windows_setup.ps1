# aia_kaiwu Windows setup: mirror aia_kaiwu config to the workspace root and
# generate per-tool skill dirs from skills/ (Windows can't follow the Unix
# symlinks aia_kaiwu ships in .claude/, .cursor/, .opencode/).
#
# Usage (first-time AND update):
#   cd C:\workspace
#   .\aia_kaiwu\windows_setup.ps1
#
# If execution policy blocks it:
#   powershell -ExecutionPolicy Bypass -File .\aia_kaiwu\windows_setup.ps1

$ErrorActionPreference = "Stop"

$SRC = $PSScriptRoot
$DST = Split-Path $SRC -Parent

try {
  git -C $SRC pull
  if ($LASTEXITCODE -ne 0) { Write-Warning "git pull exit $LASTEXITCODE; using existing checkout" }
} catch {
  Write-Warning "git pull failed; using existing checkout"
}

Copy-Item "$SRC\AGENTS.md" "$DST\" -Force
Copy-Item "$SRC\AGENTS.md" "$DST\CLAUDE.md" -Force
Copy-Item "$SRC\skills" "$DST\" -Recurse -Force
New-Item "$DST\.cursor\rules" -ItemType Directory -Force | Out-Null
Copy-Item "$SRC\.cursor\rules\*" "$DST\.cursor\rules\" -Force

New-Item "$DST\.claude\agents", "$DST\.cursor\agents", "$DST\.opencode\skills" -ItemType Directory -Force | Out-Null
Get-ChildItem "$DST\skills\*.md" | ForEach-Object {
  Copy-Item $_.FullName "$DST\.claude\agents\$($_.Name)" -Force
  Copy-Item $_.FullName "$DST\.cursor\agents\$($_.Name)" -Force
  $slug = $_.BaseName
  New-Item "$DST\.opencode\skills\$slug" -ItemType Directory -Force | Out-Null
  Copy-Item $_.FullName "$DST\.opencode\skills\$slug\SKILL.md" -Force
}
