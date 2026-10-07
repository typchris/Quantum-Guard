@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-QGuard-NetworkSafe.ps1"
if errorlevel 1 (
  echo.
  echo Quantum Guard network-safe startup failed.
  pause
)
