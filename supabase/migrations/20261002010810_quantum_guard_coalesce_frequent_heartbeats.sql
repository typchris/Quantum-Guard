create or replace function public.device_heartbeat(
  p_device_id uuid,
  p_agent_version text,
  p_hostname text default null,
  p_current_user text default null,
  p_os_version text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  d public.devices;
  p public.profiles;
  r text;
  primary_admin boolean := false;
  org_name text;
  desired_device_status text;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select * into d
  from public.devices
  where id = p_device_id;

  if d.id is null then
    raise exception 'device not found';
  end if;

  r := public.device_effective_role(p_device_id);
  if r is null then
    raise exception 'not authorized for device';
  end if;

  select is_primary_admin into primary_admin
  from public.device_user_assignments
  where device_id = p_device_id
    and user_id = auth.uid();

  desired_device_status :=
    case when d.control_status in ('disabled','revoked')
      then 'restricted'
      else 'online'
    end;

  -- Preview.4 still calls heartbeat more frequently than the production target.
  -- Coalesce routine writes to roughly one every 8 minutes while still applying
  -- real metadata/control-status changes immediately. This reduces WAL, Realtime
  -- churn and log volume until the client source moves to ~10-minute heartbeats.
  if d.last_seen_at is null
     or d.last_seen_at < now() - interval '8 minutes'
     or d.device_status is distinct from desired_device_status
     or d.agent_version is distinct from p_agent_version
     or (p_hostname is not null and d.hostname is distinct from p_hostname)
     or (p_current_user is not null and d.current_user_name is distinct from p_current_user)
     or (p_os_version is not null and d.os_version is distinct from p_os_version)
  then
    update public.devices
    set
      device_status = desired_device_status,
      agent_version = p_agent_version,
      last_seen_at = now(),
      updated_at = now(),
      hostname = coalesce(p_hostname, hostname),
      current_user_name = coalesce(p_current_user, current_user_name),
      os_version = coalesce(p_os_version, os_version)
    where id = p_device_id
    returning * into d;
  end if;

  update public.profiles
  set
    last_active_at = now(),
    updated_at = now()
  where id = auth.uid()
    and (
      last_active_at is null
      or last_active_at < now() - interval '8 minutes'
    );

  select * into p
  from public.profiles
  where id = auth.uid();

  select name into org_name
  from public.organizations
  where id = d.organization_id;

  return jsonb_build_object(
    'user_id', auth.uid(),
    'account_status', coalesce(p.account_status, 'active'),
    'profile_settings', coalesce(p.profile_settings, '{}'::jsonb),
    'device_id', d.id,
    'organization_id', d.organization_id,
    'organization_name', org_name,
    'device_role', r,
    'is_primary_admin', coalesce(primary_admin, false),
    'control_status', d.control_status,
    'device_status', d.device_status,
    'last_seen_at', d.last_seen_at
  );
end;
$function$;
