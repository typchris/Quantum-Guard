[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$PayloadDir,
  [Parameter(Mandatory=$true)][string]$Version,
  [string]$Makensis = 'makensis.exe',
  [string]$OutputDir = (Join-Path $PSScriptRoot 'out')
)
$ErrorActionPreference = 'Stop'
$required = @('QuantumGuard.UI.exe','QuantumGuard.UI.dll','QuantumGuard.Engine.exe')
foreach ($file in $required) {
  if (-not (Test-Path (Join-Path $PayloadDir $file))) { throw "Payload is missing $file" }
}
if ($Version -notmatch '^\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?$') { throw 'Invalid version.' }
$nsis = (Get-Command $Makensis -ErrorAction Stop).Source
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
Push-Location $PSScriptRoot
try {
  & $nsis "/DAPP_VERSION=$Version" "/DSOURCE_DIR=$((Resolve-Path $PayloadDir).Path)" 'QuantumGuard.nsi'
  if ($LASTEXITCODE -ne 0) { throw 'NSIS build failed.' }
  $built = Join-Path $PSScriptRoot "QuantumGuard-$Version-x64-Setup.exe"
  $target = Join-Path $OutputDir (Split-Path $built -Leaf)
  Move-Item -Force $built $target
  $hash = (Get-FileHash -Algorithm SHA256 $target).Hash.ToLowerInvariant()
  "$hash  $(Split-Path $target -Leaf)" | Set-Content -NoNewline (Join-Path $OutputDir 'SHA256.txt')
  Write-Host "Built: $target"
  Write-Host "SHA-256: $hash"
} finally { Pop-Location }
