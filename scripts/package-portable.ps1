param(
  [string]$SourceDir = "dist\AnarlogPortable",
  [string]$OutputDir = "dist",
  [string]$ZipName = "anarlog-windows-portable-x64.zip"
)

$ErrorActionPreference = "Stop"

# Verify the portable directory exists and has content
if (-not (Test-Path $SourceDir)) {
  Write-Host "::error::Portable directory not found: $SourceDir"
  Write-Host "::error::Run scripts/find-anarlog-exe.ps1 first."
  exit 1
}

$exePath = "$SourceDir\Anarlog.exe"
if (-not (Test-Path $exePath)) {
  Write-Host "::error::$exePath not found. Run scripts/find-anarlog-exe.ps1 first."
  exit 1
}

# Add a README.txt inside the portable folder
$readmeContent = @"
Anarlog Portable Build
======================
This is an unofficial portable build of Anarlog, built directly from the upstream source code.

To use:
1. Double-click Anarlog.exe to launch the application.
2. If the application fails to open, install Microsoft Edge WebView2 Runtime from:
   https://developer.microsoft.com/en-us/microsoft-edge/webview2/
3. After installing WebView2, run Anarlog.exe again.

Note: This build is provided as-is. It is not an official release and may not include
all features or stability of the official packaged version.

Source: https://github.com/fastrepl/anarlog
"@

$readmePath = "$SourceDir\README.txt"
Set-Content -Path $readmePath -Value $readmeContent -Encoding ASCII

Write-Host "Added $readmePath"

# Create the output directory if needed
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# Create the ZIP (use full path to avoid .NET working-directory issues)
Compress-Archive -Path "$SourceDir\*" -DestinationPath "$OutputDir\$ZipName" -Force

$zipFile = Get-Item "$OutputDir\$ZipName"
Write-Host "ZIP created: $($zipFile.FullName)"
Write-Host "Size: $([math]::Round($zipFile.Length / 1MB, 2)) MB"
