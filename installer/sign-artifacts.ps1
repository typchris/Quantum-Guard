[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string[]]$Path,
  [string]$Thumbprint,
  [string]$PfxPath,
  [string]$PfxPassword,
  [string]$ExpectedSubject,
  [string]$TimestampUrl = 'https://timestamp.digicert.com',
  [switch]$AllowTestCertificate
)

$ErrorActionPreference = 'Stop'
$signtool = (Get-Command signtool.exe -ErrorAction Stop).Source

if ([string]::IsNullOrWhiteSpace($Thumbprint) -and [string]::IsNullOrWhiteSpace($PfxPath)) {
  throw 'Provide -Thumbprint (preferred) or -PfxPath.'
}

foreach ($item in $Path) {
  if (-not (Test-Path $item)) {
    throw "Signing target not found: $item"
  }

  $args = @(
    'sign',
    '/fd','SHA256',
    '/tr',$TimestampUrl,
    '/td','SHA256',
    '/d','Quantum Guard'
  )

  if ($Thumbprint) {
    $args += @('/sha1',$Thumbprint)
  } else {
    $args += @('/f',$PfxPath)
    if ($PfxPassword) {
      $args += @('/p',$PfxPassword)
    }
  }

  $args += $item

  & $signtool @args
  if ($LASTEXITCODE -ne 0) {
    throw "SignTool failed for $item"
  }

  & $signtool verify /pa /all /v $item
  if ($LASTEXITCODE -ne 0 -and -not $AllowTestCertificate) {
    throw "Authenticode verification failed for $item"
  }

  $signature = Get-AuthenticodeSignature -FilePath $item
  if (-not $AllowTestCertificate -and $signature.Status -ne 'Valid') {
    throw "Authenticode status for $item is $($signature.Status), expected Valid."
  }

  if ($ExpectedSubject) {
    $subject = $signature.SignerCertificate.Subject
    if ([string]::IsNullOrWhiteSpace($subject) -or $subject -notlike "*$ExpectedSubject*") {
      throw "Unexpected signer for $item. Expected subject containing '$ExpectedSubject', got '$subject'."
    }
  }

  if ($Thumbprint) {
    $actual = $signature.SignerCertificate.Thumbprint
    if ([string]::IsNullOrWhiteSpace($actual) -or $actual -ne $Thumbprint.Replace(' ','').ToUpperInvariant()) {
      throw "Unexpected certificate thumbprint for $item."
    }
  }
}
