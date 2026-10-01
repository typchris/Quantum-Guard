# Publishing Quantum Guard updates

Quantum Guard 1.11 uses a multi-file WinUI 3 + Go engine package. The old single-EXE GitHub updater is now a **legacy compatibility path**, not the target production release system.

The target update architecture is:

```text
Quantum Guard client
        |
        v
Cloudflare Worker
        |
        +-- signed update manifest
        +-- private R2 package delivery
        |
        v
client verifies manifest + version + platform + size + SHA-256
        |
        v
Windows verifies trusted Authenticode publisher
        |
        v
versioned installer / first-start health / rollback
```

Supabase remains the account, organization, device, policy, command and audit control plane. Cloudflare handles release distribution and large/private archive delivery.

## Current release hold

No production 1.11 release should be published yet.

The staging Worker has been updated and tested from the Cloudflare-enabled development session, but the exact live Worker source still needs to be synchronized into this Git branch. The file:

`cloudflare/update-edge/SOURCE_SYNC_REQUIRED.md`

intentionally blocks deployment from GitHub until that synchronization is complete.

Automatic installer execution also remains disabled until trusted Windows signing and live Windows upgrade/rollback QA are complete.

## Cloudflare release publication order

For a production Windows release:

1. Build the exact WinUI + Go payload from the committed release source.
2. Run the full automated test suite.
3. Authenticode-sign the first-party binaries with the trusted production publisher identity.
4. Verify signatures, publisher identity and RFC3161 timestamps.
5. Build the versioned Windows installer from the signed payload.
6. Authenticode-sign and verify the final installer.
7. Compute SHA-256 and exact byte size from the **final signed installer**.
8. Build the release manifest for the intended channel/platform.
9. Sign the manifest using the release-signing key.
10. Upload the installer/package to the private R2 distribution bucket.
11. Verify the staged package can be downloaded only through the intended Worker path.
12. Re-download the staged package and verify size, SHA-256 and Authenticode again.
13. Publish the signed manifest **last**.
14. Verify one preview device checks, downloads, installs, acknowledges first-start health and remains stable.
15. Expand rollout only after the canary passes.

Never reuse a version number for different bytes.

## Client verification requirements

Before an installer may execute, the Windows client must reject an update when any of these checks fail:

- manifest signature
- trusted key ID
- manifest expiry/freshness rules
- semantic version / downgrade protection
- channel
- platform/architecture
- trusted Worker/download origin
- expected package path/filename rules
- declared size
- SHA-256
- trusted Authenticode signature/publisher
- installer handoff authorization

A download that fails verification must remain non-executable.

## Rollback

The versioned installer retains the previous version and does not permanently select the new startup path until the new version reaches the first-start health acknowledgement.

The Windows acceptance suite must cover:

- successful health acknowledgement
- missing/late acknowledgement
- immediate process failure
- invalid/corrupt package
- interrupted install
- startup/service migration failure
- rollback to the previous version

Do not treat a successful file copy as a successful update.

## Cloudflare credentials

Release automation must not use a broad human/agent token.

Use separate credentials for:

- Worker deployment: `CLOUDFLARE_WORKER_DEPLOY_TOKEN`
- R2 publishing: bucket-limited R2 S3 credentials

Keep release-signing keys separate from Cloudflare credentials.

No Cloudflare token, R2 secret, release-signing private key, PFX or signing password belongs in the desktop/mobile client or repository.

## GitHub source repository

The application source repository is now private.

That means anonymous `raw.githubusercontent.com`, GitHub Release asset, and GitHub API URLs from this repository are no longer valid public runtime/update dependencies. Preview.4 and all future clients must use Cloudflare for public update/package delivery.

The legacy GitHub feed remains in the private repository only as an internal compatibility/reference path. Existing external clients that depended on anonymous GitHub URLs will not be able to use it after the repository visibility change.

## Legacy GitHub feed

`.github/workflows/publish-update-manifest.yml` now requires a manual dispatch and explicit confirmation.

It exists only for controlled compatibility with older single-EXE clients that still understand:

- `releases/latest.json`
- `releases/latest-stable.json`
- GitHub release asset `QuantumGuard.exe`

Publishing or editing a GitHub release no longer automatically changes this legacy feed on the hardening branch.

Do not use the legacy workflow for the 1.11 multi-file installer.

## Staging rule

The staging update feeds should continue to return no release until a deliberately prepared, signed preview package is ready for end-to-end installer testing.

Production and staging credentials, R2 buckets, manifests and release channels should remain distinct.
