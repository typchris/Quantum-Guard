# Quantum Guard Windows Preview 4 Remote Control QA

This branch preserves the owner-supplied Windows WinUI `1.11.0-preview.4` frontend and its original `QuantumGuard.Engine.exe`.

## Goal

Allow Android Owner/Admin clients to control the Windows endpoint reliably without replacing the working WinUI application or creating a second protection engine.

## Root causes fixed

* Windows command names differed from Android admin command names.
* Stateful Focus/Web/Download commands could arrive as transient commands instead of persistent Windows policy.
* Stale Windows device rows could appear online long after the client stopped checking in.
* The correct Preview 4 AppData folder could be missing the cloud session/device enrollment held by an older QA folder.
* The Windows executable inventory needed a bounded startup publication path for Android administration.
* Startup presence could remain stale until the original engine reached its next cloud interval.

## Windows repair helper

`QuantumGuard.RemoteStartup.exe` runs before the existing WinUI application. It:

1. Repairs/migrates missing per-user cloud state from known older QA folders without deleting the source.
2. Restores and refreshes the Supabase session using Windows DPAPI.
3. Sends one authenticated startup heartbeat for the enrolled Windows device.
4. Fetches the selected Windows device context and merges only supported remotely-managed policy fields into the local config.
5. Publishes one bounded Windows executable inventory snapshot.
6. Launches the original `QuantumGuard.UI.exe`.

The helper exits after launch. The original `QuantumGuard.Engine.exe` remains the only protection/enforcement process.

## Supported Android Owner/Admin -> Windows controls

* Protected Apps using Windows executable paths
* Focus On/Off, allow/deny mode and Focus executable list
* Schedules
* After Hours
* Web Protection
* Ad/tracker filtering
* Web categories
* Blocked/allowed domains
* Download Guard, risky/all mode and blocked extensions
* Refresh Policy
* Lock Device / Lock Apps

Android-only app-install / Google Play restrictions are not Windows Preview 4 enforcement features.

## Backend migrations

* `20261003214639_windows_cross_platform_command_compatibility.sql`
* `20261003215622_device_context_presence_accuracy.sql`

Both are already applied to the Quantum Guard Supabase project.

## Integrity

All original Preview 4 files are preserved byte-for-byte except `Start Quantum Guard.cmd`, which intentionally launches the repair helper. The original launcher is retained as `Start Quantum Guard (Direct).cmd`.

Production updater feed remains unchanged. Physical Android -> Windows QA is still required.
