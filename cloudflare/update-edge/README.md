# Quantum Guard Cloudflare update edge

> **DEPLOYMENT HOLD:** the Worker source currently in this folder is older than the live Quantum Guard staging Worker. Do not deploy it. `SOURCE_SYNC_REQUIRED.md` intentionally blocks the GitHub deploy workflow until the exact reviewed live Worker source is synchronized back into this folder.

## Current architecture

The live staging Worker is the Cloudflare distribution edge for Quantum Guard. The Cloudflare-enabled development session reports that it currently preserves:

- signed update-manifest delivery
- private R2 package delivery
- private diagnostic/report routes
- authorization checks for report access
- query-string redaction
- removal of obsolete temporary upload routes
- separate staging release behavior
- no published staging release yet
- diagnostic archive completion handling that accepts a successful empty Supabase response without misclassifying the upload as failed

Supabase remains the identity, organization, device, policy, command and audit control plane.

## Source synchronization procedure

Before any GitHub-driven deployment:

1. Export/copy the exact source and configuration of the currently deployed staging Worker from the Cloudflare-enabled session.
2. Replace the older Worker source/configuration in this folder.
3. Confirm all required R2 bindings, environment variables, compatibility settings and routes are represented without committing secret values.
4. Preserve private `/reports/*` behavior and signed R2 update/download behavior, including the regression-tested empty-success-response handling for report completion.
5. Run the full Worker test suite locally.
6. Run a dry-run deployment.
7. Verify staging endpoints against the already-deployed Worker.
8. Remove `SOURCE_SYNC_REQUIRED.md` **in the same reviewed commit** that contains the synchronized source.
9. Only then manually dispatch the GitHub deploy workflow with `confirm_source_synced=yes`.

If the sentinel still exists, deployment must fail.

## GitHub deployment credentials

The deployment workflow uses a protected `cloudflare-staging` environment and expects:

- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_WORKER_DEPLOY_TOKEN`

The deploy token must be a least-privilege replacement for the broad account-wide token. It must not be embedded in application source or client binaries.

R2 package publishing uses separate bucket-limited credentials. Do not reuse the Worker deployment token for release object publishing.

## Release safety

The Worker is not the release authority by itself. A Windows update is only eligible after the client validates the signed manifest and package metadata, and after the final installer passes SHA-256 and trusted Authenticode verification.

Publish release packages first and the signed manifest last.

See:

- `../../UPDATES.md`
- `../../docs/CURRENT_HANDOFF.md`
- `../../docs/CLOUDFLARE_RELEASE_CREDENTIALS.md`

## What the older source in this folder represents

The current checked-in `src/index.js` predates the completed staging migration and still describes the former GitHub-proxy update edge. It remains only so the branch history shows the migration path. It must be replaced, not redeployed.
