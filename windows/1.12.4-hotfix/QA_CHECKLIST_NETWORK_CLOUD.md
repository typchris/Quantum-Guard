# Windows 1.12.4 Network Hotfix QA

This checklist is for the 1.12.3 mitigation helpers and the eventual in-engine 1.12.4 implementation.

## Immediate 1.12.3 mitigation

1. Exit Quantum Guard completely.
2. Run `Start Quantum Guard - Network Safe.cmd`.
3. Confirm normal browsing works before enabling Web Protection.
4. Enable Web Protection and load at least five HTTPS sites in Edge and Chrome.
5. Disable Web Protection and confirm the same sites still load without unusual delay.
6. Exit Quantum Guard normally. Confirm Windows proxy settings no longer point to `127.0.0.1:53679`.
7. Start again, then force-kill only the main engine. Wait at least 15 seconds.
8. If the built-in watchdog restarts the main engine, browsing must recover without manual changes.
9. If the engine does not restart, the temporary guardian must remove stale QGuard proxy settings.
10. Confirm `%APPDATA%\QuantumAppGuard\network-recovery\network-guardian.log` records the path taken.

## Do not destroy unrelated proxy configuration

Before testing on a machine that uses a VPN, PAC file, corporate proxy, or manually configured proxy, record those settings.

The recovery helper only clears values that still point at the known QGuard endpoint. The final in-engine implementation must restore the exact prior state from an ownership snapshot instead of assuming direct internet access.

## Cloud sign-in

1. Use the existing enrolled Windows device.
2. Sign out and sign back in using Google.
3. Confirm the PKCE token exchange succeeds.
4. Confirm Windows makes authenticated calls to `recover_my_device_v2`, `get_my_device_context`, and when required `enroll_device_v2`.
5. Confirm the same device UUID is retained.
6. Confirm a stable non-empty Windows `installation_id` is stored in Supabase.
7. Restart twice and confirm no second Windows device row is created.
8. Test a stale cached local user ID and verify server-authorized recovery succeeds without an external account-specific script.
9. Test a different Google account and verify it cannot take over the existing installation.
10. Confirm Android Google sign-in is unaffected.

## Release blockers

Do not publish 1.12.4 if any of these occur:

- browser remains pointed to a dead QGuard proxy after exit or crash
- Web Protection OFF still blocks or materially delays ordinary browsing
- shutdown/sign-out leaves stale QGuard proxy policy
- watchdog restart races with proxy cleanup
- third-party proxy configuration is overwritten
- Windows login requires the account-specific recovery script
- Windows upgrade creates another device row
