# Quantum Guard Windows Preview 4 Remote Control Repair

This branch is the Windows cross-platform control handoff for the exact owner-supplied `QuantumGuard-1.11.0-preview.4-x64.zip` WinUI baseline.

## Baseline

The official Windows baseline for this work is the compiled WinUI 3 Preview 4 package, not the older Go-only Mobile Admin Preview 5/6 test builds.

Baseline ZIP SHA256:

`d5bee13c77ec988b38d7220dc5f04c78efd02718c85fbbe08492667d4ec9c2af`

Critical original binaries remain unchanged in the rebuilt QA package:

* QuantumGuard.Engine.exe: `ea1f15565b41292cf860e395bdcb3f6d8d8d5af4da6f5fc6a8b04d9bfb2af857`
* QuantumGuard.UI.exe: `f78d32a5a8b04fa206a98a7811425069bb0e9def245054bf1b19af92a76e94b9`
* QuantumGuard.UI.dll: `d08d61d502951c885ab6f095f7bc9bbf5707e33f8a8e4648b445c804f5185698`

## Failure found

Android Owner/Admin was successfully writing policy/commands to Supabase, but Windows was not consuming them reliably. Live Windows commands such as refresh_policy and lock_device remained pending. Earlier Windows Preview 5 tests also recorded unsupported start_focus and refresh_app_inventory commands.

Reverse engineering of the owner-supplied Preview 4 engine confirmed it already has:

* cloud session restore
* assigned-policy polling
* command polling and acknowledgement
* remote command execution
* WinUI named-pipe IPC
* approximately 60-second cloud worker cadence

The correct repair therefore keeps the original protection engine and fixes cloud-state recovery plus command compatibility rather than introducing a second enforcement engine.

## Rebuilt QA package

The QA package adds `QuantumGuard.RemoteStartup.exe` and makes it the default Start wrapper.

The helper:

1. Uses the correct `%APPDATA%\QuantumAppGuard` state directory.
2. Imports only missing cloud session/device enrollment fields from known earlier QA folders when needed.
3. Never deletes or modifies the source legacy state file.
4. Backs up the correct Preview 4 state before a migration write.
5. Resets only the local policy cursor after migration.
6. Restores the DPAPI session using the current Windows user.
7. Refreshes the Supabase session if needed.
8. Prefetches the current policy for the exact enrolled Windows device.
9. Merges only remotely managed policy fields into the local config before engine startup.
10. Preserves passwords, startup settings, vault information and unrelated local configuration.
11. Publishes one bounded Windows executable inventory snapshot at startup.
12. Launches the original QuantumGuard.UI.exe. The original QuantumGuard.Engine.exe remains the sole enforcement process.

The production updater feed is unchanged.

## Live backend fixes

Migration `20261003214639_windows_cross_platform_command_compatibility` maps Android-facing commands to the existing Windows command vocabulary and keeps stateful features policy-backed.

Migration `20261003215622_device_context_presence_accuracy` reports a target Offline when the last heartbeat is older than 15 minutes, preventing stale Windows rows from appearing actively connected.

## QA boundary

The rebuilt package passes static integrity/build checks, but physical Windows-to-Android validation is still required. Fully exit older QA builds before starting this package.