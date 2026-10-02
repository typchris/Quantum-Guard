# Quantum Guard current handoff

**Date:** 2026-10-01  
**Windows baseline:** 1.11.0-preview.4 local WinUI/Go work  
**Android baseline:** 1.11.0-preview.2  
**GitHub branch:** `security/preview3-release-hardening`  
**Draft PR:** #3  
**GitHub visibility:** private as of 2026-10-01  
**Production release/feed:** intentionally unchanged

This file is the shared checkpoint for switching between ChatGPT/Codex sessions. Do not infer that a local-only change is in GitHub unless it is explicitly listed below.

## Live and verified

### Supabase

- Project: `goffrcpfelmgqbidaxhb`.
- `admin-account-control` is live as **version 9**, ACTIVE, with JWT verification enabled.
- The account-control HTTP boundary rejects oversized request bodies above 16 KiB and validates target UUID/status before calling the database RPC.
- Edge Function dependencies are pinned to exact versions:
  - `jsr:@supabase/functions-js@2.5.0/edge-runtime.d.ts`
  - `npm:@supabase/supabase-js@2.117.2`
- Account-wide status changes delegate to `apply_account_status_change`.
- The database transaction updates profile status, fans commands out to all authorized target organizations/devices, and creates one audit row per target organization.
- Auth ban/unban synchronization is finalized through the service-role-only `finalize_account_status_auth_sync` RPC.
- Rollback-only regression tests passed for:
  - cross-organization command/event/policy rejection
  - client device isolation
  - suspended-admin denial
  - own-device status availability
  - two-organization account status fan-out
  - pairing-code generation through schema-qualified pgcrypto, including format/expiry clamp and client denial
- `report_archives` has no direct `authenticated` table grant. It now also has an explicit deny-all authenticated RLS policy, while checked SECURITY DEFINER RPCs and service-role server logic remain the only intended access paths.
- Database-level size/length constraints now cap common profile, organization, device, policy, command, event, pairing-code and audit inputs to reduce storage-abuse risk.
- Unreachable authenticated table-write grants were revoked, and organization creation now requires the checked `create_organization` RPC.
- Missing foreign-key indexes were added and all Supabase auth-RLS initplan warnings were cleared; the performance advisor now shows only unused-index informational findings.
- `update_my_profile_preferences` is live as the safe profile-roaming write path. It updates only display name, HTTPS avatar URL and profile settings, while direct authenticated profile UPDATE remains unavailable.
- Automatic retention is live through `run_quantum_guard_retention_cleanup()` plus pg_cron. Daily cleanup removes expired/used pairing codes, completed/failed/expired commands older than 30 days, routine/info events older than 30 days, and old unassigned policy versions when a newer same-name version exists. The existing expired report-archive metadata cleanup remains separate. Supabase Auth tables are not touched.
- The retention regression passed in a rollback transaction, verifying stale rows are removed while critical events and the assigned current policy are retained.

### GitHub

- The repository is private.
- The `main` branch is currently unprotected. Add a ruleset/branch protection requiring PR review and the `Repository validation` check, and block force pushes/deletions before merging release hardening.

- Draft PR #3 is the release-hardening integration PR.
- The branch contains:
  - Supabase multi-org migration and regression test
  - live Edge Function source
  - NSIS installer foundation
  - rollback helper
  - Authenticode/RFC3161 signing helper
  - Cloudflare credential-split guidance
- Repository validation run #96 passed after the retention migration/test commits.
- Cloudflare deployment is **manual-only**.
- The Cloudflare workflow expects:
  - `CLOUDFLARE_ACCOUNT_ID`
  - `CLOUDFLARE_WORKER_DEPLOY_TOKEN`
- A fail-closed sentinel, `cloudflare/update-edge/SOURCE_SYNC_REQUIRED.md`, blocks deployment of stale Worker source. It must only be removed in the same commit that synchronizes the exact reviewed live Worker source.

## Work reported complete in the Cloudflare/local-source session

These items were completed and tested in the session that has local preview.4 source and Cloudflare MCP access, but the final source still needs to be synchronized into PR #3:

- WinUI preview builds successfully.
- UI checks passed across all ten pages.
- Collapsed sidebar and managed Client view checks passed.
- Go dependency upgrade passed the regression suite.
- Signed-manifest tests passed.
- Cloudflare staging Worker was updated.
- Obsolete temporary upload routes were removed.
- Query-string redaction was enabled.
- Private report authorization was preserved.
- Both staging update feeds still returned no release after deployment.
- Eight local security test groups passed.
- Installer work was changed from unsafe process-name shutdown toward an authenticated handoff.
- First-start health acknowledgement / rollback gating was added locally.
- Automatic installer execution remains disabled.
- No trusted Windows code-signing certificate was found on the development PC.
- The engine regression suite now passes after fixes for Web Protection shutdown behavior and Download Guard cleanup.
- The Cloudflare diagnostic-upload 502 was traced to parsing a successful empty Supabase response as JSON; the local Worker/client fix and regression test pass in the Cloudflare-enabled session.

