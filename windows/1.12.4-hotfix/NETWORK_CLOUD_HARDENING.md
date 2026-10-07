# Quantum Guard Windows 1.12.4 Network and Cloud Hardening

## Release goal

Fix the Windows failure mode where browser traffic becomes unavailable or slow after Web Protection is disabled, Quantum Guard exits, the protection engine crashes, or Windows shuts down. Also permanently replace the account-specific cloud recovery script with server-authorized in-app recovery.

This document is based on inspection of the supplied Quantum Guard Windows 1.12.3 binaries and the live Supabase control plane.

## Confirmed network finding

QuantumGuard.Engine.exe owns a local HTTP/HTTPS proxy on:

`127.0.0.1:53679`

The binary contains and uses these routines:

- `applyLocalWebFilter`
- `stopLocalWebFilter`
- `writeWindowsUserProxy`
- `writeWebProxyPolicy`
- `closeWebConnections`
- `serveWebProxy`
- `flushWindowsDNS`

The browser error page text `Destination unavailable` is also embedded in the engine. This means that screenshot is produced by Quantum Guard's proxy path, not by qguard.site itself.

A normal message-loop exit reaches `stopLocalWebFilter`, but crash/forced termination and Windows end-session paths are not guaranteed to run the same cleanup. The watchdog also needs a stale-proxy recovery path before restarting the engine.

Binary inspection also confirms two proxy timing behaviors that must be corrected:

- HTTPS CONNECT uses a 15 second `net.DialTimeout`.
- Once a CONNECT tunnel succeeds, both sides receive one fixed absolute deadline 15 minutes in the future.

The first can make failed destinations appear to hang. The second can terminate otherwise healthy long-lived browser connections and force reconnects.

## Required network fixes

### 1. Crash-safe ownership state

Persist the previous Windows proxy and browser-policy state before Quantum Guard changes it.

The ownership record must include:

- schema version
- created timestamp
- Quantum Guard proxy endpoint
- previous WinINet ProxyEnable
- previous WinINet ProxyServer
- previous AutoConfigURL if present
- previous Edge proxy policy values if changed
- previous Chrome proxy policy values if changed
- an `owned_by_quantum_guard` marker

Write this state atomically using temp file + rename.

Never overwrite a newer user/VPN/corporate proxy setting during cleanup. Restore only when the currently configured value still equals the Quantum Guard-owned proxy/policy.

### 2. Startup orphan repair

Before enabling any local proxy:

1. Read the ownership record.
2. Test whether `127.0.0.1:53679` has a healthy Quantum Guard listener.
3. If Windows or browser policies still point to the QGuard proxy while no healthy owner exists, restore the previous settings.
4. Notify WinINet that settings changed.
5. Flush Windows DNS only after an actual repair.
6. Log the repair.

This must run before the normal local proxy starts.

### 3. Normal exit cleanup

Call proxy teardown before destroying the main window, not only after the Win32 message loop ends.

Expected order:

1. stop accepting new proxy requests
2. close existing proxied connections
3. restore Edge/Chrome policy owned by QGuard
4. restore the previous Windows user proxy owned by QGuard
5. notify WinINet
6. flush DNS
7. signal the watchdog exit event
8. destroy the UI and finish process shutdown

Cleanup must be idempotent.

### 4. Windows shutdown/session-end cleanup

Handle `WM_QUERYENDSESSION` and `WM_ENDSESSION`.

When Windows is ending the user session, synchronously execute the bounded proxy cleanup before returning. Do not perform a long cloud sync in this path.

### 5. Watchdog recovery

When the watchdog detects that the protected engine/window disappeared unexpectedly:

1. repair stale QGuard-owned proxy state
2. wait until the QGuard proxy port is no longer owned by the old process
3. restart Quantum Guard
4. let the restarted engine run startup orphan repair before reapplying protection

The watchdog must never leave browsers pointed at a dead proxy.

### 6. Web Protection OFF behavior

When Web Protection is OFF, browser requests must not be blocked, rewritten, or delayed by category/ad rules.

If the product still requires the proxy while Quantum Guard is running, pass-through mode must be equivalent to direct browsing and use bounded dial/TLS/response timeouts.

Preferred behavior when no other enabled feature requires interception: restore the native proxy and remove QGuard browser proxy policy while Web Protection is OFF.

### 7. Proxy transport hardening

For normal HTTP forwarding:

