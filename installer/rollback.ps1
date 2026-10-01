#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$reg = 'HKLM:\Software\QuantumGuard'
$root = (Get-ItemProperty -Path $reg -Name InstallRoot).InstallRoot
$current = (Get-ItemProperty -Path $reg -Name CurrentVersion).CurrentVersion
$previous = (Get-ItemProperty -Path $reg -Name PreviousVersion -ErrorAction SilentlyContinue).PreviousVersion

$expectedRoot = [IO.Path]::GetFullPath((Join-Path $env:ProgramFiles 'Quantum Guard')).TrimEnd('\')
$actualRoot = [IO.Path]::GetFullPath($root).TrimEnd('\')
if (-not $actualRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
  throw "Unexpected Quantum Guard install root: $actualRoot"
}

$versionPattern = '^\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?
if (-not (Test-Path $previousUi)) { throw "Previous version payload is missing: $previousUi" }
Get-Process 'QuantumGuard.UI','QuantumGuard.Engine' -ErrorAction SilentlyContinue | Stop-Process -Force
Set-ItemProperty -Path $reg -Name CurrentVersion -Value $previous
Set-ItemProperty -Path $reg -Name PreviousVersion -Value $current
$programs = [Environment]::GetFolderPath('CommonPrograms')
$desktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
$ws = New-Object -ComObject WScript.Shell
$shortcut = $ws.CreateShortcut((Join-Path $programs 'Quantum Guard\Quantum Guard.lnk'))
$shortcut.TargetPath = $previousUi
$shortcut.WorkingDirectory = Split-Path $previousUi
$shortcut.Save()
$desktopShortcut = $ws.CreateShortcut((Join-Path $desktop 'Quantum Guard.lnk'))
$desktopShortcut.TargetPath = $previousUi
$desktopShortcut.WorkingDirectory = Split-Path $previousUi
$desktopShortcut.Save()
Start-Process -FilePath $previousUi
Write-Host "Rolled Quantum Guard back from $current to $previous."

if ($current -notmatch $versionPattern) { throw 'CurrentVersion contains an invalid version value.' }
if ([string]::IsNullOrWhiteSpace($previous)) { throw 'No previous Quantum Guard version is recorded.' }
if ($previous -notmatch $versionPattern) { throw 'PreviousVersion contains an invalid version value.' }

$previousUi = Join-Path $actualRoot "versions\$previous\QuantumGuard.UI.exe"
$resolvedPreviousUi = [IO.Path]::GetFullPath($previousUi)
$versionsRoot = [IO.Path]::GetFullPath((Join-Path $actualRoot 'versions')).TrimEnd('\') + '\'
if (-not $resolvedPreviousUi.StartsWith($versionsRoot, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Previous version path escaped the versioned install directory.'
}
$previousUi = $resolvedPreviousUi
if (-not (Test-Path $previousUi)) { throw "Previous version payload is missing: $previousUi" }
Get-Process 'QuantumGuard.UI','QuantumGuard.Engine' -ErrorAction SilentlyContinue | Stop-Process -Force
Set-ItemProperty -Path $reg -Name CurrentVersion -Value $previous
Set-ItemProperty -Path $reg -Name PreviousVersion -Value $current
$programs = [Environment]::GetFolderPath('CommonPrograms')
$desktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
$ws = New-Object -ComObject WScript.Shell
$shortcut = $ws.CreateShortcut((Join-Path $programs 'Quantum Guard\Quantum Guard.lnk'))
$shortcut.TargetPath = $previousUi
$shortcut.WorkingDirectory = Split-Path $previousUi
$shortcut.Save()
$desktopShortcut = $ws.CreateShortcut((Join-Path $desktop 'Quantum Guard.lnk'))
$desktopShortcut.TargetPath = $previousUi
$desktopShortcut.WorkingDirectory = Split-Path $previousUi
$desktopShortcut.Save()
Start-Process -FilePath $previousUi
Write-Host "Rolled Quantum Guard back from $current to $previous."
