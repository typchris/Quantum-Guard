# Legacy client migration after the GitHub repository became private

The source repository `typchris/Quantum-Guard` is private.

Older Quantum Guard clients that were shipped with an updater restricted to anonymous GitHub raw/release URLs cannot retrieve manifests or release assets from this private repository.

## Security rule

Do **not** solve this by embedding a GitHub personal access token, fine-grained token, OAuth secret, or repository credential in Quantum Guard.

A desktop client must never contain a credential that grants access to the private source repository.

## One-time migration

Any installed build that does not already trust the Cloudflare update endpoint needs a one-time manual upgrade to a release that contains the Cloudflare signed-manifest/R2 updater.

The migration package should:

1. preserve existing Quantum Guard configuration and local protection state,
2. install the Cloudflare-capable client/engine,
3. verify its trusted Authenticode publisher when production signing is available,
4. verify first-start health before replacing the previous startup path,
5. retain the previous version for rollback,
6. confirm a Cloudflare staging update check succeeds without GitHub credentials.

After that migration, future updates may use the signed Cloudflare manifest and private R2 package path.

## Compatibility endpoint limitation

A Cloudflare Worker can serve a legacy-shaped JSON document, but that alone does not help an older client if the client hard-codes or allow-lists GitHub release download URLs.

Do not weaken an old client's host validation to make migration easier. Use a one-time installer/manual upgrade instead.

## Release hold

Do not publish a migration installer to broad users until:

- the preview.4 source is synchronized to GitHub,
- Cloudflare Worker source is synchronized and tested,
- the installer handoff/health/rollback implementation is synchronized,
- trusted code signing is configured for production,
- Windows upgrade/rollback QA passes.

## Test cases

Before declaring migration complete, test at least:

- old GitHub-updater build with the repository private,
- expected graceful update failure/no protection shutdown,
- manual install over the old build,
- local configuration preservation,
- first-start health success,
- forced first-start failure and rollback,
- Cloudflare update check after migration,
- no GitHub token/credential present in the installed files or process environment.
