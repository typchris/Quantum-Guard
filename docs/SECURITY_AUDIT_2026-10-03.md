# Quantum Guard security audit — 2026-10-03

## Scope

This review covered the public GitHub repository, current branch tips, GitHub Actions workflows, Windows and Android client configuration, the Supabase Edge Function, live RLS/RPC exposure, and cross-organization authorization behavior.

## Critical finding: Android QA signing identity exposed

The repository publicly contained `android/preview7_qa_keystore.b64`. The Android QA source also contained the matching hardcoded store/key password. Because both the signing key material and password were public, the old QA Android signing identity must be treated as compromised.

Deleting the file from a branch tip is not a rotation. Git history and other public refs can preserve old content. Do not trust the old QA certificate for future builds.

Required rotation:

1. Generate a completely new QA signing keystore and a new random password.
2. Never reuse the exposed key or password.
3. Store the new material only as protected GitHub Actions secrets:
   * `QG_ANDROID_QA_KEYSTORE_B64`
   * `QG_ANDROID_QA_STORE_PASSWORD`
   * `QG_ANDROID_QA_KEY_PASSWORD`
   * `QG_ANDROID_QA_CERT_SHA256`
4. Rebuild Preview QA APKs with the new identity.
5. Treat APKs signed with the old QA certificate as untrusted after the migration window.
6. Optionally purge the old key from Git history after backups and coordination. History cleanup is destructive and is not a substitute for key rotation.

## Repository visibility and branch integrity

As of 2026-10-03, GitHub reports `typchris/Quantum-Guard` as public. Every branch returned by the branch API also reported `protected: false`.

If Quantum Guard is intended to be closed source, change the repository visibility to private in GitHub settings. Regardless of visibility, protect `main` and release/preview branches with pull request review and required status checks.

## Secret review

No committed value was found for:

* Supabase service role key
* Cloudflare API token
* GitHub personal access token
* Google OAuth client secret
* PostgreSQL password/connection URI
* PEM/OpenSSH/RSA private key
* Windows PFX/private signing key

The Supabase `sb_publishable_...` key and project URL are public client configuration by design. They are not backend administrator credentials. Security depends on RLS, RPC authorization, and keeping service-role credentials server-side.

## Supabase live verification

The live project showed:

* no anonymous EXECUTE permission on privileged SECURITY DEFINER RPCs
* no exposed public table without RLS in the reviewed schema
* no allow-all authenticated/anonymous RLS policy found
* `admin-account-control` Edge Function has JWT verification enabled
* service role is read from the Edge Function environment, not source

Cross-organization regression probes confirmed a foreign signed-in user was denied for:

* device administration
* device context
* remote command creation
* full policy update
* atomic policy patch
* app inventory read
* device control-status changes

Migration `20261003100849_security_definer_search_path_hardening` was applied live after rollback validation. It changes older SECURITY DEFINER functions from `search_path=public` to `search_path=public, pg_temp`.

## Remaining Supabase advisor warnings

Supabase still reports authenticated SECURITY DEFINER RPCs. This is expected for Quantum Guard's client RPC architecture, but every exposed privileged function must retain explicit authentication and tenant/device authorization checks. Do not mass-revoke these RPCs because Windows and Android clients use them.

Supabase also reports leaked-password protection disabled. Google OAuth is the primary flow today, but password protection should be enabled if password sign-in is offered.

## CI/CD review

Android build workflows use `contents: read` and do not expose deployment secrets to public pull requests. Cloudflare deployment is manual, uses a protected environment, and references secret names rather than literal values.

The repository secret scanner was strengthened in this hardening branch to reject encoded keystore files, JKS base64 material, hardcoded Gradle signing passwords, Supabase service-role literals, OAuth client-secret literals, private keys, GitHub PATs, Cloudflare token literals, and AWS secret literals.

For additional supply-chain hardening, pin third-party GitHub Actions to immutable commit SHAs.

## Update security

Current Windows Preview 6 validates update URL/source, version/tag consistency, file size, PE format, and SHA-256. Production automatic updating should remain gated until trusted Authenticode publisher verification and a signed release-manifest chain are enforced. A hash stored beside a release is integrity metadata, not an independent trust root if the same account/feed is compromised.

## Availability and free-tier abuse

Authenticated self-service creation paths are tenant-scoped and input-bounded, but there are not yet explicit per-user quotas for organization creation, device enrollment, or pairing-code creation. This is primarily an availability/cost-abuse concern rather than a cross-tenant authorization flaw. Add quotas/rate limits before broad public registration if abuse becomes possible.

## Manual owner actions still required

1. Decide whether the repository should remain public. If not, make it private.
2. Generate and configure a new QA Android signing identity using the four protected Actions secrets above.
3. Enable branch protection/rulesets for `main` and active release/preview branches.
4. Enable GitHub secret scanning and push protection when available for the repository/account.
5. Verify least-privilege Cloudflare credentials are active and revoke the old broad token after replacements are tested.
6. Keep production automatic updates disabled until trusted signing and release verification gates pass.
