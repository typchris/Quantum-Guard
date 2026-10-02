# Cloudflare credential split for Quantum Guard

The goal is to remove the current all-accounts/all-zones Cloudflare agent token from release automation.

## Credential A: Worker deploy

Create an **account-owned API token** for CI/CD. Scope it only to the Quantum Guard account and, once the Worker exists, only the update Worker with **Editor** access. `wrangler deploy` of an existing Worker needs Editor. Routes/custom-domain changes additionally need `Workers Routes Write` on the affected zone, so omit that permission unless the workflow manages routes.

GitHub environment secret names:

- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_WORKER_DEPLOY_TOKEN`

## Credential B: R2 release publishing

Create an R2 **Account API token** with `Object Read & Write` restricted to the single distribution bucket. Use the resulting S3-compatible credentials:

- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`

The token does not need archive-bucket access. Diagnostic archives should use a separate credential/path if server-side tooling ever needs direct S3 access.

## Release signing key

The RSA release-signing private key is separate from Cloudflare credentials. The Worker only needs the public key. Store the private key only in a protected release environment or dedicated signing system. Windows preview.3 pins staging key ID `qg-staging-2026-09`; do not rotate that key without shipping a client that trusts the replacement.

## Rotation

After the new Worker and R2 credentials succeed in staging:

1. remove the old broad token from GitHub/agents,
2. revoke `Cloudflare Agent Token - 2026-09-30`,
3. verify update checks and a test download still work,
4. record owner, scope, creation date and next rotation date without recording secret values.
