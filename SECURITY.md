# Security Policy

## Supported builds

Quantum Guard is in active development. Security work currently targets the newest tested development preview and the live cloud control plane.

Production automatic updates remain disabled until the signed Cloudflare/R2 distribution path, trusted Windows Authenticode signing, installer health acknowledgement, and rollback behavior complete acceptance testing.

## Reporting a security issue

Do not post credentials, private keys, access tokens, user data, device identifiers, or sensitive reproduction details in a public location.

During private development, report vulnerabilities through a private repository security advisory when available, or contact the repository owner privately.

Include:

- affected Quantum Guard version
- affected platform
- reproduction steps
- expected vs actual authorization behavior
- whether the issue crosses users, devices, or organizations
- logs/screenshots only after removing secrets and personal data

## Secrets

Never commit or paste:

- Supabase service-role keys
- Cloudflare API tokens
- R2 access/secret keys
- GitHub personal access tokens
- Google OAuth client secrets
- Windows code-signing private keys, PFX files, or passwords
- release-signing private keys

The repository validation workflow rejects several common credential/private-key patterns and blocked signing/secret file types, but automated scanning is not a substitute for careful review.

## Release security

A Windows release is not production-ready until:

1. first-party binaries are signed by the trusted publisher identity
2. the installer is signed and RFC3161 timestamped
3. signatures and publisher identity verify
4. SHA-256 and size are computed from the final signed package
5. the release manifest is signed
6. the package is uploaded to private R2
7. the signed manifest is published last
8. a canary device verifies download, install, first-start health, and rollback behavior

See `UPDATES.md` and `docs/CURRENT_HANDOFF.md` for the current release gates.