- never recursively proxy QGuard's outbound proxy connection
- strip hop-by-hop proxy headers
- use a context-aware bounded connect timeout
- use bounded TLS handshake timeout
- use bounded response-header timeout
- reuse healthy idle connections
- close unhealthy connections
- preserve IPv4/IPv6 fallback

For CONNECT:

- validate host:port
- replace the current 15 second raw dial with a context-aware bounded dial
- return a standards-compatible proxy error when connection fails
- do not impose the current fixed 15 minute lifetime on a healthy established tunnel
- if idle protection is required, use an idle-aware timeout that is refreshed by traffic
- close both sides of the tunnel cleanly
- avoid leaving goroutines/connections alive after one side closes

Never intercept the local Google OAuth callback at `127.0.0.1:43117`.

### 8. Health check and automatic rollback

After applying the QGuard proxy:

1. verify the local listener
2. make a short HTTPS health request through it
3. if the request fails, restore the user's previous proxy state immediately
4. leave Web Protection in an error/degraded state instead of breaking general browsing

## Permanent cloud sign-in recovery

The account-specific PowerShell recovery must not be the production solution.

A new authenticated Supabase RPC is now live:

`recover_my_device_context_v2(p_installation_id, p_platform, p_hostname, p_device_name)`

It returns authoritative `get_my_device_context` data for the authenticated user, prefers a stable installation ID, and limits hostname/device-name fallback to one unambiguous legacy device whose installation ID is still empty.

After PKCE returns a valid Supabase session:

1. keep the new session in memory
2. obtain or create a stable Windows installation ID
3. call `recover_my_device_context_v2`
4. require that Supabase returns an authorized device context for the newly authenticated user
5. if authorized, repair stale local `user_id`, email, display name, organization/device context
6. preserve the existing enrolled device ID and organization
7. if the recovered legacy device has no installation ID, call `enroll_device_v2` with the recovered organization and the stable local installation ID so the existing row is claimed in place
8. persist the new DPAPI-protected access/refresh session atomically
9. start heartbeat, policy, command, realtime/polling workers
10. refresh Cloud & Devices UI

Do not reject a successful Google login solely because the cached local user ID differs. The server-authorized device context is authoritative.

If Supabase says the installation belongs to a different user or organization, do not auto-transfer it. Preserve local pairing metadata and show a reconnect/authorization error.

On startup:

- restore DPAPI session
- refresh token if needed
- verify device context through `recover_my_device_context_v2` or `get_my_device_context`
- if the refresh token is invalid, clear only the encrypted auth session
- keep installation ID, device ID and organization identity for a safe re-login

## Stable Windows installation identity

Generate once and persist across upgrades/uninstalls where user data is retained.

Recommended format:

`w-<32 random hex bytes>`

Requirements:

- 8 to 128 characters
- cryptographically random
- never derived from MAC address, username, SID, hostname or other personal identifier
- stored in Quantum Guard local protected state
- reused by every later version
- submitted to the live `enroll_device_v2` RPC

The server-side v2 enrollment migration is already live and rejects cross-user/cross-organization installation takeover.

## Required regression tests

### Network

- Enable Web Protection, browse HTTPS and HTTP sites.
- Disable Web Protection and confirm direct browsing still works.
- Fully exit Quantum Guard and confirm no QGuard proxy remains.
- End the Windows user session and confirm no stale proxy on next login.
- Kill the engine process and confirm watchdog repairs stale proxy before restart.
- Simulate proxy listener failure and confirm automatic rollback.
- Test Edge and Chrome.
- Test an existing third-party/VPN proxy and confirm QGuard restores it exactly.
- Confirm QGuard does not erase proxy settings changed by another application after QGuard started.
- Test DNS, IPv4-only, IPv6-capable, slow TLS and failed upstream destinations.
- Keep a CONNECT-heavy browser session open longer than 15 minutes and confirm it is not forcibly terminated by Quantum Guard.
- Verify qguard.site and other ordinary HTTPS sites load normally.

### Cloud

- Existing enrolled Windows PC with correct cached account.
- Existing enrolled Windows PC with stale cached user ID.
- Expired access token with valid refresh token.
- Invalid refresh token followed by Google re-login.
- Legacy device with no installation ID.
- Repeated upgrade/restart does not create duplicate device rows.
- Different Google account cannot steal an existing installation.
- Android Google sign-in remains unchanged.

## Release gate

Do not publish 1.12.4 until the above network teardown tests pass on a real Windows PC and Supabase shows the existing Windows device row being reused with a stable installation ID.
