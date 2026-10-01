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

The GitHub repository is already private. The synchronized application source must therefore have **no runtime dependency on anonymous GitHub raw/release/API URLs** for updates or blocklists. Cloudflare must be the active public distribution path.

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

## 1A. Verify legacy-client migration

Read `docs/LEGACY_CLIENT_MIGRATION.md`.

Because the repository is private, test at least one older GitHub-only updater build and confirm it fails its update check safely without disabling local protection. Then verify a manual upgrade to the Cloudflare-capable preview preserves configuration and reaches a successful Cloudflare update check.

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

## 8. Release gate

When all previous items pass:

- update `docs/CURRENT_HANDOFF.md`
- update PR #3 with exact test results and commit/build hashes
- keep the legacy GitHub feed manual
- merge PR #3 only after review
- stage a signed preview release in R2
- publish its signed staging manifest last
- canary-test one device
- do not switch production until the Cloudflare updater is proven for every supported production client. Because the GitHub source repo is already private, explicitly verify that preview.4 and all future clients have no anonymous-GitHub runtime update dependency.
