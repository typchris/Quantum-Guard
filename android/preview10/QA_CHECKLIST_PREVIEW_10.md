# Android Preview 10 QA Checklist

## A. Authorization regression

1. Sign in as an organization owner on the administrator device.
2. Select a managed device that has an explicit client device assignment.
3. Confirm the target resolves as Owner or Admin and no HTTP 400 DEVICE ADMINISTRATOR REQUIRED error appears.
4. Change at least one target policy setting successfully.
5. Sign in with an unrelated organization account and confirm the same target is not accessible or administrable.

## B. Device switching

1. Open the global device selector.
2. Switch from the local administrator phone to an Android client device.
3. Confirm the Dashboard identifies the selected target device.
4. Confirm Focus, Web Protection and Download Guard states match the target policy rather than the administrator phone.
5. Switch between two targets repeatedly and confirm state does not leak between devices.
6. Delete or revoke a previously selected target and confirm the app falls back safely to a valid device.

## C. Persistent remote controls

For each control below, change it from the administrator device and verify the target Android device changes within normal Realtime timing and remains in that state after another policy sync:

1. Focus On and Off.
2. Focus allow-list / deny-list mode.
3. Focus app list.
4. Protected Apps block and allow.
5. Web Protection On and Off.
6. Ad and Tracker Blocking On and Off.
7. Web categories.
8. Blocked domains.
9. Allowed domains.
10. Download Guard On and Off.
11. Download mode and blocked extensions.
12. Browser download blocking.
13. App install blocking.
14. Schedules.
15. After Hours enabled state, times, weekdays and override minutes.

After each group, wait for or manually request another policy refresh and confirm the state does not revert.

## D. Legacy admin compatibility

Using an older admin client where practical:

1. Send Start Focus and confirm focus_mode also becomes true in persistent cloud policy.
2. Send Stop Focus and confirm focus_mode becomes false.
3. Enable and disable Web Protection and confirm persistent policy follows.
4. Enable and disable Download Guard and confirm persistent policy follows.
5. Lock All Apps and confirm persistent Focus policy represents the lock.

## E. Realtime command path

1. Send Refresh Policy and confirm one command is completed.
2. Confirm the command acknowledgement does not cause a repeating command/sync feedback loop.
3. Send an unsupported test command in a controlled QA environment and confirm it is acknowledged failed, not completed.
4. Disconnect networking, make a cloud change, reconnect, and confirm recovery synchronization applies it.
5. Force several service start requests and confirm recurring jobs do not multiply.

## F. Capability reporting

On the selected Android target confirm the administrator screen reports the actual state of:

1. Usage Access.
2. Display over other apps.
3. Accessibility.
4. VPN permission.
5. all-files access.
6. battery optimization exemption.
7. Device Admin.
8. Device Owner/Profile Owner.
9. app-blocking readiness.
10. blocklist availability.
11. selected Download Guard folder.

Disable one local prerequisite on the target, return to Quantum Guard, and confirm the capability heartbeat refreshes promptly and reports the limitation. Repeated activity/service starts must not create duplicate recurring sync jobs.

## G. App blocking

1. Refresh the target installed-app inventory.
2. Confirm the remote inventory corresponds to the target phone, not the admin phone.
3. Block a normal non-system app remotely.
4. Launch the app on the target and confirm the UsageStats/overlay blocker or managed suspension blocks it.
5. Allow the app remotely and confirm it opens again.
6. Verify Play Store install blocking in the modes supported by the target's management authority.

## H. Lock, management-channel and enrollment protection

1. Test Lock Now on a device with legacy Device Admin authority.
2. Test Lock Now on Device Owner/Profile Owner where available.
3. Confirm unsupported lock authority is reported clearly instead of showing false success.
4. On a device whose local effective role is Client, attempt local Sign Out and confirm it is rejected.
5. On the same Client device, attempt to enroll or pair the already-managed installation into another organization and confirm it is rejected.
6. Send the legacy remote sign_out_user command and confirm the command fails instead of disconnecting the managed Android endpoint.
7. Confirm the client remains signed in to the management channel and continues receiving policy updates after the failed sign-out command.
8. Confirm Preview 10 claims its installation identity once, stores it on the existing device record, and does not create a duplicate device.
9. Repeat the installation claim and confirm it is idempotent.

## I. Existing protection regression

Re-test:

1. UsageStats app blocking.
2. Overlay blocking.
3. Accessibility fallback.
4. Device Owner/Profile Owner suspension.
5. Web Protection VPN.
6. AdAway and UT1 category filtering.
7. Download Guard.
8. schedules.
9. After Hours.
10. app inventory event refresh.
11. Google sign-in.
12. enrollment and recovery.
13. duplicate-device prevention.
14. managed Client resistance to sign-out/re-enrollment bypass.
15. installation identity claim and recovery.

## J. Security and package

1. App reports 1.11.0-preview.10.
2. POST_NOTIFICATIONS is absent.
3. Required special-access declarations remain present.
4. No Supabase service-role key exists in the APK/source.
5. No hardcoded QA keystore password exists.
6. If protected replacement signing secrets are configured, the APK signature matches QG_ANDROID_QA_CERT_SHA256.
7. If CI reports ephemeral-fresh-install signing, confirm the old QA app is uninstalled before installing this APK.
8. The old public QA signing identity is not used.
