<p align="center">
  <img src="assets/qg-mark.svg" alt="Quantum Guard" width="720">
</p>

<p align="center">
  <strong>Focus. Protection. Control.</strong><br>
  Quantum Guard provides local protection and authorized connected-device management for Windows and Android.
</p>

<p align="center">
  <a href="https://github.com/typchris/Quantum-Guard/releases"><img alt="GitHub release" src="https://img.shields.io/github/v/release/typchris/Quantum-Guard?include_prereleases&style=flat-square"></a>
  <img alt="Platform" src="https://img.shields.io/badge/platform-Windows-2563EB?style=flat-square">
  <img alt="Status" src="https://img.shields.io/badge/status-development%20preview-7C3AED?style=flat-square">
</p>

## Quantum Guard

Prepared release-review builds: **Android 1.12.6** (Play bundle and installable APKs) and **Windows 1.12.4 x64** (complete app ZIP). They are uploaded as maintainer-only GitHub drafts while launch checks remain open. The builds are functional and use the supplied QG shield logo. Store approval and paid upgrades are not yet available; Windows binaries remain unsigned. See [store readiness](docs/STORE_READINESS.md) for the actual remaining work.

An obsolete QA signing identity was retired during a repository-history cleanup. Contributors must start from a fresh clone and must not merge the old history back. See [SECURITY.md](SECURITY.md). Keep private credentials, local configuration and real device/user data out of public files and release assets.

Quantum Guard is being developed as a central control platform for application restrictions, focus sessions, schedules, website protection, download controls, device enrollment, and administrator managed policies.

The project is currently in active development. The connected cloud control plane now includes device-specific roles, profile context, heartbeat, remote commands and account-control groundwork. The built-in updater is also implemented in the current development line. Public GitHub releases should still be treated as preview builds until the integrated Windows flow completes live desktop QA.

## Core capabilities

| Area | Current direction |
| --- | --- |
| Application control | Protect selected Windows applications and use allow or deny rules |
| Focus | Restrict distractions with configurable app policies and schedules |
| Web protection | Block selected sites, categories, advertising domains, and trackers |
| Download Guard | Restrict or quarantine selected download types |
| Scheduling | Apply app, focus, and after hours rules by time |
| Cloud control | Supabase backed identities, organizations, devices, policies, and commands |
| Device enrollment | Organization membership plus pairing code enrollment |
| Administration | Separate administrator and managed client experiences |
| Updates | Built-in verified GitHub release checks and background downloads in the current development line |

## Public preview

The current GitHub release is marked as a prerelease while Quantum Guard is still being tested.

Before using a preview build on an important computer:

1. Back up your Quantum Guard configuration.
2. Review the release notes.
3. Verify the SHA256 digest shown by GitHub for the executable.
4. Test the build on a non critical device first.

## Cloud architecture

Quantum Guard uses Supabase as its cloud control plane for:

* Google authenticated profiles
* Organizations and memberships
* Managed devices
* Role based access
* Device policies
* Pairing codes
* Remote commands
* Activity events
* Release metadata


## Administrator and client roles

Quantum Guard is designed so that identity and device authority are separate concepts.

An administrator account may manage devices and policies where authorized. A client device receives the policy assigned to it and must not gain administrator privileges simply because a user signs in.

The effective access design is based on:

```
Google identity
      ↓
Quantum Guard profile
      ↓
Organization membership
      ↓
Current device
      ↓
Device role and permissions
      ↓
Assigned policy
```

## Releases

Download preview builds from the official GitHub Releases page:

**https://github.com/typchris/Quantum-Guard/releases**

Do not download Quantum Guard executables from unofficial mirrors.

## Security

Security issues should not be posted publicly with sensitive reproduction details. See [SECURITY.md](SECURITY.md) for reporting guidance.

## Support and feedback

For bugs, use the repository issue templates so reports include the Windows version, Quantum Guard version, reproduction steps, and screenshots where useful.

## Development status

Quantum Guard is under active development. Features, data models, UI structure, and cloud behavior may change before a stable release.

Copyright © 2026 Quantum Guard.
