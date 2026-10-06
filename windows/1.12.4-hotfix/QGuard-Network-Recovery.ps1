# Quantum Guard 1.12.4 emergency stale-proxy recovery
# Safe to run only while QuantumGuard.Engine is fully stopped.
# This script changes only proxy values that still point to Quantum Guard's
# known local proxy endpoint. It backs up touched values before changing them.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$QGuardProxyHost = '127.0.0.1'
$QGuardProxyPort = 53679
$QGuardProxy = $QGuardProxyHost + ':' + $QGuardProxyPort
$AppDir = Join-Path $env:APPDATA 'QuantumAppGuard'
$BackupDir = Join-Path $AppDir 'network-recovery'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupFile = Join-Path $BackupDir ("proxy-recovery-" + $Stamp + ".json")
$LogFile = Join-Path $BackupDir 'proxy-recovery.log'

function Write-RepairLog([string]$Message) {
    New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
    Add-Content -LiteralPath $LogFile -Value "[$(Get-Date -Format o)] $Message"
}

function Is-QGuardProxy([object]$Value) {
    if ($null -eq $Value) { return $false }
    $s = [string]$Value
    return (
        $s -match '(?i)(^|[=;])\s*(?:http://)?127\.0\.0\.1:53679(?:$|;)' -or
        $s -match '(?i)^\s*(?:http://)?127\.0\.0\.1:53679\s*$'
    )
}

$running = Get-Process -Name 'QuantumGuard.Engine' -ErrorAction SilentlyContinue
if ($running) {
    throw 'QuantumGuard.Engine is still running. Exit Quantum Guard completely before using network recovery.'
}

New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

$internetSettings = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$browserKeys = @(
    'HKCU:\Software\Policies\Microsoft\Edge',
    'HKCU:\Software\Policies\Google\Chrome'
)

$backup = [ordered]@{
    timestamp = (Get-Date).ToString('o')
    qguard_proxy = $QGuardProxy
    internet_settings = $null
    browser_policies = @()
}

if (Test-Path $internetSettings) {
    $p = Get-ItemProperty -Path $internetSettings
    $backup.internet_settings = [ordered]@{
        ProxyEnable = $p.ProxyEnable
        ProxyServer = $p.ProxyServer
        AutoConfigURL = $p.AutoConfigURL
    }
}

foreach ($key in $browserKeys) {
    if (Test-Path $key) {
        $p = Get-ItemProperty -Path $key
        $backup.browser_policies += [ordered]@{
            path = $key
            ProxyMode = $p.ProxyMode
            ProxyServer = $p.ProxyServer
            ProxyPacUrl = $p.ProxyPacUrl
        }
    }
}

$backup | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $BackupFile -Encoding UTF8
Write-RepairLog "Backed up current proxy state to $BackupFile"

$changed = $false

if (Test-Path $internetSettings) {
    $p = Get-ItemProperty -Path $internetSettings
    if (Is-QGuardProxy $p.ProxyServer) {
        Set-ItemProperty -Path $internetSettings -Name ProxyEnable -Type DWord -Value 0
        Remove-ItemProperty -Path $internetSettings -Name ProxyServer -ErrorAction SilentlyContinue
        Write-RepairLog 'Removed stale Quantum Guard WinINet proxy.'
        $changed = $true
    }
}

foreach ($key in $browserKeys) {
    if (-not (Test-Path $key)) { continue }
    $p = Get-ItemProperty -Path $key
    $modeOwned = ([string]$p.ProxyMode -eq 'fixed_servers')
    $serverOwned = Is-QGuardProxy $p.ProxyServer

    if ($modeOwned -and $serverOwned) {
        Remove-ItemProperty -Path $key -Name ProxyMode -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $key -Name ProxyServer -ErrorAction SilentlyContinue
        Write-RepairLog "Removed stale Quantum Guard browser proxy policy from $key."
        $changed = $true
    }
}

if ($changed) {
    try {
        Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class QGuardInternetOptions {
    [DllImport("wininet.dll", SetLastError=true)]
    public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
}
'@
        [QGuardInternetOptions]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null
        [QGuardInternetOptions]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null
    } catch {
        Write-RepairLog "WinINet notification warning: $($_.Exception.Message)"
    }

    try {
        & ipconfig.exe /flushdns | Out-Null
        Write-RepairLog 'Flushed Windows DNS cache.'
    } catch {
        Write-RepairLog "DNS flush warning: $($_.Exception.Message)"
    }

    Write-Host 'Quantum Guard stale proxy settings were repaired.' -ForegroundColor Green
    Write-Host "Backup: $BackupFile"
    Write-Host 'Restart the browser before retesting affected websites.'
} else {
    Write-RepairLog 'No stale Quantum Guard-owned proxy settings were found.'
    Write-Host 'No stale Quantum Guard proxy settings were found.' -ForegroundColor Yellow
}
