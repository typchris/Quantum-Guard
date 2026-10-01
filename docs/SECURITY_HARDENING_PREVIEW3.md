# Quantum Guard preview.3 release hardening status

This checklist tracks the September 30 security review follow-up. It separates changes that are already live from changes that require an account owner, Cloudflare deployment access, application source, or a trusted code-signing identity.

## Completed live

- Supabase migration `quantum_guard_account_status_atomic_multi_org` makes account status database writes transactional across profile state, every authorized organization, device command fan-out and one audit row per organization.
- Partial multi-organization authority is rejected. Target owners remain protected; target administrators require an owner.
- `admin-account-control` Edge Function version 4 is JWT-protected and delegates database authorization/state changes to the transactional RPC.
- Supabase Auth ban/unban remains a separate external operation and the audit rows record its synchronization result.
- `@supabase/supabase-js` is pinned to `2.117.2` and the Edge Runtime type import is pinned to `2.4.5`.
- Rollback-only regression coverage passed for two-org command/audit fan-out and foreign-org rejection.

## Cloudflare release migration prepared

`cloudflare/update-edge-v2` implements the exact signed-manifest envelope enforced by Windows 1.11.0-preview.3: RSA-SHA256 / PKCS#1 v1.5 over the raw base64-decoded payload JSON, key ID `qg-staging-2026-09`, schema 1, private R2 storage and `/downloads/<signed-id>` delivery.

It intentionally does **not** overwrite the currently deployed `quantum-guard-downloads-staging` Worker because that Worker also owns the audited private `/reports/*` archive routes and its deployed source is not available through this repository connection. Merge or route the update paths only after the current report Worker source is retrieved through the Cloudflare account.

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

The preview.3 package proves `QuantumGuard.Engine.exe` was built with `golang.org/x/sys v0.10.0`; `go-winio v0.6.2` is already current. The current GitHub repository does not contain preview.3's Go `go.mod` or WinUI application source, so a safe `x/sys` upgrade cannot be rebuilt or regression-tested here. Commit/upload the preview.3 application source before enabling automatic installation.

## Windows signing and installer

`installer/` contains NSIS packaging, rollback metadata and SHA-256/RFC3161 Authenticode hooks. Production still requires a trusted publisher certificate (or another Microsoft-supported trusted signing identity). No private signing key or PFX belongs in the repository.

Automatic installation stays disabled until the application source adds installer handoff, installed-service/startup migration, first-start health acknowledgement and rollback invocation, followed by real Windows QA.
