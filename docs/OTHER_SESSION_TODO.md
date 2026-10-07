# Cloudflare/local-source session TODO

Use this list in the session that has both the local Quantum Guard 1.11.0-preview.4 source tree and the `cloudflare-api` MCP.

Work from GitHub branch:

`security/preview3-release-hardening`

and Draft PR #3.

Do **not** publish a production release while completing these steps.

## 0. Protect the private source repository

The repository is private, but `main` is currently unprotected.

In GitHub Settings, add a branch protection rule or repository ruleset for `main` that:

- requires changes through pull requests
- requires the `Repository validation` status check
- blocks force pushes
- blocks branch deletion
- dismisses stale approvals after new commits if review is enabled
- restricts bypasses to the account owner only when emergency recovery is needed

Do not disable validation just to merge PR #3.

## 1. Synchronize the tested preview.4 application source

As of 2026-10-03 the GitHub repository is public. The synchronized application source must still have **no security dependency on anonymous GitHub raw/release/API URLs** for updates or blocklists. Cloudflare should be the controlled public distribution path, and repository visibility must not be treated as an authorization boundary.

Commit the complete source that produced the tested preview.4 build, including:

- WinUI 3 / Windows App SDK UI project
- Go engine source and current `go.mod` / `go.sum`
- signed-manifest client verification
- Cloudflare staging update endpoint configuration
- tested Go dependency upgrade
- authenticated installer handoff
- first-start health acknowledgement
- rollback request/failure path
- startup/service migration changes
- Admin/Client role restrictions
- profile roaming/preferences wired through `update_my_profile_preferences` rather than direct `profiles` table updates; the RPC only changes display name, HTTPS avatar URL and profile settings

Do not commit generated secrets, OAuth client secrets, service-role keys, signing private keys, PFX files or Cloudflare credentials.

After the source is committed, rerun:

- Go tests
- WinUI build
- all ten page UI checks
- managed Client navigation checks
- collapsed-sidebar checks
- signed-manifest tests
- local security test groups
- private-repository runtime URL scan
- diagnostic upload success path where Supabase returns an empty success response

## 1B. Preview.4 protection regressions

Preserve and verify the exact user-facing fixes already reported in the preview.4 engine:

- Quantum Guard running + Web Protection ON: loopback proxy filters.
- Quantum Guard running + Web Protection OFF: proxy remains alive in pass-through mode and normal browsing works.
- Browser proxy policy is removed only when the Quantum Guard engine actually exits through its authorized exit path.
- Startup repairs stale Quantum Guard-owned proxy state after an abnormal stop without overwriting unrelated enterprise proxy settings.
- Download Guard ON + `all`: Quantum Guard Chrome/Edge block-all policy is active.
- Download Guard ON + `risky`: block-all policy is removed; risky completed files are quarantined.
- Download Guard OFF: all Quantum Guard-owned Chrome/Edge download restrictions are removed immediately.
- Startup removes stale Quantum Guard download policies whenever Download Guard is OFF.

Run these on real Chrome and Edge with `chrome://policy` / `edge://policy` visible during transitions.

## 1C. Cloud polling redesign

The uploaded preview.4 engine still runs heartbeat, policy fallback, and command polling together at roughly 60-second intervals.

**Server-side mitigation now live:** `device_heartbeat` coalesces identical device/profile writes to roughly one write every 8 minutes while preserving immediate writes for changed version/host/user/OS/control-derived status. This reduces database write churn only; it does not reduce the client's network request frequency. Preserve migration `20261002010810_quantum_guard_coalesce_frequent_heartbeats.sql` and its regression test.

In the exact Go source, separate those concerns:

- device heartbeat: approximately every 10 minutes
- policy fallback: approximately every 10-15 minutes
- admin changes/commands: event-driven immediate refresh via Supabase Realtime/Broadcast or the existing Cloudflare path where practical
- repeated failures: exponential backoff with a sensible cap and reset after success
- keep a fallback poll so missed/offline notifications eventually recover

Add timing/backoff tests and verify the resulting request rate stays comfortably within the intended free-service limits.

## 1D. Diagnostic UI and safe payload

A QA binary package wording patch now uses `Send diagnostic report`, but that patch is not a substitute for source. Port the same wording into the exact WinUI/Go source and implement the real preview control there.

Update the WinUI source to:

- label the action `Send diagnostic report`
- add `View what will be sent`
- show: `Send diagnostic report securely to your Quantum Guard administrator. Reports are private and automatically deleted after 30 days.`
- make the preview show the exact payload before upload

The payload may contain only bounded technical data such as version/build, Windows version, protection feature states, engine/service state, cloud/enrollment state, and relevant Quantum Guard error summaries. It must never include passwords, Supabase/Google tokens, browsing history, personal files, Vault contents, administrator credentials, or arbitrary log/file contents.

## 1A. Verify legacy-client migration

Read `docs/LEGACY_CLIENT_MIGRATION.md`.

Because repository visibility can change and must not be a security dependency, test at least one older GitHub-only updater build and confirm it fails its update check safely without disabling local protection. Then verify a manual upgrade to the Cloudflare-capable preview preserves configuration and reaches a successful Cloudflare update check.

Do not put GitHub credentials in the client.

## 2. Synchronize the exact deployed Cloudflare Worker source

The GitHub Worker source is deliberately blocked because it is older than the live staging deployment.

Using the connected Cloudflare MCP, inspect/export the **currently deployed staging Worker** and synchronize its exact reviewed source/configuration into:

`cloudflare/update-edge/`

