param(
  [string]$SourceDir = "anarlog",
  [string]$OutputDir = "dist\AnarlogPortable"
)

$ErrorActionPreference = "Stop"

Write-Host "Searching for .exe files in $SourceDir recursively..."

# Collect all .exe files, excluding setup/installer/bundle paths
$allCandidates = Get-ChildItem -Path $SourceDir -Recurse -Filter "*.exe" | Where-Object {
  $path = $_.FullName
  $excludePatterns = @(
    "bundle\msi",
    "bundle\nsis",
    "node_modules",
    "setup",
    "installer"
  )
  $keep = $true
  foreach ($pattern in $excludePatterns) {
    if ($path -like "*$pattern*") {
      $keep = $false
      break
    }
  }
  $keep
}

if (-not $allCandidates) {
  Write-Host "::error::No .exe files found after build."
  exit 1
}

Write-Host "`nAll candidates ($($allCandidates.Count) found):"
$allCandidates | ForEach-Object { Write-Host "  $($_.FullName)" }

# Prefer candidates under target\release (Rust release builds)
$releaseCandidates = $allCandidates | Where-Object {
  $_.FullName -like "*target\release*"
}

if ($releaseCandidates) {
  Write-Host "`nFound $($releaseCandidates.Count) release-candidate(s) in target\release."
  # Pick the largest .exe — that's almost certainly the main app binary
  $best = $releaseCandidates | Sort-Object Length -Descending | Select-Object -First 1
} else {
  Write-Host "`n::warning::No binary found under target\release. Falling back to the largest .exe anywhere."
  $best = $allCandidates | Sort-Object Length -Descending | Select-Object -First 1
}

Write-Host "`nSelected: $($best.FullName) ($([math]::Round($best.Length / 1MB, 2)) MB)"

# Ensure output directory exists
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# Copy with rename
Copy-Item -Path $best.FullName -Destination "$OutputDir\Anarlog.exe" -Force

Write-Host "Copied to $OutputDir\Anarlog.exe"
