create or replace function public.get_my_device_context(p_device_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $function$
declare
  d public.devices;
  p public.profiles;
  r text;
  primary_admin boolean := false;
  org_name text;
  policy_id uuid;
  policy_version bigint;
  policy_settings jsonb;
  effective_status text;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  select * into d from public.devices where id=p_device_id;
  if d.id is null then raise exception 'device not found'; end if;
  r := public.device_effective_role(p_device_id);
  if r is null then raise exception 'not authorized for device'; end if;
  select * into p from public.profiles where id=auth.uid();
  select is_primary_admin into primary_admin
  from public.device_user_assignments
  where device_id=p_device_id and user_id=auth.uid();
  select name into org_name from public.organizations where id=d.organization_id;
  select pol.id,pol.version,pol.settings
    into policy_id,policy_version,policy_settings
  from public.device_policy_assignments a
  join public.policies pol on pol.id=a.policy_id
  where a.device_id=p_device_id;

  effective_status :=
    case
      when d.control_status in ('disabled','revoked') then 'restricted'
      when d.last_seen_at is null or d.last_seen_at < now()-interval '15 minutes' then 'offline'
      else d.device_status
    end;

  return jsonb_build_object(
    'user_id',auth.uid(),
    'account_status',coalesce(p.account_status,'active'),
    'profile_settings',coalesce(p.profile_settings,'{}'::jsonb),
    'device_id',d.id,
    'device_name',d.device_name,
    'platform',d.platform,
    'agent_version',d.agent_version,
    'os_version',d.os_version,
    'device_status',effective_status,
    'last_seen_at',d.last_seen_at,
    'organization_id',d.organization_id,
    'organization_name',org_name,
    'device_role',r,
    'can_administer',public.can_administer_device(p_device_id),
    'is_primary_admin',coalesce(primary_admin,false),
    'control_status',d.control_status,
    'capabilities',coalesce(d.capabilities,'{}'::jsonb),
    'policy_id',policy_id,
    'policy_version',policy_version,
    'policy_settings',coalesce(policy_settings,'{}'::jsonb)
  );
end;
$function$;