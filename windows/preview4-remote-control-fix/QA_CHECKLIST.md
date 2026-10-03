# Windows Remote Control QA

1. Fully exit every older Quantum Guard QA build.
2. Extract the whole rebuilt Preview 4 Remote Control QA package.
3. Run Start Quantum Guard.cmd.
4. Confirm only one QuantumGuard.Engine.exe is running.
5. Confirm Cloud & Devices shows the expected organization and Windows device.
6. If cloud sign-in is required, sign in once and restart.
7. Confirm %APPDATA%\QuantumAppGuard\remote_startup_repair.log records session/policy recovery.
8. From Android Preview 10 select the Windows target.
9. Test Focus On and Off.
10. Test Web Protection and Ad Blocking.
11. Test Download Guard and download policy.
12. Test blocked/allowed sites and web categories.
13. Test schedules and After Hours.
14. Test Protected Apps / Focus executable paths shown by the Windows startup inventory.
15. Send Refresh Policy and confirm it changes from pending to completed.
16. Send Lock Device and confirm the backend queues lock_apps for Windows.
17. Restart Windows Quantum Guard and confirm the latest remote policy is loaded before normal engine polling.
18. Confirm unrelated users/organizations cannot administer the Windows device.
19. Re-test local Windows app blocking, Focus, Web Protection, Download Guard, schedules, After Hours, vault, startup, tray behavior and updater UI.
20. Confirm the production update feed was not changed.