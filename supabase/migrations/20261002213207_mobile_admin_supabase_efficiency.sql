create or replace function public.set_device_policy(p_device_id uuid,p_name text,p_settings jsonb)
returns uuid language plpgsql security definer set search_path to 'public','pg_temp'
as $function$
declare
  d public.devices;
  v_policy_id uuid;
  assignment_count bigint := 0;
  next_version bigint;
  safe_name text;
  current_settings jsonb;
  current_name text;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if not public.account_is_active() then raise exception 'account is not active'; end if;
  if not public.can_administer_device(p_device_id) then raise exception 'device administrator required'; end if;
  if octet_length(coalesce(p_settings,'{}'::jsonb)::text)>1048576 then raise exception 'policy too large'; end if;
  select * into d from public.devices where id=p_device_id;
  if d.id is null then raise exception 'device not found'; end if;
  safe_name:=left(coalesce(nullif(trim(p_name),''),d.platform||' policy'),200);

  select a.policy_id into v_policy_id
  from public.device_policy_assignments a
  where a.device_id=p_device_id
  for update;

  if v_policy_id is not null then
    select count(*) into assignment_count
    from public.device_policy_assignments a
    where a.policy_id=v_policy_id;
  end if;

  if v_policy_id is not null and assignment_count=1 then
    select p.settings,p.name into current_settings,current_name
    from public.policies p
    where p.id=v_policy_id and p.organization_id=d.organization_id
    for update;

    if current_settings is not distinct from coalesce(p_settings,'{}'::jsonb)
       and current_name is not distinct from safe_name then
      return v_policy_id;
    end if;

    update public.policies p
    set name=safe_name,version=p.version+1,settings=coalesce(p_settings,'{}'::jsonb),
        updated_by=auth.uid(),updated_at=now()
    where p.id=v_policy_id and p.organization_id=d.organization_id
    returning p.id into v_policy_id;
  else
    select coalesce(max(p.version),0)+1 into next_version
    from public.policies p where p.organization_id=d.organization_id and p.name=safe_name;
    insert into public.policies(organization_id,name,version,settings,updated_by)
    values(d.organization_id,safe_name,next_version,coalesce(p_settings,'{}'::jsonb),auth.uid())
    returning id into v_policy_id;
  end if;

  insert into public.device_policy_assignments(device_id,policy_id,assigned_by,assigned_at)
  values(p_device_id,v_policy_id,auth.uid(),now())
  on conflict(device_id) do update set
    policy_id=excluded.policy_id,assigned_by=excluded.assigned_by,assigned_at=excluded.assigned_at;
  return v_policy_id;
end;
$function$;

create or replace function public.create_device_command(p_device_id uuid,p_command_type text,p_payload jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path to 'public','pg_temp'
as $function$
declare
  d public.devices;
  cmd uuid;
  safe_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if not public.account_is_active() then raise exception 'account is not active'; end if;
  if length(coalesce(p_command_type,'')) not between 1 and 100 then raise exception 'invalid command type'; end if;
  if octet_length(safe_payload::text)>262144 then raise exception 'command payload too large'; end if;
  select * into d from public.devices where id=p_device_id;
  if d.id is null or not public.can_administer_device(p_device_id) then raise exception 'device administrator required'; end if;

  select c.id into cmd
  from public.device_commands c
  where c.device_id=p_device_id and c.created_by=auth.uid()
    and c.command_type=p_command_type and c.payload=safe_payload
    and c.status='pending' and c.created_at>=now()-interval '10 seconds'
  order by c.created_at desc limit 1;
  if cmd is not null then return cmd; end if;

  insert into public.device_commands(organization_id,device_id,command_type,payload,status,created_by)
  values(d.organization_id,p_device_id,p_command_type,safe_payload,'pending',auth.uid())
  returning id into cmd;
  return cmd;
end;
$function$;

create or replace function public.replace_device_apps(p_device_id uuid,p_apps jsonb)
returns integer language plpgsql security definer set search_path to 'public','pg_temp'
as $function$
declare
  d public.devices;
  item jsonb;
  app_count integer:=0;
  v_app_id text;
  v_display_name text;
  v_kind text;
  v_system boolean;
  v_metadata jsonb;
  seen_app_ids text[]:=array[]::text[];
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if not public.account_is_active() then raise exception 'account is not active'; end if;
  select * into d from public.devices where id=p_device_id;
  if d.id is null then raise exception 'device not found'; end if;
  if d.assigned_user_id<>auth.uid() then raise exception 'only the assigned device user may publish app inventory'; end if;
  if p_apps is null or jsonb_typeof(p_apps)<>'array' then raise exception 'apps must be an array'; end if;
  if jsonb_array_length(p_apps)>1000 then raise exception 'too many apps'; end if;
  if octet_length(p_apps::text)>1048576 then raise exception 'inventory too large'; end if;

  for item in select value from jsonb_array_elements(p_apps) loop
    v_app_id:=trim(coalesce(item->>'app_id',''));
    v_display_name:=trim(coalesce(item->>'display_name',v_app_id));
    v_kind:=trim(coalesce(nullif(item->>'app_kind',''),'application'));
    v_system:=coalesce((item->>'is_system')::boolean,false);
    v_metadata:=coalesce(item->'metadata','{}'::jsonb);
    if length(v_app_id) between 1 and 1024
       and length(v_display_name) between 1 and 512
       and length(v_kind) between 1 and 64
       and octet_length(v_metadata::text)<=65536
       and not (v_app_id=any(seen_app_ids)) then
      seen_app_ids:=array_append(seen_app_ids,v_app_id);
      app_count:=app_count+1;
      insert into public.device_apps(device_id,app_id,display_name,app_kind,is_system,metadata,last_seen_at)
      values(p_device_id,v_app_id,v_display_name,v_kind,v_system,v_metadata,now())
      on conflict(device_id,app_id) do update set
        display_name=excluded.display_name,app_kind=excluded.app_kind,is_system=excluded.is_system,
        metadata=excluded.metadata,last_seen_at=excluded.last_seen_at
      where public.device_apps.display_name is distinct from excluded.display_name
         or public.device_apps.app_kind is distinct from excluded.app_kind
         or public.device_apps.is_system is distinct from excluded.is_system
         or public.device_apps.metadata is distinct from excluded.metadata;
    end if;
  end loop;

  if cardinality(seen_app_ids)=0 then
    delete from public.device_apps where device_id=p_device_id;
  else
    delete from public.device_apps where device_id=p_device_id and not (app_id=any(seen_app_ids));
  end if;
  return app_count;
end;
$function$;
