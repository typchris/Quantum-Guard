# QGuard: GitHub audit and store readiness

Reviewed 7 October 2026. This records the inspected repository, compiled release files and current official store guidance. It is not a penetration test, export certification or store approval. Owner dashboards were not audited for completed store submissions in this task.

## GitHub security work

- Inspected the public `typchris/Quantum-Guard` repository, 20 branches, two tags, 318 unique historical file blobs, public issue/PR discussion, existing release binaries and available Actions artifacts. Encoded Android archives were inspected separately; the ordinary text scan alone did not find the encoded QA key.
- Found an obsolete encoded Android QA signing keystore. With explicit owner approval, saved a private rollback bundle, rewrote all 20 heads and two tags and verified the new remote references. Removed obsolete Android preview workflows from reachable history. Retired that signing identity for future builds. Current Test-app and production upload certificates are different from the exposed identity.
- Backed up the complete-history Actions artifact privately, removed it and verified it was no longer listed. Old QA APKs already downloaded cannot be recalled or made untrustworthy merely by rewriting Git history.
- GitHub secret scanning and push protection were already enabled with zero open alerts. Enabled dependency alerts. Additional non-provider secret-pattern scanning remains disabled after the configuration attempt. No CodeQL analysis exists. The main branch has no required-review protection; adding protection requires accommodating the existing automatic feed publisher rather than silently breaking updates.
- Added a publication guard, credential exclusions and private vulnerability contact `contact@qguard.site`. Added weekly dependency checks for GitHub Actions. GitHub's own scanning is useful but did not report the encoded key.
- Found a developer PDB path inside the old Windows UI DLL. Rebuilt the release UI with debug symbols disabled and verified that path was absent. Persisted the release setting in canonical Windows source. Preserved the earlier delivered Windows files locally.
- Found the previous personal Gmail links in the old Android source ZIP's website copy. Created a separate sanitized 1.12.6 source copy using the published website contact files. The original source archive remains local for rollback and is not a upload candidate.
- Actual new APK/AAB/Windows ZIP contents were scanned for recognized server secrets, private keys, non-anonymous JWTs, personal email addresses, local user paths and restricted filenames. CRC, APK signatures, version identity and Windows file hashes were checked. No findings remained in the checked upload files. This finite scan cannot establish that all application vulnerabilities are absent.

