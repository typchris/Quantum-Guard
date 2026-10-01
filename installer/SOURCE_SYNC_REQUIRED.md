# Installer source synchronization required

The installer/application integration in this Git branch is older than the local Quantum Guard 1.11.0-preview.4 work.

The Cloudflare/local-source session reports that preview.4 now uses an authenticated update handoff and first-start health/rollback gating instead of relying on process-name shutdown. Those exact changes must be synchronized into this branch before a release installer is built from GitHub source.

Remove this file only in the same reviewed commit that synchronizes the tested preview.4 installer and application handoff source.

Production installer creation must remain blocked while this file exists.
