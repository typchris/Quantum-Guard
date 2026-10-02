create or replace function public.patch_device_policy(
  p_device_id uuid,
  p_patch jsonb,
  p_name text default 'Quantum Guard managed policy'
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  current_settings jsonb := '{}'::jsonb;
  merged_settings jsonb;
  v_policy_id uuid;
  v_policy_version bigint;
  v_policy_settings jsonb;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if not public.account_is_active() then raise exception 'account is not active'; end if;
  if not public.can_administer_device(p_device_id) then raise exception 'device administrator required'; end if;
  if p_patch is null or jsonb_typeof(p_patch) <> 'object' then raise exception 'policy patch must be an object'; end if;
  if octet_length(p_patch::text) > 262144 then raise exception 'policy patch too large'; end if;

  select p.settings into current_settings
  from public.device_policy_assignments a
  join public.policies p on p.id = a.policy_id
  where a.device_id = p_device_id;

  merged_settings := coalesce(current_settings, '{}'::jsonb) || p_patch;

  v_policy_id := public.set_device_policy(
    p_device_id,
    coalesce(nullif(trim(p_name), ''), 'Quantum Guard managed policy'),
    merged_settings
  );

  select p.version, p.settings into v_policy_version, v_policy_settings
  from public.policies p where p.id = v_policy_id;

  return jsonb_build_object(
    'policy_id', v_policy_id,
    'policy_version', v_policy_version,
    'policy_settings', coalesce(v_policy_settings, '{}'::jsonb)
  );
end;
$function$;

revoke all on function public.patch_device_policy(uuid, jsonb, text) from public;
revoke all on function public.patch_device_policy(uuid, jsonb, text) from anon;
grant execute on function public.patch_device_policy(uuid, jsonb, text) to authenticated;
