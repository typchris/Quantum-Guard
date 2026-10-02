# Quantum Guard Android 1.11.0-preview.8 QA

Preview 8 adds a native Android UsageStatsManager app-blocking engine on top of Preview 7.

## App blocking

- Uses `UsageStatsManager.queryEvents()` with `PACKAGE_USAGE_STATS` to detect the current foreground package on personal devices.
- Uses `SYSTEM_ALERT_WINDOW` / `TYPE_APPLICATION_OVERLAY` to place a Quantum Guard blocking screen over restricted apps.
- Reuses the existing Quantum Guard foreground protection service instead of creating a second always-running service.
- Device Owner/Profile Owner package suspension remains the strongest managed-device enforcement path.
- Accessibility remains available as an optional faster fallback and for browser/Play Store UI interception.
- App inventory now includes last-used time and seven-day foreground usage when Usage Access is granted.

## Special Access onboarding

- On app launch, personal-device users are prompted to complete Usage Access and Display over other apps.
- The guided flow also offers the battery-optimization exemption for background reliability.
- The old Accessibility-only blocking prompt is replaced by a choice between Usage Access + overlay and Accessibility.
- Normal `POST_NOTIFICATIONS` remains absent. Android 13+ may still show an active-app entry in the system Task Manager for foreground services.

## Existing Preview 7 protections retained

- Web Protection VPN, UT1/AdAway filtering, Download Guard, schedules, app inventory, stable QA signing, idempotent device enrollment, device recovery and device switching are preserved.
