# Quantum Guard Android 1.11.0-preview.9 QA

Preview 9 keeps the Preview 8 UsageStats app blocker and reduces routine Supabase usage.

## Supabase efficiency

- Routine app inventory publication changes from every 30 minutes to every 6 hours.
- App inventory still publishes when the protection service starts.
- Package install/remove/change broadcasts still request a fresh inventory.
- The Windows admin console can request an immediate inventory refresh.
- The backend now delta-upserts app inventory instead of deleting and reinserting every package.
- Identical repeated policy writes are coalesced and a device's assigned policy row is reused when safe.
- Rapid duplicate pending commands are coalesced for 10 seconds.

## Existing Preview 8 behavior retained

- UsageStatsManager foreground app detection.
- Display-over-apps blocking overlay.
- Usage Access and overlay Special Access onboarding.
- Accessibility fallback.
- Web Protection, Download Guard, schedules, protected apps and managed-device controls.
