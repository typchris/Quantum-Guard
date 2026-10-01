[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$PayloadDir,
  [Parameter(Mandatory=$true)][string]$Version,
  [string]$Makensis = 'makensis.exe',
  [string]$OutputDir = (Join-Path $PSScriptRoot 'out'),
  [switch]$AllowUnsignedPreview
)

$ErrorActionPreference = 'Stop'

$syncSentinel = Join-Path $PSScriptRoot 'SOURCE_SYNC_REQUIRED.md'
if (Test-Path $syncSentinel) {
  throw 'Installer source is not synchronized with the tested preview.4 handoff. Replace the stale installer/application integration and remove SOURCE_SYNC_REQUIRED.md in the same reviewed commit before building.'
}

if ($Version -notmatch '^\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?$') {
  throw 'Invalid semantic version.'
}

$payload = (Resolve-Path $PayloadDir).Path
$required = @(
  'QuantumGuard.UI.exe',
  'QuantumGuard.UI.dll',
  'QuantumGuard.Engine.exe'
)

foreach ($file in $required) {
  $path = Join-Path $payload $file
  if (-not (Test-Path $path)) {
    throw "Payload is missing $file"
  }

  $signature = Get-AuthenticodeSignature -FilePath $path
  if ($signature.Status -ne 'Valid') {
    if (-not $AllowUnsignedPreview) {
      throw "$file is not validly Authenticode-signed. Use -AllowUnsignedPreview only for non-production QA."
    }
    Write-Warning "$file is unsigned or untrusted ($($signature.Status)). Preview QA only."
  }
}

$nsis = (Get-Command $Makensis -ErrorAction Stop).Source
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

Push-Location $PSScriptRoot
try {
  & $nsis "/DAPP_VERSION=$Version" "/DSOURCE_DIR=$payload" 'QuantumGuard.nsi'
  if ($LASTEXITCODE -ne 0) {
    throw 'NSIS build failed.'
  }

  $built = Join-Path $PSScriptRoot "QuantumGuard-$Version-x64-Setup.exe"
  if (-not (Test-Path $built)) {
    throw "NSIS reported success but installer was not found: $built"
  }

  $target = Join-Path $OutputDir (Split-Path $built -Leaf)
  Move-Item -Force $built $target

  $item = Get-Item $target
  $hash = (Get-FileHash -Algorithm SHA256 $target).Hash.ToLowerInvariant()

  "$hash  $(Split-Path $target -Leaf)" |
    Set-Content -NoNewline (Join-Path $OutputDir 'SHA256.txt')

  [ordered]@{
    version = $Version
    file = (Split-Path $target -Leaf)
    size = $item.Length
    sha256 = $hash
    unsigned_preview_allowed = [bool]$AllowUnsignedPreview
    generated_at_utc = [DateTime]::UtcNow.ToString('o')
  } |
    ConvertTo-Json |
    Set-Content -Encoding UTF8 (Join-Path $OutputDir 'BUILD_METADATA.json')

  Write-Host "Built: $target"
  Write-Host "Size: $($item.Length)"
  Write-Host "SHA-256: $hash"
} finally {
  Pop-Location
}
