#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$reg = 'HKLM:\Software\QuantumGuard'
$root = (Get-ItemProperty -Path $reg -Name InstallRoot -ErrorAction Stop).InstallRoot
$current = (Get-ItemProperty -Path $reg -Name CurrentVersion -ErrorAction Stop).CurrentVersion
$previous = (Get-ItemProperty -Path $reg -Name PreviousVersion -ErrorAction SilentlyContinue).PreviousVersion

$expectedRoot = [IO.Path]::GetFullPath((Join-Path $env:ProgramFiles 'Quantum Guard')).TrimEnd('\')
$actualRoot = [IO.Path]::GetFullPath($root).TrimEnd('\')

if (-not $actualRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
  throw "Unexpected Quantum Guard install root: $actualRoot"
}

$versionPattern = '^\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?$'
if ($current -notmatch $versionPattern) {
  throw 'CurrentVersion contains an invalid version value.'
}
if ([string]::IsNullOrWhiteSpace($previous)) {
  throw 'No previous Quantum Guard version is recorded.'
}
if ($previous -notmatch $versionPattern) {
  throw 'PreviousVersion contains an invalid version value.'
}

$versionsRoot = [IO.Path]::GetFullPath((Join-Path $actualRoot 'versions')).TrimEnd('\') + '\'
$previousUi = [IO.Path]::GetFullPath(
  (Join-Path $actualRoot "versions\$previous\QuantumGuard.UI.exe")
)

if (-not $previousUi.StartsWith($versionsRoot, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Previous version path escaped the versioned install directory.'
}
if (-not (Test-Path $previousUi -PathType Leaf)) {
  throw "Previous version payload is missing: $previousUi"
}

# Preview-only fallback. Production synchronization must replace process-name
# termination with the authenticated application/engine handoff.
Get-Process 'QuantumGuard.UI','QuantumGuard.Engine' -ErrorAction SilentlyContinue |
  Stop-Process -Force

Set-ItemProperty -Path $reg -Name CurrentVersion -Value $previous
Set-ItemProperty -Path $reg -Name PreviousVersion -Value $current

$programs = [Environment]::GetFolderPath('CommonPrograms')
$desktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
$ws = New-Object -ComObject WScript.Shell

$programShortcutPath = Join-Path $programs 'Quantum Guard\Quantum Guard.lnk'
$programShortcut = $ws.CreateShortcut($programShortcutPath)
$programShortcut.TargetPath = $previousUi
$programShortcut.WorkingDirectory = Split-Path $previousUi
$programShortcut.Save()

$desktopShortcutPath = Join-Path $desktop 'Quantum Guard.lnk'
$desktopShortcut = $ws.CreateShortcut($desktopShortcutPath)
$desktopShortcut.TargetPath = $previousUi
$desktopShortcut.WorkingDirectory = Split-Path $previousUi
$desktopShortcut.Save()

Start-Process -FilePath $previousUi
Write-Host "Rolled Quantum Guard back from $current to $previous."
