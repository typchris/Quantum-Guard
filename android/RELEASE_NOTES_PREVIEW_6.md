# Quantum Guard Android 1.11.0-preview.6

Preview 6 is an Android enforcement and mobile UI QA build.

## Protection fixes

- Fixed Google Play install blocking in managed-device mode with Android's app-install restriction.
- Added Accessibility fallback that blocks entry to Google Play when install blocking is requested on personal-device QA installs.
- Added managed Chrome and Microsoft Edge download policy enforcement where supported by installed browser versions.
- Retained user-approved-folder quarantine as a personal-device and browser-independent fallback.
- Ships full Quantum Guard AdAway and UT1 QGH blocklists in the APK.
- Local VPN DNS filtering now uses the full category data and records blocked-query counters.
- Added common encrypted-DNS endpoint blocking and managed-browser Secure DNS disable policy where Android management authority permits it.
- Installed-app inventory is scanned immediately on the local phone and refreshed after app install/remove events.
- Remote devices can be asked to refresh app inventory through the shared command channel.

## Scheduling

- Replaced raw schedule bitmask entry with day checkboxes and Android time pickers.
- Schedules can target selected apps and can activate Focus, Web Protection, Download Guard, and app-install blocking.
- Schedule enforcement uses the target device's local time.

## Mobile UI

- New Dashboard, Rules, Activity, and Devices bottom navigation.
- Updated forest/mint Quantum Guard mobile visual system based on the approved Guardian Pulse reference.
- Added protection status, quick actions, System Defenses cards, counters, recent activity, device targeting, and clearer managed-vs-personal capability messaging.

## Android enforcement note

Android Device Owner/Profile Owner mode provides the strongest enforcement. Personal-device installs cannot universally intercept every browser or Play Store operation because the Android OS intentionally restricts those capabilities. Quantum Guard uses the strongest consent-based fallbacks available in that mode.
