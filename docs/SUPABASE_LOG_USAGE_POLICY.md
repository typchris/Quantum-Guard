# Supabase Log Query Usage Policy

Quantum Guard must not use Supabase platform log queries as an application runtime feature.

## Why

Supabase Logs Query usage measures log data scanned when logs are read through Studio, APIs, CLI tools, agents, or other log-query interfaces. Repeated broad scans can consume substantially more quota than the amount of log data actually ingested.

Quantum Guard already has application-level data sources for runtime state and support:

- devices and heartbeat/status fields
- device_events
- device_commands
- policies and device_policy_assignments
- device app inventory
- admin audit records
- private diagnostic report archives

These are the supported runtime sources. Supabase platform logs are for targeted development and incident investigation only.

## Development rules

1. Do not poll Supabase platform logs from Windows, Android, iOS, web, Workers, Edge Functions, scheduled jobs, or monitoring agents.
2. Do not use Logs Explorer data as a device online/offline or health signal.
3. Do not implement dashboards that repeatedly query edge_logs, postgres_logs, auth_logs, function_logs, realtime_logs, or other Supabase platform log sources.
4. When platform logs are required for debugging, query one relevant source only.
5. Use the narrowest useful time range, normally 15 minutes to 1 hour.
6. Avoid repeated 24-hour scans and avoid automated refresh unless actively investigating an incident.
7. Prefer SQL/RPC inspection of Quantum Guard application tables for routine QA.
8. Keep production Postgres logging conservative. Do not disable warning/error logging merely to reduce usage.

## Feature impact

This policy does not disable any Quantum Guard feature. It only limits how developers inspect Supabase's internal service logs.

Diagnostics sent by a user remain separate from Supabase platform log queries and may continue to use the private diagnostic archive architecture.

## Existing usage

Logs Query usage already accumulated in a billing cycle cannot be reduced by this policy. The purpose is to make future Logs Query growth minimal. Usage resets according to the Supabase billing cycle.
