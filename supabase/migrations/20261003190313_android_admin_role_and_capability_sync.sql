-- Applied live as 20261003190313_android_admin_role_and_capability_sync

alter table public.devices
  add column if not exists capabilities jsonb not null default '{}'::jsonb;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.devices'::regclass
      and conname='devices_capabilities_size_check'
  ) then
    alter table public.devices
      add constraint devices_capabilities_size_check
      check (octet_length(capabilities::text) <= 65536);
  end if;
end $$;

create or replace function public.device_effective_role(p_device_id uuid)
returns text
language plpgsql
stable security definer
set search_path = public, pg_temp
as $function$
declare
  v_org uuid;
  v_assigned uuid;
  v_device_role text;
  v_org_role text;
begin
  if auth.uid() is null then return null; end if;

  select d.organization_id,d.assigned_user_id into v_org,v_assigned
  from public.devices d where d.id=p_device_id;

  if v_org is null then return null; end if;

  if not public.account_is_active() and v_assigned is distinct from auth.uid() then
    return null;
  end if;

  select a.role into v_device_role
  from public.device_user_assignments a
  where a.device_id=p_device_id and a.user_id=auth.uid();

  select m.role into v_org_role
  from public.organization_members m
  where m.organization_id=v_org and m.user_id=auth.uid()
    and m.role in ('owner','admin');

  if v_org_role='owner' or v_device_role='owner' then return 'owner'; end if;
  if v_org_role='admin' or v_device_role='admin' then return 'admin'; end if;
  if v_device_role='client' or v_assigned=auth.uid() then return 'client'; end if;
  return null;
end;
$function$;

create or replace function public.can_administer_device(p_device_id uuid)
returns boolean
language sql
stable security definer
set search_path = public, pg_temp
as $function$
  select public.account_is_active()
     and coalesce(public.device_effective_role(p_device_id) in ('owner','admin'),false);
$function$;

create or replace function public.get_my_device_context(p_device_id uuid)
returns jsonb
language plpgsql
stable security definer
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

  return jsonb_build_object(
    'user_id',auth.uid(),
    'account_status',coalesce(p.account_status,'active'),
    'profile_settings',coalesce(p.profile_settings,'{}'::jsonb),
    'device_id',d.id,
    'device_name',d.device_name,
    'platform',d.platform,
    'agent_version',d.agent_version,
    'os_version',d.os_version,
    'device_status',d.device_status,
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

create or replace function public.device_heartbeat_v2(
  p_device_id uuid,
  p_agent_version text,
  p_hostname text default null,
  p_current_user text default null,
  p_os_version text default null,
  p_capabilities jsonb default '{}'::jsonb
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
  safe_capabilities jsonb := coalesce(p_capabilities,'{}'::jsonb);
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if jsonb_typeof(safe_capabilities) <> 'object' then raise exception 'capabilities must be an object'; end if;
  if octet_length(safe_capabilities::text) > 65536 then raise exception 'capabilities too large'; end if;

  select * into d from public.devices where id=p_device_id;
  if d.id is null then raise exception 'device not found'; end if;
  if d.assigned_user_id is distinct from auth.uid() then raise exception 'assigned device user required'; end if;

  r := public.device_effective_role(p_device_id);
  if r is null then raise exception 'not authorized for device'; end if;

  select is_primary_admin into primary_admin
  from public.device_user_assignments
  where device_id=p_device_id and user_id=auth.uid();

  desired_device_status :=
    case when d.control_status in ('disabled','revoked') then 'restricted' else 'online' end;

  if d.last_seen_at is null
     or d.last_seen_at < now() - interval '8 minutes'
     or d.device_status is distinct from desired_device_status
     or d.agent_version is distinct from p_agent_version
     or (p_hostname is not null and d.hostname is distinct from p_hostname)
     or (p_current_user is not null and d.current_user_name is distinct from p_current_user)
     or (p_os_version is not null and d.os_version is distinct from p_os_version)
     or d.capabilities is distinct from safe_capabilities
  then
    update public.devices
    set device_status=desired_device_status,
        agent_version=p_agent_version,
        last_seen_at=now(),
        updated_at=now(),
        hostname=coalesce(p_hostname,hostname),
        current_user_name=coalesce(p_current_user,current_user_name),
        os_version=coalesce(p_os_version,os_version),
        capabilities=safe_capabilities
    where id=p_device_id
    returning * into d;
  end if;

  update public.profiles
  set last_active_at=now(),updated_at=now()
  where id=auth.uid()
    and (last_active_at is null or last_active_at < now()-interval '8 minutes');

  select * into p from public.profiles where id=auth.uid();
  select name into org_name from public.organizations where id=d.organization_id;

  return jsonb_build_object(
    'user_id',auth.uid(),
    'account_status',coalesce(p.account_status,'active'),
    'profile_settings',coalesce(p.profile_settings,'{}'::jsonb),
    'device_id',d.id,
    'organization_id',d.organization_id,
    'organization_name',org_name,
    'device_role',r,
    'can_administer',public.can_administer_device(p_device_id),
    'is_primary_admin',coalesce(primary_admin,false),
    'control_status',d.control_status,
    'device_status',d.device_status,
    'last_seen_at',d.last_seen_at,
    'capabilities',coalesce(d.capabilities,'{}'::jsonb)
  );
end;
$function$;

revoke all on function public.device_heartbeat_v2(uuid,text,text,text,text,jsonb) from public;
revoke all on function public.device_heartbeat_v2(uuid,text,text,text,text,jsonb) from anon;
grant execute on function public.device_heartbeat_v2(uuid,text,text,text,text,jsonb) to authenticated;
