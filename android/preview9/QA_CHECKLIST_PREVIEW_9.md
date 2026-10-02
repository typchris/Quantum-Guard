# Android Preview 9 QA Checklist

## Regression
- Complete the Preview 8 Special Access setup and confirm Usage Access plus Display over other apps remain enabled.
- With Accessibility off, block a normal app and confirm the Quantum Guard overlay appears.
- Re-test Web Protection, Download Guard, schedules, Focus and Play Store install blocking.

## PC administration
- From the Windows Device Admin page select this Android device.
- Toggle Focus, Web Protection, Download Guard, app-install blocking and browser-download blocking.
- Confirm each assigned policy change reaches Android.
- Request Refresh App List from Windows and confirm installed apps appear on the PC.
- Block and allow a selected Android app from Windows and confirm enforcement changes.

## Supabase efficiency
- Confirm the app inventory is not scheduled every 30 minutes.
- Install or remove an app and confirm inventory still refreshes from the package-change receiver.
- Use Refresh App List from Windows and confirm an immediate inventory publish.
