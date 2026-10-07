# Quantum Guard 1.12.3 temporary network guardian
# QA mitigation until the equivalent logic is built directly into QuantumGuard.Engine.exe.

[CmdletBinding()]
param(
    [int]$GraceSeconds = 10
)

$ErrorActionPreference = 'SilentlyContinue'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Recovery = Join-Path $Here 'QGuard-Network-Recovery.ps1'
$LogDir = Join-Path $env:APPDATA 'QuantumAppGuard\network-recovery'
$LogFile = Join-Path $LogDir 'network-guardian.log'

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Log([string]$Message) {
    Add-Content -LiteralPath $LogFile -Value "[$(Get-Date -Format o)] $Message"
}

$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\QuantumGuard_NetworkGuardian_1124', [ref]$createdNew)
if (-not $createdNew) {
    exit 0
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
        return $null
    } catch {
        # Conservative fallback: if process inspection is unavailable, treat
        # any engine process as active so this helper never tears down a live proxy.
        return Get-Process -Name 'QuantumGuard.Engine' -ErrorAction SilentlyContinue | Select-Object -First 1
    }
}

function Test-QGuardPort {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect('127.0.0.1', 53679, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne(500, $false)) {
            return $false
        }
        $client.EndConnect($iar)
        return $client.Connected
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

try {
    Log 'Network guardian started.'
    $sawMainEngine = $false

    while ($true) {
        $engine = Get-MainEngine
        if ($engine) {
            $sawMainEngine = $true
            Start-Sleep -Seconds 2
            continue
        }

        if (-not $sawMainEngine) {
            Start-Sleep -Seconds 1
            continue
        }

        Log "Main engine disappeared. Allowing built-in watchdog $GraceSeconds seconds to recover it."
        Start-Sleep -Seconds $GraceSeconds

        if (Get-MainEngine) {
            Log 'Main engine returned during grace period. No proxy repair needed.'
            Start-Sleep -Seconds 2
            continue
        }

        if (Test-QGuardPort) {
            Log 'No main engine was detected but the local proxy port is still accepting connections. Waiting before repair.'
            Start-Sleep -Seconds 4
            if (Get-MainEngine) {
                Log 'Main engine returned after proxy-port grace period.'
                continue
            }
        }

        if (Test-Path -LiteralPath $Recovery) {
            Log 'No main engine recovered. Running stale proxy repair.'
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Recovery | Out-Null
            Log 'Stale proxy repair completed.'
        } else {
            Log "Recovery helper missing: $Recovery"
        }
        break
    }
} finally {
    Log 'Network guardian stopped.'
    if ($mutex) {
        $mutex.ReleaseMutex() | Out-Null
        $mutex.Dispose()
    }
}
