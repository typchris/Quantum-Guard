# Quantum Guard Windows 1.11.0-preview.6 Mobile Admin QA

This branch continues directly from the exact Windows 1.11.0-preview.5 Mobile Admin QA source supplied for the Preview 6 build.

## Preview 6 additions

1. Remote Android Ad Block enable and disable controls from Windows.
2. Remote Android After Hours enable and disable controls.
3. A dedicated Mobile Schedules page in the Windows console.
4. Exact HH:MM schedule creation for Android using the Android device local time.
5. Schedules can activate Focus, Web Protection, Download Guard, App Install blocking, and a selected Android app.
6. Windows can refresh, remove, or clear mobile schedules.
7. Device Admin status now includes key policy states.
8. Mobile boolean controls use the atomic patch_device_policy RPC rather than read plus whole-policy rewrite.
9. Preview 6 detects a running Preview 5 QA instance and refuses to start a second protection engine.

## Upgrade behavior

Preview 6 intentionally preserves the Preview 5 QA AppData directory so local settings, encrypted Supabase session state, selected organization/device state and startup configuration continue forward.

## Supabase usage

Windows heartbeat remains 10 minutes.
Windows policy recovery remains 15 minutes.
Android app inventory remains on demand from the Windows console.
Existing policy row reuse, command de-duplication and Android delta inventory updates remain active.

This remains a QA build. Do not point the production updater feed at Preview 6 until Windows and Android cross-device QA is complete.
