# RemoteStartup source handoff

The compiled Windows QA package adds a small startup/cloud recovery helper named QuantumGuard.RemoteStartup.exe. It is not a second enforcement engine.

The complete helper source handoff is stored with the project artifact as QuantumGuard-Windows-Preview4-RemoteControl-Repair-source.zip.

Source ZIP SHA256:
8781e5e09a914d0a7ff00970f4ad1a46771beb50fac19c533da128429b858cb9

Compiled helper SHA256:
d4e1907a0e23d0ccd3dca1d56286cd5ed77c831fccc1ce687d88755a638e36f1

The helper:
* migrates only missing per-user cloud session/device state into the correct QuantumAppGuard AppData folder
* restores/refreshes the current-user DPAPI session
* prefetches and merges the target Windows policy before original engine startup
* publishes one bounded Windows executable inventory snapshot
* starts the original WinUI application
* never replaces the original QuantumGuard.Engine.exe enforcement process
