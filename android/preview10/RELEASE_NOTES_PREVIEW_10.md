# Quantum Guard Android 1.11.0-preview.10

Preview 10 is the Android cross-device administration reliability release.

## Release objective

Make Android administration reliable when one Quantum Guard device controls another device. This release focuses on authorization, device switching, persistent remote state, Realtime behavior, service lifecycle, and accurate target-device status.

## Administrator authorization

The backend now resolves the highest valid authority for a device.

Priority is:

1. Organization owner or device owner
2. Organization admin or device admin
3. Client

An explicit client assignment can no longer demote an organization owner or administrator. This fixes the HTTP 400 DEVICE ADMINISTRATOR REQUIRED error seen when an organization owner selected some managed devices.

Cross-organization access remains denied.

## Remote state and device switching

The Android admin dashboard now loads the selected target device context instead of reading the administrator phone's local PolicyStore.

Remote screens use the target device's:

* policy settings
* role and can-administer state
* platform
* Android/OS version
* Quantum Guard agent version
* online/control status
* reported enforcement capabilities

When a different device is selected, stale target context is invalidated before the new target is rendered.

## Persistent remote controls

Persistent settings now use the atomic patch_device_policy RPC rather than transient commands or whole-policy replacement.

This covers:

* Focus enabled state
* Focus allow/deny mode and app list
* Protected Apps
* Web Protection
* Ad and tracker blocking
* web categories
* blocked and allowed domains
* Download Guard
* download mode and extensions
* browser download blocking
* app install blocking
* schedules
* After Hours

Immediate commands remain for one-shot actions such as Lock Now and Refresh Policy.

The backend also keeps older admin clients compatible. Legacy Focus/Web/Download state commands now update persistent policy before the immediate command is queued, so the next policy synchronization cannot undo the requested state.

## Realtime and service reliability

* device_commands Realtime listens for INSERT only, so command acknowledgement UPDATE events no longer trigger a feedback sync.
* CloudSyncService installs recurring timers only once per service instance.
* Realtime reconnect attempts are guarded so multiple reconnect timers cannot stack.
* The Realtime heartbeat is scheduled once rather than once per reconnect.
* Unsupported commands are acknowledged as failed rather than completed.

## Device capability reporting

Preview 10 sends a compact capability object with device_heartbeat_v2. The admin UI can report whether the selected Android device has the prerequisites needed for enforcement, including:

* Usage Access
* Display over other apps
* Accessibility
* VPN approval
* all-files special access
* battery unrestricted state
* legacy Device Admin
* Device Owner
* Profile Owner
* managed-owner capability
* app-blocking readiness
* blocklist availability
* selected download folder

This prevents the administrator UI from implying full enforcement when Android has not granted the required authority.

## Lock and managed-client channel protection

Lock Device works with legacy Device Admin and Device Owner/Profile Owner authority where Android permits it.

The fine-tooth security review found that signing a managed Android client out of cloud administration could orphan that endpoint after reboot. Preview 10 therefore rejects the legacy remote sign_out_user command on managed Android clients instead of disconnecting the management channel.

Local Sign Out, re-enrollment and pairing of an already enrolled Android installation are gated by the local device's Owner/Admin authority. A Client role can no longer use those controls to detach itself from administration.

Preview 10 also claims a stable installation identity against the existing device record. The backend enforces uniqueness for claimed platform/installation identities, which strengthens duplicate-device prevention and blocks a claimed installation from silently becoming a second device record in another organization. The claim is made once per installation and is idempotent.

## Supabase efficiency retained

Preview 10 keeps the existing low-usage design:

* about 10-minute routine client heartbeat cadence, with an immediate coalesced readiness heartbeat after returning from Android special-access settings
* about 15-minute policy recovery sync
* event-driven Realtime updates
* six-hour routine app inventory fallback plus install/remove and on-demand refresh
* atomic policy patches
* identical policy no-ops
* command coalescing
* delta app inventory updates

## Security

The previously exposed QA signing identity is not used by the Preview 10 workflow.

For stable upgrade-capable QA releases, configure a replacement signing identity through protected GitHub Actions secrets:

* QG_ANDROID_QA_KEYSTORE_B64
* QG_ANDROID_QA_STORE_PASSWORD
* QG_ANDROID_QA_KEY_PASSWORD
* QG_ANDROID_QA_CERT_SHA256

The replacement keystore must contain alias quantumguard-preview.

If these protected secrets are not configured, CI generates a new ephemeral signing identity inside the GitHub runner. The private key is not committed or exported. That artifact is safe for fresh-install QA, but it cannot update an APK signed by the old or a different certificate.

## Validation boundary

CI can validate reconstruction, source checks, unit tests, Android lint, APK creation, signature identity, permissions, and package metadata. Physical-device tests are still required for actual Android enforcement and cross-device timing.
