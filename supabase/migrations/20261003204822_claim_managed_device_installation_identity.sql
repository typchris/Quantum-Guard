-- Applied live as 20261003204822_claim_managed_device_installation_identity

create unique index if not exists devices_platform_installation_unique
  on public.devices(platform, installation_id)
  where installation_id is not null and btrim(installation_id) <> '';

create or replace function public.claim_device_installation(
  p_device_id uuid,
  p_installation_id text
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  d public.devices;
  v_install text := nullif(btrim(coalesce(p_installation_id,'')),'');
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if not public.account_is_active() then raise exception 'account is not active'; end if;
  if v_install is null or length(v_install) not between 8 and 128 then
    raise exception 'invalid installation id';
  end if;

  select * into d
  from public.devices
  where id=p_device_id
  for update;

  if d.id is null then raise exception 'device not found'; end if;
  if d.assigned_user_id is distinct from auth.uid() then
    raise exception 'assigned device user required';
  end if;

  if d.installation_id is not null and btrim(d.installation_id)<>'' then
    if d.installation_id is distinct from v_install then
      raise exception 'device installation identity mismatch';
    end if;
    return false;
  end if;

  if exists(
    select 1
    from public.devices other
    where other.id<>p_device_id
      and other.platform=d.platform
      and other.installation_id=v_install
  ) then
    raise exception 'installation identity already belongs to another device';
  end if;

  update public.devices
  set installation_id=v_install,updated_at=now()
  where id=p_device_id;

  return true;
end;
$function$;

revoke all on function public.claim_device_installation(uuid,text) from public;
revoke all on function public.claim_device_installation(uuid,text) from anon;
grant execute on function public.claim_device_installation(uuid,text) to authenticated;
