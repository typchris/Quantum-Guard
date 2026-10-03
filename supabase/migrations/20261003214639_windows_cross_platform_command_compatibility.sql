create or replace function public.create_device_command(
  p_device_id uuid,
  p_command_type text,
  p_payload jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  d public.devices;
  cmd uuid;
  safe_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  effective_command text:=p_command_type;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if not public.account_is_active() then raise exception 'account is not active'; end if;
  if length(coalesce(p_command_type,'')) not between 1 and 100 then raise exception 'invalid command type'; end if;
  if octet_length(safe_payload::text)>262144 then raise exception 'command payload too large'; end if;

  select * into d from public.devices where id=p_device_id;
  if d.id is null or not public.can_administer_device(p_device_id) then
    raise exception 'device administrator required';
  end if;

  case p_command_type
    when 'start_focus' then
      perform public.patch_device_policy(p_device_id,'{"focus_mode":true}'::jsonb,'Device policy');
      if d.platform='windows' then effective_command:='refresh_policy'; end if;
    when 'stop_focus' then
      perform public.patch_device_policy(p_device_id,'{"focus_mode":false}'::jsonb,'Device policy');
      if d.platform='windows' then effective_command:='refresh_policy'; end if;
    when 'enable_web_protection' then
      perform public.patch_device_policy(p_device_id,'{"web_protection_enabled":true}'::jsonb,'Device policy');
      if d.platform='windows' then effective_command:='refresh_policy'; end if;
    when 'disable_web_protection' then
      perform public.patch_device_policy(p_device_id,'{"web_protection_enabled":false}'::jsonb,'Device policy');
      if d.platform='windows' then effective_command:='refresh_policy'; end if;
    when 'enable_download_guard' then
      perform public.patch_device_policy(p_device_id,'{"download_guard_enabled":true}'::jsonb,'Device policy');
      if d.platform='windows' then effective_command:='refresh_policy'; end if;
    when 'disable_download_guard' then
      perform public.patch_device_policy(p_device_id,'{"download_guard_enabled":false}'::jsonb,'Device policy');
      if d.platform='windows' then effective_command:='refresh_policy'; end if;
    when 'lock_all_apps' then
      perform public.patch_device_policy(
        p_device_id,
        '{"focus_mode":true,"focus_policy":"allow","focus_allowed":[]}'::jsonb,
        'Device policy'
      );
      if d.platform='windows' then effective_command:='lock_apps'; end if;
    when 'lock_device' then
      if d.platform='windows' then effective_command:='lock_apps'; end if;
    when 'sign_out_user' then
      if d.platform='windows' then effective_command:='signout'; end if;
    else
      null;
  end case;

  select c.id into cmd
  from public.device_commands c
  where c.device_id=p_device_id and c.created_by=auth.uid()
    and c.command_type=effective_command and c.payload=safe_payload
    and c.status='pending' and c.created_at>=now()-interval '10 seconds'
  order by c.created_at desc limit 1;

  if cmd is not null then return cmd; end if;

  insert into public.device_commands(
    organization_id,device_id,command_type,payload,status,created_by
  )
  values(
    d.organization_id,p_device_id,effective_command,safe_payload,'pending',auth.uid()
  )
  returning id into cmd;
  return cmd;
end;
$function$;