# Quantum Guard Windows installer and Authenticode hooks

Quantum Guard 1.11 is a multi-file WinUI 3 + Go engine application. The legacy single-EXE replacement updater is not suitable for it. This installer project uses NSIS and installs payloads in versioned directories so one previous version can be retained for rollback.

## Production signing order

1. Build/publish the WinUI + Go payload.
2. Authenticode-sign the first-party binaries (`QuantumGuard.UI.exe`, `QuantumGuard.UI.dll`, `QuantumGuard.Engine.exe`) with the production publisher certificate.
3. Verify the signatures.
4. Build the NSIS installer from the signed payload.
5. Authenticode-sign and RFC3161 timestamp the final installer.
6. Verify the installer signature, compute SHA-256, then create the signed Cloudflare release manifest.
7. Upload the package + descriptor to private R2 and publish the signed manifest **last**.

`sign-artifacts.ps1` uses SHA-256 for both file digest and RFC3161 timestamp digest. A trusted production certificate is required for production distribution. A self-signed certificate is for QA only and must never be presented as a production signature.

## Build

Use NSIS 3.13 or a newer security-supported 3.x:

```powershell
.\build-installer.ps1 -PayloadDir C:\path\to\published\QuantumGuard -Version 1.11.0-preview.4
```

## Rollback

The installer records `CurrentVersion` and `PreviousVersion` under `HKLM\Software\QuantumGuard`, retains versioned payload directories, and installs an administrator-only rollback script. Before production, the application/engine must add a first-start health acknowledgement so automatic update orchestration can invoke rollback when startup fails.

## Still required in application source

The local preview.4 source session reports that authenticated installer handoff and first-start health/rollback gating have been implemented and tested locally. Those changes are not yet synchronized into this Git branch. Do not enable unattended installation until the exact preview.4 source is committed here and live Windows QA passes fresh install, upgrade, startup/service migration, health acknowledgement, failure rollback, interrupted install, and uninstall scenarios.


## Repository safety hold

The installer files in this branch are a release-hardening foundation. The local preview.4 session has newer installer/application integration work that must be synchronized before this branch is merged.

Do not use process-name termination as the final production handoff. The running Quantum Guard UI/engine should explicitly authorize and coordinate update shutdown so an unrelated process with the same name cannot be targeted.

Automatic update execution remains disabled until:

- trusted Authenticode signing is configured
- the exact preview.4 source is in GitHub
- the signed installer is validated on Windows
- the new version reports first-start health
- rollback is proven when that health check fails


## Path safety

The installer foundation now uses a fixed machine-wide install root under `Program Files\Quantum Guard`; the directory-selection page was removed.

Uninstall refuses recursive removal if either the active installer path or the HKLM `InstallRoot` value does not match the expected Quantum Guard directory. The rollback helper also validates the install root and semantic-version path components before resolving a previous payload.

Preserve these guards when synchronizing the newer preview.4 installer integration.