Preserve:

- signed update manifest flow
- private R2 distribution
- private report routes
- report authorization
- query-string redaction
- removed temporary upload routes
- current R2 bindings
- `package-lock.json` generated from the reviewed Worker dependencies so GitHub deploys can use `npm ci` reproducibly
- current staging key ID/public-key behavior
- current no-release staging state
- diagnostic upload completion handling that accepts a successful empty Supabase response without deleting the stored object

Do not copy secret values into GitHub.

Run the Worker test suite and a dry-run deployment.

Only after the GitHub source matches the reviewed deployed Worker:

1. delete `cloudflare/update-edge/SOURCE_SYNC_REQUIRED.md`
2. commit that deletion in the **same commit** as the synchronized Worker source
3. verify repository validation passes
4. manually dispatch the Cloudflare workflow only if a deployment is actually needed

The workflow must remain manual and must continue using `CLOUDFLARE_WORKER_DEPLOY_TOKEN`.

## 2A. Diagnostic object storage decision

The current QA Worker uses private Cloudflare R2 for report objects. The requested production target is Cloudflare Worker gateway -> private Backblaze B2 object storage -> Supabase metadata/authorization.

Do not invent or commit B2 credentials. If B2 is selected for production, create a private B2 bucket/app key outside the client, store the credentials only as Worker/server secrets, keep 30-day deletion enforcement, and verify admins access reports only through `Cloud & Devices > Diagnostics`.

Until B2 credentials and the exact live Worker source are available, keep the working private R2 staging path rather than breaking diagnostics.

## 3. Synchronize the tested installer integration

The GitHub installer foundation is also deliberately blocked because the other session reported newer preview.4 handoff/health behavior.

Replace/synchronize the tested installer and application integration, then remove:

`installer/SOURCE_SYNC_REQUIRED.md`

in the same reviewed commit.

The synchronized installer must not use process-name `taskkill` as its production handoff.

Verify:

- authenticated app/engine shutdown handoff
- versioned install directories
- previous-version retention
- startup/service migration
- first-start health acknowledgement
- rollback on failed/missing health
- uninstall path
- fixed `Program Files\\Quantum Guard` install root
- refusal to recursively uninstall from an unexpected/tampered install root
- rollback rejection of invalid version/path traversal values

## 3A. Automatic retention — completed on Supabase

The live database now has daily service-role-only cleanup for expired/used pairing codes, completed/failed/expired commands older than 30 days, routine/info events older than 30 days, and superseded unassigned policy versions. The existing expired report-archive metadata cleanup remains separate. Auth tables are untouched.

The rollback-only retention regression passes. Preserve migration `20261002001113_quantum_guard_automatic_retention_cleanup.sql` and its regression test when synchronizing source.

## 4. Cloudflare token replacement

The broad Cloudflare account token still needs to be replaced.

Create/verify separate credentials:

- Worker deployment token scoped only to the Quantum Guard account/Worker
- R2 publisher token/credentials restricted to the distribution bucket

Add them to the appropriate protected GitHub environment/secrets without exposing their values in chat or source.

After staging deployment and R2 publishing work with the new credentials, revoke the old broad token.

The current Cloudflare MCP connection may not have API-token-management permission, so this may require the Cloudflare dashboard/account owner.

## 5. MFA

The account owner must visibly enable MFA/passkeys for:

- GitHub
- Supabase
- Cloudflare

Store recovery material offline.

This cannot be marked complete by code changes.

## 6. Trusted Windows code signing

No trusted code-signing certificate was found on the development PC.

Choose/acquire a trusted Windows code-signing certificate or signing service. For the repository `signtool` helper, install/expose the signing identity through the Windows certificate store/HSM provider and reference it by thumbprint; do not pass a PFX password on a command line.

Do not paste or commit its private key/password.

Then test the repository signing flow:

1. sign first-party binaries
2. verify signature/publisher/timestamp
3. build installer
4. sign installer
5. verify installer
6. compute final SHA-256/size from the signed installer

Unsigned builds may be used only for preview QA.

## 7. Live Windows acceptance matrix

Before enabling automatic installation, test on real Windows:

- fresh install
- upgrade from the currently working preview
- successful health acknowledgement
- forced startup failure and rollback
- interrupted installation
- startup/service migration
- uninstall
- 100%, 125%, 150%, 175% DPI
- owner/admin/client role behavior
- staging update check/download
- bad manifest signature rejection
- bad SHA-256 rejection
- wrong platform/version rejection
- Authenticode failure rejection once signing is configured

## 7A. Stable 1.11.0 conversion — only after QA

Do not perform this while preview.4 QA is incomplete. After all release gates pass:

- version -> `1.11.0`
- remove WinUI Preview / QA banner text
- change updater channel from preview to stable
- preserve settings, enrollment, organizations and policies
- replace the temporary green `QG` mark with the official Quantum Guard logo in the Control Center, app icon, tray icon, installer, updater, and future mobile packages

Only use an official logo asset that is actually supplied/approved; do not invent a replacement.

## 8. Release gate

When all previous items pass:

- update `docs/CURRENT_HANDOFF.md`
- update PR #3 with exact test results and commit/build hashes
- keep the legacy GitHub feed manual
- merge PR #3 only after review
- stage a signed preview release in R2
- publish its signed staging manifest last
- canary-test one device
- do not switch production until the Cloudflare updater is proven for every supported production client. Explicitly verify that preview.4 and all future clients have no security dependency on anonymous GitHub runtime update URLs, regardless of whether the repository is public or private.
