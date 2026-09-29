# Security Policy

## Supported builds

Quantum Guard is currently in active development. The newest public prerelease receives priority for security fixes.

## Reporting a vulnerability

Please do not publish credentials, tokens, private user data, database secrets, or a working exploit in a public GitHub issue.

For a security report, include:

* Quantum Guard version
* Windows version
* affected feature
* clear reproduction steps
* expected behavior
* observed behavior
* screenshots or logs with personal information removed

If a private reporting channel is not yet listed on this repository, open a public issue containing only a short request for a private security contact. Do not include exploit details in that issue.

## Secrets

Quantum Guard clients must not contain:

* Supabase service role keys
* Supabase secret keys
* Google OAuth client secrets
* plaintext administrator passwords
* plaintext application unlock passwords

Client applications may contain a Supabase publishable key when Row Level Security is correctly configured.

## Cloud authorization

Authorization must be enforced by database Row Level Security and server side functions. Hiding an administrator button in the user interface is not considered a security boundary.
