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

The preview.3 source is not present in the public GitHub repository. Before enabling unattended installation, update the WinUI/Go source so it can: launch the signed installer after download verification, hand off cleanly, migrate the startup/service path to the installed version, acknowledge first-start health, and request rollback on failure. Do not enable automatic execution until those changes pass live Windows QA.
