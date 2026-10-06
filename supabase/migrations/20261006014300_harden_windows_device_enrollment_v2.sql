create or replace function public.enroll_device_v2(
  p_organization_id uuid,
  p_device_name text,
  p_platform text,
  p_agent_version text default null,
  p_hostname text default null,
  p_os_version text default null,
  p_installation_id text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  member_role text;
  default_device_role text;
  v_device uuid;
  v_count bigint;
  v_install text := nullif(btrim(coalesce(p_installation_id, '')), '');
  v_name text := coalesce(nullif(btrim(coalesce(p_device_name, '')), ''), 'Managed Device');
  v_hostname text := nullif(btrim(coalesce(p_hostname, '')), '');
  v_existing_org uuid;
  v_existing_user uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;
  if not public.account_is_active() then
    raise exception 'account is not active';
  end if;
  if p_organization_id is null then
    raise exception 'organization required';
  end if;
  if p_platform not in ('windows', 'android', 'ios', 'ipados') then
    raise exception 'unsupported platform';
  end if;
  if p_platform = 'windows' and v_install is null then
    raise exception 'installation id required for windows';
  end if;
  if v_install is not null and length(v_install) not between 8 and 128 then
    raise exception 'invalid installation id';
  end if;
  if length(v_name) > 200 then
    raise exception 'device name too long';
  end if;
  if v_hostname is not null and length(v_hostname) > 255 then
    raise exception 'hostname too long';
  end if;
  if p_agent_version is not null and length(p_agent_version) > 100 then
    raise exception 'agent version too long';
  end if;
  if p_os_version is not null and length(p_os_version) > 255 then
    raise exception 'os version too long';
  end if;

  select role into member_role
  from public.organization_members
  where organization_id = p_organization_id
    and user_id = auth.uid();

  if member_role is null then
    raise exception 'organization membership required';
  end if;

  default_device_role :=
    case
      when member_role = 'owner' then 'owner'
      when member_role = 'admin' then 'admin'
      else 'client'
    end;

  if v_install is not null then
    perform pg_advisory_xact_lock(
      hashtextextended('qguard-device:' || p_platform || ':' || v_install, 0)
    );

    select id, organization_id, assigned_user_id
      into v_device, v_existing_org, v_existing_user
    from public.devices
    where platform = p_platform
      and installation_id = v_install
    for update;

    if v_device is not null then
      if v_existing_org is distinct from p_organization_id then
        raise exception 'installation identity belongs to another organization';
      end if;
      if v_existing_user is distinct from auth.uid() then
        raise exception 'installation identity belongs to another user';
      end if;
    end if;
  end if;

  if v_device is null and v_install is not null and v_hostname is not null then
    select (array_agg(id order by updated_at desc))[1], count(*)
      into v_device, v_count
    from public.devices
    where organization_id = p_organization_id
      and assigned_user_id = auth.uid()
      and platform = p_platform
      and nullif(btrim(coalesce(installation_id, '')), '') is null
      and lower(coalesce(hostname, '')) = lower(v_hostname);
    if v_count <> 1 then v_device := null; end if;
  end if;

  if v_device is null and v_install is not null then
    select (array_agg(id order by updated_at desc))[1], count(*)
      into v_device, v_count
    from public.devices
    where organization_id = p_organization_id
      and assigned_user_id = auth.uid()
      and platform = p_platform
      and nullif(btrim(coalesce(installation_id, '')), '') is null
      and lower(device_name) = lower(v_name);
    if v_count <> 1 then v_device := null; end if;
  end if;

  if v_device is null and v_install is null then
    if v_hostname is not null then
      select (array_agg(id order by updated_at desc))[1], count(*)
        into v_device, v_count
      from public.devices
      where organization_id = p_organization_id
        and assigned_user_id = auth.uid()
        and platform = p_platform
        and lower(coalesce(hostname, '')) = lower(v_hostname);
      if v_count <> 1 then v_device := null; end if;
    end if;

    if v_device is null then
      select (array_agg(id order by updated_at desc))[1], count(*)
        into v_device, v_count
      from public.devices
      where organization_id = p_organization_id
        and assigned_user_id = auth.uid()
        and platform = p_platform
        and lower(device_name) = lower(v_name);
      if v_count <> 1 then v_device := null; end if;
    end if;
  end if;

  if v_device is null then
    insert into public.devices(
      organization_id, assigned_user_id, device_name, platform, agent_version,
      device_status, control_status, last_seen_at, updated_at, hostname,
      os_version, installation_id
    )
    values (
      p_organization_id, auth.uid(), v_name, p_platform, p_agent_version,
      'online', 'active', now(), now(), v_hostname,
      nullif(btrim(coalesce(p_os_version, '')), ''), v_install
    )
    returning id into v_device;
  else
    update public.devices
    set device_name = v_name,
        agent_version = coalesce(p_agent_version, agent_version),
        hostname = coalesce(v_hostname, hostname),
        os_version = coalesce(nullif(btrim(coalesce(p_os_version, '')), ''), os_version),
        installation_id = coalesce(v_install, installation_id),
        device_status = case
          when control_status in ('disabled', 'revoked') then 'restricted'
          else 'online'
        end,
        last_seen_at = now(),
        updated_at = now()
    where id = v_device;
  end if;

  insert into public.device_user_assignments(
    device_id, user_id, role, is_primary_admin, updated_at
  )
  values (
    v_device, auth.uid(), default_device_role,
    (default_device_role = 'owner'), now()
  )
  on conflict (device_id, user_id) do nothing;

  return v_device;
end;
$function$;

revoke all on function public.enroll_device_v2(uuid, text, text, text, text, text, text) from public;
grant execute on function public.enroll_device_v2(uuid, text, text, text, text, text, text) to authenticated;
grant execute on function public.enroll_device_v2(uuid, text, text, text, text, text, text) to service_role;

comment on function public.enroll_device_v2(uuid, text, text, text, text, text, text)
is 'Atomically enrolls or recovers a device using a stable installation identity. Windows requires an installation id. Existing per-device roles are preserved.';

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

  select * into d from public.devices where id = p_device_id;
  if d.id is null then raise exception 'device not found'; end if;

  r := public.device_effective_role(p_device_id);
  if r is null then raise exception 'not authorized for device'; end if;

  select * into p from public.profiles where id = auth.uid();

  select is_primary_admin into primary_admin
  from public.device_user_assignments
  where device_id = p_device_id and user_id = auth.uid();

  select name into org_name from public.organizations where id = d.organization_id;

  select pol.id, pol.version, pol.settings
    into policy_id, policy_version, policy_settings
  from public.device_policy_assignments a
  join public.policies pol on pol.id = a.policy_id
  where a.device_id = p_device_id;

  effective_status :=
    case
      when d.control_status in ('disabled', 'revoked') then 'restricted'
      when d.last_seen_at is null or d.last_seen_at < now() - interval '15 minutes' then 'offline'
      else d.device_status
    end;

  return jsonb_build_object(
    'user_id', auth.uid(),
    'account_status', coalesce(p.account_status, 'active'),
    'profile_settings', coalesce(p.profile_settings, '{}'::jsonb),
    'device_id', d.id,
    'device_name', d.device_name,
    'platform', d.platform,
    'installation_id', d.installation_id,
    'agent_version', d.agent_version,
    'os_version', d.os_version,
    'device_status', effective_status,
    'last_seen_at', d.last_seen_at,
    'organization_id', d.organization_id,
    'organization_name', org_name,
    'device_role', r,
    'local_device_role', coalesce((
      select a.role
      from public.device_user_assignments a
      where a.device_id = p_device_id
        and a.user_id = auth.uid()
    ), r),
    'can_administer', public.can_administer_device(p_device_id),
    'is_primary_admin', coalesce(primary_admin, false),
    'control_status', d.control_status,
    'capabilities', coalesce(d.capabilities, '{}'::jsonb),
    'policy_id', policy_id,
    'policy_version', policy_version,
    'subscription', qguard_private.plan_for_org(d.organization_id),
    'policy_settings', coalesce(policy_settings, '{}'::jsonb)
  );
end;
$function$;
