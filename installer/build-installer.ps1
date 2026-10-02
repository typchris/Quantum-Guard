[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$PayloadDir,
  [Parameter(Mandatory=$true)][string]$Version,
  [string]$Makensis = 'makensis.exe',
  [string]$OutputDir = (Join-Path $PSScriptRoot 'out'),
  [string]$ExpectedPublisherThumbprint,
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

$payload = [IO.Path]::GetFullPath((Resolve-Path $PayloadDir -ErrorAction Stop).Path).TrimEnd('\')
$output = [IO.Path]::GetFullPath($OutputDir).TrimEnd('\')

if ($output.StartsWith($payload + '\', [StringComparison]::OrdinalIgnoreCase) -or
    $output.Equals($payload, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'OutputDir must not be inside the payload directory.'
}

$reparsePoints = Get-ChildItem -LiteralPath $payload -Force -Recurse -ErrorAction Stop |
  Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }

if ($reparsePoints) {
  $names = ($reparsePoints | Select-Object -ExpandProperty FullName) -join ', '
  throw "Payload contains reparse points/junctions and cannot be packaged safely: $names"
}

$required = @(
  'QuantumGuard.UI.exe',
  'QuantumGuard.UI.dll',
  'QuantumGuard.Engine.exe'
)

$expectedThumbprint = $null
if ($ExpectedPublisherThumbprint) {
  $expectedThumbprint = $ExpectedPublisherThumbprint.Replace(' ', '').ToUpperInvariant()
  if ($expectedThumbprint -notmatch '^[0-9A-F]{40}$') {
    throw 'ExpectedPublisherThumbprint must be a 40-character hexadecimal SHA-1 certificate thumbprint.'
  }
}

if (-not $AllowUnsignedPreview -and -not $expectedThumbprint) {
  throw 'Production installer builds require -ExpectedPublisherThumbprint.'
}

foreach ($file in $required) {
  $path = Join-Path $payload $file

  if (-not (Test-Path $path -PathType Leaf)) {
    throw "Payload is missing $file"
  }

  $signature = Get-AuthenticodeSignature -FilePath $path

  if ($signature.Status -ne 'Valid') {
    if (-not $AllowUnsignedPreview) {
      throw "$file is not validly Authenticode-signed. Use -AllowUnsignedPreview only for non-production QA."
    }

    Write-Warning "$file is unsigned or untrusted ($($signature.Status)). Preview QA only."
    continue
  }

  if (-not $signature.SignerCertificate) {
    throw "$file reports a valid signature but has no signer certificate."
  }

  if ($expectedThumbprint) {
    $actual = $signature.SignerCertificate.Thumbprint.Replace(' ', '').ToUpperInvariant()
    if ($actual -ne $expectedThumbprint) {
      throw "$file is signed by an unexpected publisher certificate."
    }
  }
}

$nsis = (Get-Command $Makensis -ErrorAction Stop).Source
New-Item -ItemType Directory -Force -Path $output | Out-Null

Push-Location $PSScriptRoot
try {
  & $nsis "/DAPP_VERSION=$Version" "/DSOURCE_DIR=$payload" 'QuantumGuard.nsi'
  if ($LASTEXITCODE -ne 0) {
    throw 'NSIS build failed.'
  }

  $built = Join-Path $PSScriptRoot "QuantumGuard-$Version-x64-Setup.exe"
  if (-not (Test-Path $built -PathType Leaf)) {
    throw "NSIS reported success but installer was not found: $built"
  }

  $target = Join-Path $output (Split-Path $built -Leaf)
  Move-Item -Force $built $target

  $item = Get-Item $target
  $hash = (Get-FileHash -Algorithm SHA256 $target).Hash.ToLowerInvariant()

  "$hash  $(Split-Path $target -Leaf)" |
    Set-Content -NoNewline (Join-Path $output 'PRE_SIGN_SHA256.txt')

  [ordered]@{
    schema = 1
    version = $Version
    file = (Split-Path $target -Leaf)
    size = $item.Length
    pre_sign_sha256 = $hash
    final_release_hash = $false
    unsigned_preview_allowed = [bool]$AllowUnsignedPreview
    expected_publisher_thumbprint = $expectedThumbprint
    generated_at_utc = [DateTime]::UtcNow.ToString('o')
  } |
    ConvertTo-Json |
    Set-Content -Encoding UTF8 (Join-Path $output 'BUILD_METADATA.json')

  Write-Host "Built unsigned installer container: $target"
  Write-Host "Pre-sign size: $($item.Length)"
  Write-Host "Pre-sign SHA-256: $hash"
  Write-Host 'This hash is not release metadata. Sign the installer, then run verify-release.ps1.'
} finally {
  Pop-Location
}
