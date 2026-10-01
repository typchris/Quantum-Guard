create or replace function public.apply_account_status_change(
  p_target_user uuid,
  p_status text,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_caller uuid := auth.uid();
  v_requested text := lower(trim(coalesce(p_status, '')));
  v_reason text := left(coalesce(p_reason, ''), 500);
  v_previous_status text;
  v_operation_id uuid := gen_random_uuid();
  v_org_count integer := 0;
  v_device_count integer := 0;
  v_audit_ids jsonb := '[]'::jsonb;
  v_bad_org uuid;
begin
  if v_caller is null then raise exception 'authentication required'; end if;
  if not public.account_is_active() then raise exception 'active account required'; end if;
  if p_target_user is null then raise exception 'target user is required'; end if;
  if v_requested not in ('active','suspended','blocked') then
    raise exception 'status must be active, suspended, or blocked';
  end if;
  if p_target_user = v_caller and v_requested <> 'active' then
    raise exception 'administrators cannot suspend or block themselves';
  end if;

  select p.account_status into v_previous_status
  from public.profiles p
  where p.id = p_target_user
  for update;

  if v_previous_status is null then raise exception 'target profile not found'; end if;

  select count(*) into v_org_count
  from public.organization_members target
  where target.user_id = p_target_user;

  if v_org_count = 0 then raise exception 'target user has no organization memberships'; end if;

  select target.organization_id into v_bad_org
  from public.organization_members target
  left join public.organization_members caller
    on caller.organization_id = target.organization_id
   and caller.user_id = v_caller
  where target.user_id = p_target_user
    and (
      target.role = 'owner'
      or caller.role is null
      or caller.role not in ('owner','admin')
      or (target.role = 'admin' and caller.role <> 'owner')
      or target.role not in ('admin','client')
    )
  limit 1;

  if v_bad_org is not null then
    raise exception 'account-wide action not authorized for every organization';
  end if;

  update public.profiles
  set account_status = v_requested,
      blocked_at = case when v_requested = 'blocked' then now() else null end,
      blocked_reason = case when v_requested = 'blocked' then nullif(v_reason, '') else null end,
      updated_at = now()
  where id = p_target_user;

  with inserted as (
    insert into public.device_commands(
      organization_id, device_id, command_type, payload, status, created_by
    )
    select
      d.organization_id,
      d.id,
      case
        when v_requested = 'blocked' then 'account_blocked'
        when v_requested = 'suspended' then 'account_suspended'
        else 'account_restored'
      end,
      jsonb_build_object(
        'reason', v_reason,
        'account_status', v_requested,
        'operation_id', v_operation_id
      ),
      'pending',
      v_caller
    from public.devices d
    join public.organization_members target
      on target.organization_id = d.organization_id
     and target.user_id = p_target_user
    where d.assigned_user_id = p_target_user
    returning id
  )
  select count(*) into v_device_count from inserted;

  with inserted as (
    insert into public.admin_audit_log(
      organization_id, actor_user_id, target_user_id, action, detail
    )
    select
      target.organization_id,
      v_caller,
      p_target_user,
      'account_' || v_requested,
      jsonb_build_object(
        'reason', v_reason,
        'previous_status', v_previous_status,
        'requested_status', v_requested,
        'operation_id', v_operation_id,
        'auth_sync', 'pending'
      )
    from public.organization_members target
    where target.user_id = p_target_user
    returning id
  )
  select coalesce(jsonb_agg(id order by id), '[]'::jsonb)
    into v_audit_ids
  from inserted;

  return jsonb_build_object(
    'ok', true,
    'operation_id', v_operation_id,
    'status', v_requested,
    'previous_status', v_previous_status,
    'organizations_affected', v_org_count,
    'devices_notified', v_device_count,
    'audit_ids', v_audit_ids
  );
end;
$function$;

revoke all on function public.apply_account_status_change(uuid,text,text) from public;
revoke all on function public.apply_account_status_change(uuid,text,text) from anon;
grant execute on function public.apply_account_status_change(uuid,text,text) to authenticated;
grant execute on function public.apply_account_status_change(uuid,text,text) to service_role;
