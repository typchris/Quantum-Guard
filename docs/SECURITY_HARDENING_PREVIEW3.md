# Quantum Guard preview.4 release hardening status

This checklist tracks the September 30 security review follow-up and the October 1 preview.4 hardening work. It separates changes that are already live from changes that require an account owner, Cloudflare deployment access, application source, or a trusted code-signing identity.

## Completed live

- Supabase migration `quantum_guard_account_status_atomic_multi_org` makes account status database writes transactional across profile state, every authorized organization, device command fan-out and one audit row per organization.
- Partial multi-organization authority is rejected. Target owners remain protected; target administrators require an owner.
- `admin-account-control` Edge Function version 7 is JWT-protected and delegates database authorization/state changes to the transactional RPC.
- Supabase Auth ban/unban remains a separate external operation. Its result is finalized through the service-role-only `finalize_account_status_auth_sync` RPC so all related audit rows are updated together.
- `@supabase/supabase-js` is pinned to `2.117.2` and the Edge Runtime type import is pinned to `2.5.0`.
- Rollback-only regression coverage passed for two-org command/audit fan-out and foreign-org rejection.

## Cloudflare release migration status

The Cloudflare-enabled session has already updated the live staging Worker and verified the private report routes and no-release update endpoints. The source currently stored under `cloudflare/update-edge/` in this branch is older than that live deployment. `SOURCE_SYNC_REQUIRED.md` and the manual-only workflow intentionally block deployment until the exact reviewed live Worker source is synchronized back into GitHub.

## Owner/account actions required

### MFA

Enable MFA/passkeys separately on:

- GitHub account owning `typchris/Quantum-Guard`
- Supabase organization owner account
- Cloudflare Super Administrator account

Keep recovery codes offline. Do not mark this item complete until each provider visibly reports MFA enabled.

### Cloudflare token reduction

Retire the broad `Cloudflare Agent Token - 2026-09-30` after the replacement credentials are verified.

Use separate credentials by purpose:

1. **Worker deployment token**: account-owned API token, scoped to the Quantum Guard account and only the Worker being deployed, with `Editor` access. Add `Workers Routes Write` only if the deployment actually changes a custom domain/route. Do not grant R2 object access just to deploy an existing R2-bound Worker.
2. **R2 release-publisher credentials**: R2 account API token with **Object Read & Write** restricted to `quantum-guard-distribution-staging` (and later a separate production bucket). Use its S3 Access Key ID/Secret Access Key only in the protected GitHub release environment. It must not be embedded in Quantum Guard clients.
3. Give both credentials an expiration/rotation schedule. Ninety days is a practical initial CI lifetime; rotate sooner after any suspected exposure.

Do not reuse the human/agent token for CI.

## Source/dependency blocker

The Cloudflare/local-source session reports that the Go dependency upgrade passed its regression suite and preview.4 builds successfully. The complete preview.4 WinUI/Go source still needs to be synchronized into this branch so GitHub contains the exact code that produced the tested build. The live Supabase account-control migration, regression test, and Edge Function source are mirrored under `supabase/` on this hardening branch.

## Windows signing and installer

`installer/` contains NSIS packaging, rollback metadata and SHA-256/RFC3161 Authenticode hooks. Production still requires a trusted publisher certificate (or another Microsoft-supported trusted signing identity). No private signing key or PFX belongs in the repository.

The local preview.4 work reports installer handoff and first-start health/rollback gating are implemented, but those source changes still need to be synchronized into this branch and exercised through real Windows upgrade/rollback QA. Automatic installation remains disabled until that QA passes and a trusted Windows signing identity is configured.
