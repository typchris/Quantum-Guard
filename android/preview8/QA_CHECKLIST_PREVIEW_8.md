# Android Preview 8 QA Checklist

## First launch / special access
- Open Quantum Guard and confirm the App Protection setup prompt appears on a personal device.
- Tap Start setup, grant Usage Access, return, then grant Display over other apps.
- Confirm battery optimization exemption is offered.
- Confirm Settings reports Usage Access and Display over apps as enabled.
- Confirm Quantum Guard does not request normal notification permission.

## UsageStats app blocking
- Leave Accessibility disabled to test the new path independently.
- Add a normal user app to Protected Apps.
- Launch it and confirm the Quantum Guard full-screen blocked overlay appears.
- Tap Return to Home and confirm the overlay clears.
- Test Focus Engine, schedule blocking and After Hours with Accessibility still disabled.
- Enable Play Store install blocking and confirm Play Store is covered by the blocking overlay on personal-device mode.

## Accessibility fallback
- Enable Accessibility and confirm existing blocking still works.

## Managed device
- On Device Owner/Profile Owner provisioning, confirm package suspension remains the primary blocking path and no overlay is needed.

## Inventory
- Grant Usage Access, refresh app inventory, and confirm metadata includes last-used and seven-day foreground usage values for recently used apps.

## Existing Preview 7 regression
- Re-test Google sign-in, device recovery, Web Protection, ad/category filtering, Download Guard, schedules, app inventory, device switching and duplicate-device prevention.