## Deliberate release holds

Do **not** publish a production release, change the production update feed, or make installer execution unattended until the relevant gates below are complete. The GitHub source repository is already private, so any runtime/update path that depended on anonymous GitHub URLs must be treated as broken until migrated to Cloudflare.

### Cloudflare source drift

The source currently under `cloudflare/update-edge/` in PR #3 is older than the live staging Worker. It must not be deployed. The sentinel blocks it.

The Cloudflare-enabled session must export/copy the exact deployed Worker source and configuration into this branch, preserving:

- signed R2 manifest/update flow
- private `/reports/*` routes
- authorization checks
- query-string redaction
- removal of temporary upload routes
- existing staging bucket bindings
- current trusted key ID / public-key behavior

Then run the Worker test suite and only then remove `SOURCE_SYNC_REQUIRED.md`.

### Private-repository runtime dependency gate

The repository is now private. Preview.4 must not depend at runtime on anonymous `raw.githubusercontent.com`, GitHub Release download URLs, or GitHub API URLs for update delivery. Repository validation now rejects those URLs in active source once synchronized. Legacy GitHub feed files remain only as an explicitly manual compatibility path.

### Windows source drift

As of the latest GitHub inspection, the branch still does not contain a Go `go.mod`, WinUI `.csproj`, or XAML application source. The local preview.4 source therefore has **not** yet been synchronized despite the repository now being private.

The complete preview.4 WinUI/Go source is still local to the other session. Sync it into this branch before merge so GitHub contains the code that produced the tested build.

The synchronized source must include the tested:

- Go dependency upgrade
- signed-manifest client validation
- installer handoff
- first-start health acknowledgement
- rollback request path
- startup/service migration logic
- Client/Admin UI restrictions

### Cloudflare credentials

The broad account-wide Cloudflare token still needs replacement. The replacement should use separate least-privilege credentials:

1. Worker deploy token scoped to the Quantum Guard account/Worker.
2. R2 release-publisher credentials limited to the distribution bucket.

After both replacements are verified in staging, revoke the old broad token. Never place Cloudflare credentials in the Windows/Android client.

### MFA

Owner must enable MFA/passkeys on:

- GitHub
- Supabase
- Cloudflare

Keep recovery material offline.

### Windows trusted signing

Production Authenticode remains blocked until a trusted code-signing certificate or signing service is available.

Do not commit a PFX, private key, certificate password, or signing-service secret.

Production signing order:

1. Build release payload.
2. Sign first-party binaries.
3. Verify publisher, signature and timestamp.
4. Build installer from signed payload.
5. Sign and verify installer.
6. Compute SHA-256 from final signed installer.
7. Create/sign Cloudflare release manifest.
8. Upload package to private R2.
9. Publish manifest last.

### Windows acceptance QA

Before enabling automatic installation, perform a real Windows test matrix for:

- fresh install
- preview-to-preview upgrade
- previous-version retention
- successful first-start health acknowledgement
- failed-first-start rollback
- power loss / interrupted install
- app/engine shutdown handoff
- startup/service path migration
- uninstall
- 100%, 125%, 150%, 175% DPI
- Admin and Client roles
- Cloudflare update check/download
- SHA-256 and manifest-signature failure cases
- Authenticode failure case once trusted signing exists

## Supabase advisor interpretation

Current advisor warnings are now limited to the intentional authenticated SECURITY DEFINER surface and leaked-password protection. They should not be mass-fixed blindly.

- Policy helper SECURITY DEFINER functions such as `account_is_active`, `is_org_admin`, `is_org_member`, `is_org_owner`, `owns_device`, `can_administer_user`, and `can_assign_device_policy` are referenced by RLS policies and require authenticated execution for those policies to work.
- RPC functions exposed intentionally to authenticated clients still require their internal authorization checks.
- Service-only functions such as `finalize_account_status_auth_sync`, `delete_expired_pairing_codes`, `handle_new_auth_user`, and `rls_auto_enable` are not granted to authenticated users.
- `report_archives` now has an explicit authenticated deny-all RLS policy, so the former RLS-with-no-policy advisor item is cleared while RPC/service-role access remains unchanged.
- Leaked-password protection is lower priority while Google OAuth is the primary sign-in path; do not weaken Google/Supabase auth to remove the warning.

## Rule for the next session

Before changing release infrastructure, read this file, PR #3, and the live deployed state. Prefer synchronizing already-tested local/Cloudflare changes over reimplementing them independently.


## Cross-session action list

The Cloudflare/local-source session has a dedicated checklist at:

`docs/OTHER_SESSION_TODO.md`

Use that file rather than reconstructing the remaining steps from chat history.
