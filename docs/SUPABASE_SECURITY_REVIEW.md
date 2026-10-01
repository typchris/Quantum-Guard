# Supabase security review checkpoint

**Project:** `goffrcpfelmgqbidaxhb`  
**Review date:** 2026-10-01

## Live hardening state

- Every public application table has RLS enabled.
- Anonymous table access is not granted.
- Account-active enforcement is implemented as **RESTRICTIVE** RLS policies on the organization/device/policy control-plane tables.
- Cross-organization command, event and policy-assignment boundaries have rollback-only regression coverage.
- `admin-account-control` is live as Edge Function **version 9**, ACTIVE, with JWT verification enabled.
- Account-wide status changes are authorized across every organization that the target belongs to.
- `update_my_profile_preferences` is the checked profile-roaming write path. It only permits active users to change display name, HTTPS avatar URL, and `profile_settings`; direct authenticated profile UPDATE remains unavailable.
- Profile status, device-command fan-out and one audit row per organization are committed through `apply_account_status_change`.
- Auth ban/unban synchronization is finalized through service-role-only `finalize_account_status_auth_sync`.
- `report_archives` has no direct authenticated table grant and now has an explicit deny-all authenticated RLS policy.
- Report archive RPC flow has a rollback-only regression proving direct table access is denied while checked RPC access works.
- Database constraints now bound common text and JSON inputs to reduce accidental or malicious Free-Tier storage exhaustion.
- Authenticated table grants that had no reachable RLS write path were revoked.
- Direct authenticated organization inserts are revoked; `create_organization` is the supported creation path and atomically creates the owner membership.

## Input bounds

Current database-level upper bounds include:

- profile display name: 200 characters
- profile email: 320 characters
- avatar URL: 4096 characters
- blocked reason: 500 characters
- profile settings JSON: 64 KiB
- organization name: 2-200 characters
- device name: 1-200 characters
- agent version: 100 characters
- hostname/current Windows user/OS version: 255 characters each
- policy name: 1-200 characters
- policy settings JSON: 1 MiB
- device command type: 100 characters
- command payload/result JSON: 256 KiB each
- device event type: 100 characters
- device event detail JSON: 64 KiB
- pairing code: exactly 10 uppercase hexadecimal characters
- admin audit action: 100 characters
- admin audit detail JSON: 64 KiB

These limits are intentionally generous for normal clients while preventing one request from storing arbitrarily large values.

## SECURITY DEFINER advisor warnings

The remaining Supabase advisor warning about authenticated users being able to execute SECURITY DEFINER functions should **not** be resolved by mass revocation. The count is currently 24 because the new checked profile-preference RPC is intentionally authenticated.

Several functions are RLS helpers and are intentionally referenced by policies:

- `account_is_active`
- `can_administer_user`
- `can_assign_device_policy`
- `is_org_admin`
- `is_org_member`
- `is_org_owner`
- `owns_device`

Other functions are intentionally authenticated RPCs used by the device/admin clients:

- `ack_device_command`
- `apply_account_status_change`
- `complete_report_archive`
- `create_device_command`
- `create_organization`
- `create_pairing_code`
- `device_effective_role`
- `device_heartbeat`
- `enroll_device`
- `get_my_device_context`
- `get_report_archive`
- `list_organization_members`
- `redeem_pairing_code`
- `reserve_report_archive`
- `set_device_control_status`
- `set_organization_member_role`

Service-only functions are not granted to authenticated users, including:

- `delete_expired_pairing_codes`
- `finalize_account_status_auth_sync`
- `handle_new_auth_user`
- `rls_auto_enable`

A future cleanup may move internal RLS helper functions to a non-exposed schema, but only together with policy rewrites and full regression testing. Do not revoke helper execution in-place because PostgreSQL RLS evaluation depends on it.

## Current regression suite

The pairing-code regression also verifies schema-qualified pgcrypto generation, ten-character uppercase hexadecimal format, minimum expiry clamping, and client denial.

Live rollback-only tests currently cover:

- two-organization account status fan-out
- account owner/admin/client/outsider authorization boundaries
- private report archive direct-access denial and checked RPC access
- accepted normal heartbeat plus rejection of oversized device metadata
- cross-organization command/event/policy-assignment rejection
- client device isolation
- suspended administrator denial
- inactive user own-device status visibility

## Remaining account-level warning

Leaked-password protection remains disabled. Google OAuth is the current primary sign-in path, so this is not a reason to weaken or replace the existing auth model. Revisit it when password authentication is intentionally offered or the Supabase plan/features change.

## Change rule

Any future RLS, role, function-grant or SECURITY DEFINER cleanup must be applied as a migration, mirrored to GitHub, and followed by the rollback-only authorization suite before release.


## Performance-lint cleanup

The three missing foreign-key indexes were added for:

- `policies.organization_id`
- `report_archives.device_id`
- `report_archives.uploaded_by`

The six RLS auth-initplan warnings were removed by evaluating `auth.uid()` through scalar subqueries in the affected policies. The performance advisor now reports only unused-index informational findings, which should not be acted on while the dataset is still small because many of those indexes support expected future access paths.

All five stored rollback-only regressions passed again after the grant/index/RLS changes.

- The live account-control HTTP boundary rejects oversized request bodies above 16 KiB and validates target UUID/status before calling the database RPC.
