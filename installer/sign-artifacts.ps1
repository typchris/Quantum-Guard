[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string[]]$Path,
  [string]$Thumbprint,
  [string]$PfxPath,
  [string]$PfxPassword,
  [string]$TimestampUrl = 'http://timestamp.digicert.com',
  [switch]$AllowTestCertificate
)
$ErrorActionPreference = 'Stop'
$signtool = (Get-Command signtool.exe -ErrorAction Stop).Source
if ([string]::IsNullOrWhiteSpace($Thumbprint) -and [string]::IsNullOrWhiteSpace($PfxPath)) {
  throw 'Provide -Thumbprint (preferred) or -PfxPath.'
}
foreach ($item in $Path) {
  if (-not (Test-Path $item)) { throw "Signing target not found: $item" }
  $args = @('sign','/fd','SHA256','/tr',$TimestampUrl,'/td','SHA256')
  if ($Thumbprint) { $args += @('/sha1',$Thumbprint) }
  else {
    $args += @('/f',$PfxPath)
    if ($PfxPassword) { $args += @('/p',$PfxPassword) }
  }
  $args += $item
  & $signtool @args
  if ($LASTEXITCODE -ne 0) { throw "SignTool failed for $item" }
  & $signtool verify /pa /all /v $item
  if ($LASTEXITCODE -ne 0 -and -not $AllowTestCertificate) { throw "Authenticode verification failed for $item" }
}
