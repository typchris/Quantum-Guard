[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string[]]$Path,
  [Parameter(Mandatory=$true)][string]$Thumbprint,
  [string]$ExpectedSubject,
  [string]$TimestampUrl = 'https://timestamp.digicert.com',
  [switch]$AllowTestCertificate
)

$ErrorActionPreference = 'Stop'
$signtool = (Get-Command signtool.exe -ErrorAction Stop).Source

$normalizedThumbprint = $Thumbprint.Replace(' ','').ToUpperInvariant()
if ($normalizedThumbprint -notmatch '^[0-9A-F]{40}) {
  throw 'Thumbprint must be a hexadecimal certificate thumbprint.'
}

$timestamp = [Uri]$TimestampUrl
if ($timestamp.Scheme -ne 'https') {
  throw 'RFC3161 timestamp URL must use HTTPS.'
}

$cert = @(
  Get-ChildItem Cert:\CurrentUser\My -ErrorAction SilentlyContinue
  Get-ChildItem Cert:\LocalMachine\My -ErrorAction SilentlyContinue
) | Where-Object {
  $_.Thumbprint -eq $normalizedThumbprint
} | Select-Object -First 1

if (-not $cert) {
  throw "Code-signing certificate $normalizedThumbprint was not found in CurrentUser\My or LocalMachine\My."
}

$now = Get-Date
if ($now -lt $cert.NotBefore -or $now -gt $cert.NotAfter) {
  throw "Code-signing certificate is outside its validity period: $($cert.NotBefore) - $($cert.NotAfter)."
}

$codeSigningEku = $cert.EnhancedKeyUsageList | Where-Object {
  $_.ObjectId.Value -eq '1.3.6.1.5.5.7.3.3'
}
if (-not $codeSigningEku) {
  throw 'Selected certificate does not contain the Code Signing enhanced key usage.'
}

if (-not $cert.HasPrivateKey) {
  throw 'Selected code-signing certificate does not expose a usable private key/signing provider.'
}

if ($ExpectedSubject) {
  if ($cert.Subject -notlike "*$ExpectedSubject*") {
    throw "Unexpected certificate subject. Expected '$ExpectedSubject', got '$($cert.Subject)'."
  }
}

$machineStore = $cert.PSParentPath -like '*LocalMachine*'

foreach ($item in $Path) {
  $resolved = (Resolve-Path $item -ErrorAction Stop).Path
  if (-not (Test-Path $resolved -PathType Leaf)) {
    throw "Signing target not found: $item"
  }

  $args = @(
    'sign',
    '/fd','SHA256',
    '/tr',$TimestampUrl,
    '/td','SHA256',
    '/d','Quantum Guard',
    '/s','My',
    '/sha1',$normalizedThumbprint
  )
  if ($machineStore) {
    $args += '/sm'
  }
  $args += $resolved

  & $signtool @args
  if ($LASTEXITCODE -ne 0) {
    throw "SignTool failed for $resolved"
  }

  & $signtool verify /pa /all /v $resolved
  if ($LASTEXITCODE -ne 0 -and -not $AllowTestCertificate) {
    throw "Authenticode verification failed for $resolved"
  }

  $signature = Get-AuthenticodeSignature -FilePath $resolved
  if (-not $signature.SignerCertificate) {
    throw "No Authenticode signer certificate found after signing $resolved"
  }

  $actualThumbprint = $signature.SignerCertificate.Thumbprint.Replace(' ','').ToUpperInvariant()
  if ($actualThumbprint -ne $normalizedThumbprint) {
    throw "Unexpected signer certificate for $resolved."
  }

  if ($ExpectedSubject -and $signature.SignerCertificate.Subject -notlike "*$ExpectedSubject*") {
    throw "Unexpected signer subject for $resolved: $($signature.SignerCertificate.Subject)"
  }

  if (-not $AllowTestCertificate -and $signature.Status -ne 'Valid') {
    throw "Authenticode status for $resolved is $($signature.Status), expected Valid."
  }

  Write-Host "Signed and verified: $resolved"
}
) {
  throw 'Thumbprint must be a hexadecimal certificate thumbprint.'
}

$timestamp = [Uri]$TimestampUrl
if ($timestamp.Scheme -ne 'https') {
  throw 'RFC3161 timestamp URL must use HTTPS.'
}

$cert = @(
  Get-ChildItem Cert:\CurrentUser\My -ErrorAction SilentlyContinue
  Get-ChildItem Cert:\LocalMachine\My -ErrorAction SilentlyContinue
) | Where-Object {
  $_.Thumbprint -eq $normalizedThumbprint
} | Select-Object -First 1

if (-not $cert) {
  throw "Code-signing certificate $normalizedThumbprint was not found in CurrentUser\My or LocalMachine\My."
}

$now = Get-Date
if ($now -lt $cert.NotBefore -or $now -gt $cert.NotAfter) {
  throw "Code-signing certificate is outside its validity period: $($cert.NotBefore) - $($cert.NotAfter)."
}

$codeSigningEku = $cert.EnhancedKeyUsageList | Where-Object {
  $_.ObjectId.Value -eq '1.3.6.1.5.5.7.3.3'
}
if (-not $codeSigningEku) {
  throw 'Selected certificate does not contain the Code Signing enhanced key usage.'
}

if (-not $cert.HasPrivateKey) {
  throw 'Selected code-signing certificate does not expose a usable private key/signing provider.'
}

if ($ExpectedSubject) {
  if ($cert.Subject -notlike "*$ExpectedSubject*") {
    throw "Unexpected certificate subject. Expected '$ExpectedSubject', got '$($cert.Subject)'."
  }
}

$machineStore = $cert.PSParentPath -like '*LocalMachine*'

foreach ($item in $Path) {
  $resolved = (Resolve-Path $item -ErrorAction Stop).Path
  if (-not (Test-Path $resolved -PathType Leaf)) {
    throw "Signing target not found: $item"
  }

  $args = @(
    'sign',
    '/fd','SHA256',
    '/tr',$TimestampUrl,
    '/td','SHA256',
    '/d','Quantum Guard',
    '/s','My',
    '/sha1',$normalizedThumbprint
  )
  if ($machineStore) {
    $args += '/sm'
  }
  $args += $resolved

  & $signtool @args
  if ($LASTEXITCODE -ne 0) {
    throw "SignTool failed for $resolved"
  }

  & $signtool verify /pa /all /v $resolved
  if ($LASTEXITCODE -ne 0 -and -not $AllowTestCertificate) {
    throw "Authenticode verification failed for $resolved"
  }

  $signature = Get-AuthenticodeSignature -FilePath $resolved
  if (-not $signature.SignerCertificate) {
    throw "No Authenticode signer certificate found after signing $resolved"
  }

  $actualThumbprint = $signature.SignerCertificate.Thumbprint.Replace(' ','').ToUpperInvariant()
  if ($actualThumbprint -ne $normalizedThumbprint) {
    throw "Unexpected signer certificate for $resolved."
  }

  if ($ExpectedSubject -and $signature.SignerCertificate.Subject -notlike "*$ExpectedSubject*") {
    throw "Unexpected signer subject for $resolved: $($signature.SignerCertificate.Subject)"
  }

  if (-not $AllowTestCertificate -and $signature.Status -ne 'Valid') {
    throw "Authenticode status for $resolved is $($signature.Status), expected Valid."
  }

  Write-Host "Signed and verified: $resolved"
}
