# Security

Report vulnerabilities privately to **contact@qguard.site**. Include the affected version, concise reproduction and impact. Do not post account sessions, passwords, signing keys, user data or sensitive logs in public issues.

Android 1.12.6 and Windows 1.12.4 are prepared for release review. Store approval and complete production payment activation remain pending. Windows executables remain unsigned.

An obsolete Android QA signing identity was exposed in historical development files. It is retired: never use it to sign or trust future builds. The current main Android upload identity and current Test-app update identity are different. Keep production upload keys private; public certificates may be shared.

Repository heads and tags were cleaned on 7 October 2026. Do not merge or push a pre-cleanup clone: create a fresh clone or rebase only reviewed, clean changes. GitHub pull-request references, caches and previously downloaded copies may retain old history. Rewriting history cannot invalidate an exposed signing key.

## Publication checks

- GitHub secret scanning, push protection and dependency alerts are enabled.
- The publication guard rejects private-key files, encoded keystores, provider secrets, account tokens, personal email addresses and developer home-directory paths in tracked files. Public client identifiers and Supabase publishable/anonymous keys are not privileged secrets; server authorization must enforce access.
- Separately scan actual release-archive contents and verify SHA-256. A clean source tree does not establish that a compiled binary is safe.
- Keep keys, sessions, private backups, machine SDK configuration, caches and real device reports out of release assets.

These checks are not a penetration test or a guarantee of store approval. The private incident record retains the rollback copy and details needed for GitHub cache cleanup.

