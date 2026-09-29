# Publishing Quantum Guard updates

## One time setup

The public repository is `typchris/Quantum-Guard`. Put these files from `release-tools` into matching paths on its `main` branch:

* `.github/workflows/publish-update-manifest.yml`
* `scripts/publish_update_manifest.py`

The workflow needs permission to write repository contents. If branch protection prevents its commit, use a reviewed manual manifest change or an approved PR based publication process. Do not disable branch protection just to make the workflow pass.

Application source can stay private. The public feed and release executable are sufficient for clients. This package includes the source for your own development.

## Each new version

1. Set `appVersion` in `src/update_core.go` to a higher semantic version, such as `1.8.1`.
2. Run `build.ps1` on Windows. Test startup and the update flow before distributing.
3. If using a signing certificate, sign the final executable before publishing. The manifest must describe the final signed bytes. Certificate signing and publisher certificate enforcement are not implemented in this preview.
4. Draft a GitHub release tagged `v1.8.1`. Attach the newly built file with the exact name `QuantumGuard.exe` and write release notes. Mark previews as prereleases.
5. Publish the release. The workflow downloads and verifies the asset, then updates `releases/latest.json`. A stable release also updates `releases/latest-stable.json`.
6. Check the workflow completed successfully. If the executable was attached after publication, run the workflow manually with the tag or edit the release to trigger it again.

Keep version numbers increasing. Existing clients compare semantic versions and never install a release whose version is equal to or older than their own. The workflow also refuses to replace the feed with an older release. Existing releases should not be reused for different builds.

Once the feed changes, connected clients receive the update on their next startup check or hourly check. Offline computers receive it after reconnecting and checking. Users can check immediately through Settings > Updates.

## Initial rollout

Old v1.6 and v1.7 installations without updater support need the new executable once through your normal distribution method. Publishing a release cannot add an updater to an already installed executable that has no update code.

This package identifies itself as 1.8.0 and will ignore the current 1.7.0 manifest. Use 1.8.1 or higher for the first update test after installing this package.

## Feed fields

The workflow computes `sha256` and `size` from the actual downloadable Windows x64 executable. It copies the version, channel and notes from the published release. The client accepts only `https://github.com/typchris/Quantum-Guard/releases/download/<matching-tag>/QuantumGuard.exe` and approved GitHub HTTPS download redirects.

Publishing a source commit does not build or publish a release in this release-only repository. Publish the executable release to notify users.

## Recovery

The old executable remains as `previous.exe` inside the corresponding `.qg-update-*` folder beside the app. Automatic rollback covers replacement failure and failure to reach the initial startup health signal. It does not promise recovery from every later application failure, disk failure, antivirus lock or Windows shutdown.

To recover manually, exit Quantum Guard and its watchdog normally, restore `previous.exe` to the original application path as `QuantumGuard.exe`, then launch it. Preserve the original icon and user configuration. Keep recent backups until the new version has been verified.

GitHub API reference used for release asset metadata:
https://docs.github.com/en/rest/releases/assets
