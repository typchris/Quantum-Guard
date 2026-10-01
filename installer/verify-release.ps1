[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$InstallerPath,
  [string]$ExpectedSubject,
  [string]$ExpectedThumbprint,
  [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$signtool = (Get-Command signtool.exe -ErrorAction Stop).Source
$resolved = (Resolve-Path $InstallerPath -ErrorAction Stop).Path

if (-not (Test-Path $resolved -PathType Leaf)) {
  throw "Release installer not found: $InstallerPath"
}

& $signtool verify /pa /all /v $resolved
if ($LASTEXITCODE -ne 0) {
  throw 'SignTool verification failed for the release installer.'
}

$signature = Get-AuthenticodeSignature -FilePath $resolved
if ($signature.Status -ne 'Valid') {
  throw "Authenticode status is $($signature.Status), expected Valid."
}
if (-not $signature.SignerCertificate) {
  throw 'Release installer has no signer certificate.'
}
if (-not $signature.TimeStamperCertificate) {
  throw 'Release installer has no trusted timestamp certificate.'
}

$actualThumbprint = $signature.SignerCertificate.Thumbprint.Replace(' ','').ToUpperInvariant()

if ($ExpectedThumbprint) {
  $expected = $ExpectedThumbprint.Replace(' ','').ToUpperInvariant()
  if ($expected -notmatch '^[0-9A-F]{40,64}$') {
    throw 'ExpectedThumbprint must be a hexadecimal certificate thumbprint.'
  }
  if ($actualThumbprint -ne $expected) {
    throw "Unexpected release signer thumbprint: $actualThumbprint"
  }
}

if ($ExpectedSubject -and $signature.SignerCertificate.Subject -notlike "*$ExpectedSubject*") {
  throw "Unexpected release signer subject: $($signature.SignerCertificate.Subject)"
}

$item = Get-Item $resolved
$sha256 = (Get-FileHash -Algorithm SHA256 $resolved).Hash.ToLowerInvariant()

$descriptor = [ordered]@{
  schema = 1
  file = $item.Name
  size = $item.Length
  sha256 = $sha256
  signer_subject = $signature.SignerCertificate.Subject
  signer_thumbprint = $actualThumbprint
  signer_not_before = $signature.SignerCertificate.NotBefore.ToUniversalTime().ToString('o')
  signer_not_after = $signature.SignerCertificate.NotAfter.ToUniversalTime().ToString('o')
  timestamp_subject = $signature.TimeStamperCertificate.Subject
  verified_at_utc = [DateTime]::UtcNow.ToString('o')
}

$json = $descriptor | ConvertTo-Json -Depth 4
if ($OutputPath) {
  $parent = Split-Path -Parent $OutputPath
  if ($parent) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  $json | Set-Content -Encoding UTF8 $OutputPath
}

Write-Host $json
