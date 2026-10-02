# Windows Preview 6 QA Checklist

## Upgrade from Preview 5

1. Start Preview 5 and confirm cloud sign-in and the Android device list.
2. Exit Preview 5 completely.
3. Start Preview 6.
4. Confirm the same cloud account, organization and selected device state remain available.
5. Confirm only one Quantum Guard protection engine is running.

## Android administration

1. Select an Android device and choose Manage Selected.
2. Test Focus, Web Protection, Download Guard, App Install blocking and Browser Download blocking.
3. Test Ad Block On and Off.
4. Test After Hours On and Off.
5. Request Refresh App List.
6. Block and allow one non-system Android app.
7. Test Lock Now.

## Mobile schedules

1. Open Mobile Schedules.
2. Enter valid HH:MM start and end times.
3. Select at least one day.
4. Select one or more protection features, or include the app selected on Device Admin.
5. Add the schedule and confirm it reaches Android.
6. Remove one schedule.
7. Test Clear All.

## Supabase efficiency

1. Confirm Windows heartbeats are about every 10 minutes.
2. Confirm policy recovery checks are about every 15 minutes.
3. Confirm an individual mobile toggle uses patch_device_policy.
4. Repeat an identical toggle and confirm the policy version does not increment unnecessarily.
5. Confirm app inventory is not continuously fetched while Device Admin is idle.

## Windows regression

Re-test Protected Apps, Focus, Windows Schedules, After Hours, Web Protection, Download Guard, Vault, tray behavior, startup, updater UI and common Windows DPI scales.
