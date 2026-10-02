# Android Preview 6 QA Checklist

## Package
- Confirm app reports `1.11.0-preview.6`.
- Confirm APK contains `assets/adaway.qgh` and all `assets/UT1/*.qgh` category files.

## App inventory
- Open Rules -> Protected Apps on the local Android device.
- Choose installed apps and confirm current apps appear immediately with app name and package ID.
- Install/uninstall an app, keep Quantum Guard running, and confirm inventory refreshes.

## Web Protection
- Grant VPN permission.
- Confirm Web Protection page reports full blocklists installed.
- Add a custom blocked domain and confirm it fails to resolve/load through ordinary browser DNS.
- Enable Ad & Tracker Blocking and verify known AdAway-listed domains are blocked.
- Test at least one enabled UT1 category.
- In managed-device mode, inspect `chrome://policy` / Edge policy page and confirm supported managed policies are present.

## Download Guard
- Risky mode: verify risky downloads are blocked by supported managed Chrome/Edge versions, or quarantined in the selected monitored folder on personal-device mode.
- All mode: verify supported managed Chrome/Edge downloads are blocked.
- Verify temporary `.crdownload`, `.part`, `.tmp` files are not prematurely quarantined.

## Google Play install blocking
- Device Owner/Profile Owner: enable Block app installs, including Google Play, and verify installs are denied by Android.
- Personal-device fallback: enable Accessibility and confirm opening Play Store is blocked while the setting is active.

## Schedules
- Add a schedule with exact start/end time and selected weekdays.
- Test an app-only schedule.
- Test scheduled Focus.
- Test scheduled Web Protection.
- Test scheduled Download Guard.
- Test scheduled app-install blocking.
- Confirm restrictions stop outside the scheduled interval unless the base feature toggle is independently enabled.

## UI
- Verify Dashboard, Rules, Activity, Devices bottom navigation.
- Verify Settings remains reachable from the top-right button.
- Verify cards and controls fit common phone sizes without horizontal clipping.
