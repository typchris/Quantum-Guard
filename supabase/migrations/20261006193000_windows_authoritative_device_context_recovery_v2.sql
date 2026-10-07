create or replace function public.recover_my_device_context_v2(
  p_installation_id text default null,
  p_platform text default 'windows',
  p_hostname text default null,
  p_device_name text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $function$
declare
  v_install text := nullif(btrim(coalesce(p_installation_id, '')), '');
  v_platform text := lower(nullif(btrim(coalesce(p_platform, '')), ''));
  v_hostname text := nullif(btrim(coalesce(p_hostname, '')), '');
  v_name text := nullif(btrim(coalesce(p_device_name, '')), '');
  v_device uuid;
  v_count bigint;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  if not public.account_is_active() then
    raise exception 'account is not active';
  end if;

  if v_platform is null or v_platform not in ('windows','android','ios','ipados') then
    raise exception 'unsupported platform';
  end if;

  if v_install is not null and length(v_install) not between 8 and 128 then
    raise exception 'invalid installation id';
  end if;

  if v_install is not null then
    select id
      into v_device
    from public.devices
    where assigned_user_id = auth.uid()
      and platform = v_platform
      and installation_id = v_install
    order by updated_at desc
    limit 1;

    if v_device is not null then
      return public.get_my_device_context(v_device);
    end if;
  end if;

  if v_hostname is not null then
    select (array_agg(id order by updated_at desc))[1], count(*)
      into v_device, v_count
    from public.devices
    where assigned_user_id = auth.uid()
      and platform = v_platform
      and nullif(btrim(coalesce(installation_id, '')), '') is null
      and lower(coalesce(hostname, '')) = lower(v_hostname);

    if v_count = 1 then
      return public.get_my_device_context(v_device);
    end if;
  end if;

  if v_name is not null then
    select (array_agg(id order by updated_at desc))[1], count(*)
      into v_device, v_count
    from public.devices
    where assigned_user_id = auth.uid()
      and platform = v_platform
      and nullif(btrim(coalesce(installation_id, '')), '') is null
      and lower(device_name) = lower(v_name);

    if v_count = 1 then
      return public.get_my_device_context(v_device);
    end if;
  end if;

  return null;
end;
$function$;

revoke all on function public.recover_my_device_context_v2(text, text, text, text) from public;
grant execute on function public.recover_my_device_context_v2(text, text, text, text) to authenticated;
grant execute on function public.recover_my_device_context_v2(text, text, text, text) to service_role;

comment on function public.recover_my_device_context_v2(text, text, text, text)
is 'Returns authoritative authenticated device context for a stable installation identity or one unambiguous legacy device without changing ownership.';
