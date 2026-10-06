# Quantum Guard Android 1.12.4 Functional Fix

This branch preserves the 1.12.3 functional-test APK line while applying targeted Android enforcement fixes.

Base APK SHA-256:

`0cc9a20fda41d017c464ee66f3bce285378b02af2663ed51b9af4f1fc4ff0c4c`

## Fixes included

* Prevent Quantum Guard's current package `com.quantumguard.android.uipreview` from blocking itself.
* Improve installed-app inventory visibility and report empty inventory diagnostics.
* Make `refresh_app_inventory` fail honestly when upload fails instead of reporting false success.
* Isolate enforcement subsystem exceptions so one failure does not permanently stop scheduled enforcement.
* Include command expiry in pending command sync and ignore commands whose `expires_at` has passed.
* Restart management after normal boot, package replacement and user unlock.
* Re-assert installation identity after restart/update so an update does not silently create another managed device.
* Report web/download service state, app inventory count, installation-claim state and package identity in heartbeat capabilities.
* Web Protector now reports missing VPN approval clearly.
* Web Protector routes common public encrypted-DNS resolver IPs into the local filter to reduce direct DoH/DoT bypass on personal devices.
* Download Guard reports missing folder access clearly and scans completed downloads more quickly.

## Reproduce

The patch file is `qg-1.12.4-smali.patch.xz.b64`.

1. Verify the input APK SHA-256 matches the value above.
2. Decode the APK with Apktool 3.0.3.
3. Decode the patch: `base64 -d qg-1.12.4-smali.patch.xz.b64 | xz -d > qg-1.12.4.patch`.
4. Apply it inside the decoded APK directory with `patch -p1 < qg-1.12.4.patch`.
5. Rebuild with Apktool.
6. Zip-align and sign with the appropriate QA or production Android signing identity.

Do not commit Android signing private keys or passwords.
