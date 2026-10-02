create or replace function public.run_quantum_guard_retention_cleanup()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_pairing integer := 0;
  v_commands integer := 0;
  v_events integer := 0;
  v_policies integer := 0;
begin
  delete from public.device_pair_codes
  where
    expires_at < now() - interval '1 day'
    or (used_at is not null and used_at < now() - interval '1 day');
  get diagnostics v_pairing = row_count;

  delete from public.device_commands
  where status in ('completed', 'failed', 'expired')
    and coalesce(completed_at, received_at, created_at) < now() - interval '30 days';
  get diagnostics v_commands = row_count;

  delete from public.device_events
  where lower(coalesce(severity, '')) in ('debug', 'info', 'routine')
    and created_at < now() - interval '30 days';
  get diagnostics v_events = row_count;

  delete from public.policies p
  where p.updated_at < now() - interval '30 days'
    and not exists (
      select 1
      from public.device_policy_assignments a
      where a.policy_id = p.id
    )
    and exists (
      select 1
      from public.policies newer
      where newer.organization_id = p.organization_id
        and newer.name = p.name
        and (
          newer.version > p.version
          or (newer.version = p.version and newer.updated_at > p.updated_at)
          or (
            newer.version = p.version
            and newer.updated_at = p.updated_at
            and newer.id > p.id
          )
        )
    );
  get diagnostics v_policies = row_count;

  return jsonb_build_object(
    'pairing_codes_deleted', v_pairing,
    'device_commands_deleted', v_commands,
    'routine_events_deleted', v_events,
    'unassigned_policy_versions_deleted', v_policies,
    'completed_at', now()
  );
end;
$function$;

revoke all on function public.run_quantum_guard_retention_cleanup() from public;
revoke all on function public.run_quantum_guard_retention_cleanup() from anon;
revoke all on function public.run_quantum_guard_retention_cleanup() from authenticated;
grant execute on function public.run_quantum_guard_retention_cleanup() to service_role;

do $schedule$
declare
  existing_job bigint;
begin
  select jobid into existing_job
  from cron.job
  where jobname = 'quantum-guard-retention-cleanup'
  limit 1;

  if existing_job is not null then
    perform cron.unschedule(existing_job);
  end if;

  perform cron.schedule(
    'quantum-guard-retention-cleanup',
    '23 3 * * *',
    $$select public.run_quantum_guard_retention_cleanup();$$
  );
end;
$schedule$;
