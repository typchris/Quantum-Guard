# Quantum Guard Android 1.11.0-preview.10 Admin Reliability

Preview 10 is the release-blocking Android administration reliability pass.

## Backend corrections already live

1. Device-role precedence uses the highest valid authority. Organization Owner/Admin is no longer demoted by a lower per-device assignment.
2. Device context now reports `can_administer`, target platform/version/presence and enforcement capabilities.
3. Android heartbeat v2 reports readiness/capability state with coalesced routine writes.
4. Legacy persistent-state commands first patch the desired device policy so later recovery sync does not undo the administrator action.
5. Cross-organization access remains denied.

## Android corrections

1. Device switching resolves target context before administrative actions.
2. Remote Dashboard and policy pages use the selected target policy rather than the administrator phone's local PolicyStore.
3. Signed-in Client controls fail closed from the cloud role.
4. Device-spinner initialization preserves the intended selected target.
5. Protected Apps, Focus, Schedules, After Hours, Web Protection and Download Guard automatically hydrate from the selected target.
6. Persistent controls use atomic policy patches.
7. Realtime command subscription uses INSERT only, avoiding acknowledgement-triggered sync loops.
8. Repeated service starts do not create duplicate periodic workers or Realtime loops.
9. Capability reporting covers Usage Access, overlay, Accessibility, VPN permission, battery/background state, Device Owner/Profile Owner, app-block readiness and download-folder readiness.
10. Remote Lock reports failure when Android management authority is insufficient.
11. Unsupported commands are marked failed.
12. Device presence is derived from `last_seen_at`.
13. Local UI is notified when cloud policy is applied.

## Validation status

The Preview 10 GitHub Actions workflow reconstructs Preview 6, Preview 7, Preview 8, Preview 9 and the verified Preview 10 patch chain. Static checks and blocklist generation pass. Compilation, unit tests and Android lint run before the release signing gate.

The final APK is intentionally blocked until a newly rotated QA signing identity is configured. The previously exposed QA key is not accepted as a fallback.

Required protected GitHub Actions secrets:

* `QG_ANDROID_QA_KEYSTORE_B64`
* `QG_ANDROID_QA_STORE_PASSWORD`
* `QG_ANDROID_QA_KEY_PASSWORD`
* `QG_ANDROID_QA_CERT_SHA256`
