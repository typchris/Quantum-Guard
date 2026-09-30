# Quantum Guard Cloudflare update edge

This Worker gives Quantum Guard a stable Cloudflare endpoint for release metadata while keeping the existing GitHub release download security model unchanged.

## Why Workers

Quantum Guard is a native Windows application, so the executable itself is not deployed to Cloudflare Workers. Supabase remains the application control plane.

This Worker is intentionally narrow:

- serves the verified update manifests
- validates the manifest shape before returning it
- keeps executable downloads on the existing official GitHub Releases URL
- adds short edge caching and Cloudflare observability
- does not store Supabase secrets
- does not proxy or rewrite the executable download

R2 is not required for this first step. Moving the executable to R2 later would require a coordinated Quantum Guard client update because the current updater accepts only the official GitHub release download path.

## Endpoints

- `GET /health`
- `GET /updates/latest.json`
- `GET /updates/latest-stable.json`

The Worker reads manifests from:

- `https://raw.githubusercontent.com/typchris/Quantum-Guard/main/releases/latest.json`
- `https://raw.githubusercontent.com/typchris/Quantum-Guard/main/releases/latest-stable.json`

## Local setup

Use a supported Node.js release, then:

```powershell
cd cloudflare/update-edge
npm install
npx wrangler --version
npm run check
npm run dev
```

Cloudflare recommends installing Wrangler locally per project. This folder pins Wrangler 4.143.0 so local and CI behavior are reproducible.

## Deploy

Authenticate to the intended Cloudflare account:

```powershell
cd cloudflare/update-edge
npx wrangler login
npm run deploy
```

Wrangler will deploy the Worker as `quantum-guard-update-edge` and print the `workers.dev` URL.

After deployment, verify:

```powershell
curl https://YOUR-WORKER.workers.dev/health
curl https://YOUR-WORKER.workers.dev/updates/latest.json
```

Only after those checks pass should the private Quantum Guard application source be updated to read its update manifest from the Worker URL.

## Security boundary

The Worker treats GitHub as the release authority and rejects manifests that do not match the expected Quantum Guard format, Windows x64 platform, SHA-256 shape, size limit, official GitHub release URL prefix, and release page prefix.

It does not alter `download_url`, so current clients still download the executable directly from the official GitHub release.

## Later option: R2

R2 becomes useful if you want Cloudflare to host release binaries instead of GitHub. That should be a separate migration:

1. add the R2 bucket and Worker binding
2. publish signed/verified release binaries to R2
3. update the desktop client's trusted download-host rules
4. test rollback and checksum verification
5. switch manifests only after the new client is distributed

Do not point existing clients at an R2 binary URL before step 3 is shipped.


## Automatic deployment from GitHub

The repository includes `.github/workflows/deploy-cloudflare-update-edge.yml`.

Before merging the Cloudflare Worker into `main`, add these GitHub Actions repository secrets:

- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_API_TOKEN`

Create the API token in Cloudflare with only the permissions needed to deploy this Worker, and scope it to the intended Cloudflare account. Do not commit either value to the repository.

After the secrets exist, a push to `main` that changes `cloudflare/update-edge/**` automatically validates and deploys the Worker. You can also run the workflow manually from GitHub Actions.
