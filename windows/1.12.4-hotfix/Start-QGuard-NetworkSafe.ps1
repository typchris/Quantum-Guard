# Quantum Guard 1.12.3 network-safe QA launcher
# Performs a conservative stale-proxy preflight and starts a temporary guardian.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Engine = Join-Path $Here 'QuantumGuard.Engine.exe'
$UI = Join-Path $Here 'QuantumGuard.exe'
$Recovery = Join-Path $Here 'QGuard-Network-Recovery.ps1'
$Guardian = Join-Path $Here 'QGuard-Network-Guardian.ps1'

foreach ($required in @($Engine, $UI, $Recovery, $Guardian)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Required Quantum Guard file is missing: $required"
    }
}

function Get-MainEngine {
    try {
        $items = Get-CimInstance Win32_Process -Filter "Name='QuantumGuard.Engine.exe'"
        foreach ($item in $items) {
            $cmd = [string]$item.CommandLine
            if ($cmd -notmatch '(?i)(?:^|\s)--watchdog(?:\s|$)') {
                return $item
            }
        }
    } catch {
        return Get-Process -Name 'QuantumGuard.Engine' -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    return $null
}

$engine = Get-MainEngine
if (-not $engine) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Recovery
    if ($LASTEXITCODE -ne 0) {
        throw "Quantum Guard network preflight failed with exit code $LASTEXITCODE"
    }

    Start-Process -FilePath $Engine -ArgumentList '--startup' -WorkingDirectory $Here
    Start-Sleep -Milliseconds 800
}

$uiRunning = Get-Process -Name 'QuantumGuard' -ErrorAction SilentlyContinue
if (-not $uiRunning) {
    Start-Process -FilePath $UI -WorkingDirectory $Here
}

Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', ('"' + $Guardian + '"')
)

Write-Host 'Quantum Guard started with temporary network crash recovery enabled.' -ForegroundColor Green