GitHub may retain old data through PR references/cached commit views, and external clones may retain it. [GitHub's sensitive-data-removal guidance](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository) explains why support-assisted purge and clean collaborator clones are separate steps. A request was prepared and owner-authorized for submission. Final submission status is recorded separately. Never push the pre-cleanup clone back to GitHub.

## Files prepared for GitHub release review

Android: 1.12.6, version code 112006, main package `com.quantumguard.android`, API target 36. Signed Play AAB and signed standalone release APK use the existing RSA-4096 upload identity. The functional UPDATE APK uses the existing Test-app identity and package suffix `.uipreview`; it must not be submitted to Play. The new build identity retains the previous policy implementation. New full physical-device tests were not performed for this metadata/package refresh.

Windows: 1.12.4 x64 complete folder ZIP. Functional production build, supplied Firefly logo, no demonstration mode. The rebuilt UI removes the developer PDB path; protection-engine behavior is unchanged. Release publish and 16 plan/expiry checks passed. Executables remain unsigned. A ZIP is not a Microsoft Store installer.

These are uploaded as drafts. The owner's prior instruction prohibits deploying the live billing build to customers until production readiness and provider verification are complete. No live payment gate or automatic update feed was activated by this task. The legacy single-EXE updater must not install just the UI executable from this multi-file Windows package.

## Google Play: remaining work

| Item | Status / next action |
| --- | --- |
| Bundle, version and API target | Signed 1.12.6 AAB ready for an internal track. Code 112006 replaces the already-used 112005; if 112006 has now been used in Console, increment again. Target API 36 meets the current phone-app target requirement. [Google target requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en-EN). |
| Signing and OAuth | Owner accepts Play App Signing terms and completes account verification. Register Google's final app-signing certificate for Android Google sign-in; the upload certificate may differ. Test the Play-installed build. |
| Sensitive API declarations | Complete Accessibility, VPN and special-use foreground-service declarations; provide actual disclosure/consent/permission/enforcement videos. QGuard is not a disability Accessibility tool. Review combined parental/enterprise monitoring classification and accurate marketing. [Accessibility guidance](https://support.google.com/googleplay/android-developer/answer/10964491), [sensitive permissions](https://support.google.com/googleplay/android-developer/answer/16558241). |
| Listing / App content | Complete Data safety, privacy and deletion URLs, content rating, intended audience, reviewer access instructions, screenshots and honest feature limitations. Public privacy: https://www.qguard.site/privacy. Deletion: https://www.qguard.site/#account-deletion. |
| Account deletion | Assign a real operator and prove deletion requests are fulfilled using the existing runbook. Request receipts alone are not completed deletion. Verify support/form delivery to contact@qguard.site. |
| Paid upgrades | Play products/Family offers, server purchase verification, restoration and renewal/cancellation/expiry lifecycle tests remain unfinished. Play purchases are disabled. A Free launch could defer paid purchases, provided listing/UI clearly say upgrades are unavailable and no external paid checkout is introduced. |
| Device QA / testing track | Test Samsung and supported older phones, reboot/background enforcement, consent revocation, app/domain blocking and quarantine restoration. New personal accounts created after 13 Nov 2023 need at least 12 opted-in closed testers continuously for 14 days before applying for production access. Check actual account type/date. [Google testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en-en). |
| Owner declarations / review | Owner completes export-law and signing agreements and submits for review; the app's use of standard cryptography does not constitute export authorization. Deobfuscation is disabled, so there is currently no mapping file to upload. |

## Microsoft Store: remaining work

| Item | Status / next action |
| --- | --- |
| Distribution package | Current ZIP is not eligible as the Store installer. Choose a complete offline EXE/MSI with silent install, uninstall and migration, or an MSIX compatible with the app's protection engine and capabilities. Existing installer plans are not proof of a finished release installer. |
| Trusted signing | For EXE/MSI submission, sign the installer and every included PE file with a certificate chaining to a Microsoft Trusted Root Program CA. Current executables are unsigned. MSIX submitted through the Store is signed by Microsoft after certification; do not conflate these routes. [Microsoft package requirements](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msi/app-package-requirements). |
| Proxy / shutdown reliability | Verify and complete crash, shutdown and watchdog restoration of QGuard-owned Windows and browser proxy settings while preserving another app's proxy changes. Source still sets a fixed 15-minute deadline on established HTTPS CONNECT tunnels. Remove that forced lifetime and test long sessions before launch. This task did not change the engine. |
| Cloud identity recovery | Canonical engine does not call the newer `recover_my_device_context_v2` RPC described in the separate hardening branch. Integrate and test server-authorized recovery for stale cached identity, invalid session and repeated enrollment; preserve pairing and reject cross-account takeover. |
| Clean-system / update QA | Complete install, upgrade, rollback, uninstall, startup, normal exit, reboot, Admin/Client and physical Windows↔Android enforcement tests. Design signed, complete multi-file updating; the older feed expects a single EXE. Run Windows App Certification Kit and malware checks. [Microsoft certification](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msi/app-certification-process). |
| Partner Center / listing | Verify developer account and app identity, reserve name, prepare screenshots, category/rating, reviewer access, support, privacy and product details. No completed Partner Center submission was verified here. |
| Payments | Windows can use secure third-party commerce for this non-game product, subject to the Store policy. Paddle's remaining live approval, notification gateway, signed event delivery and real payment/lifecycle checks must pass before enabling purchases. The current production purchase gate remains off. [Microsoft commerce policy](https://learn.microsoft.com/windows/apps/publish/store-policies). |

The immediate launch priority is Windows network/recovery reliability and Store packaging, plus Android Play declarations, actual review video, real-device QA and Play purchase handling if paid upgrades are included at launch.
