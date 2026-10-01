create or replace function public.update_my_profile_preferences(
  p_display_name text default null,
  p_avatar_url text default null,
  p_profile_settings jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_row public.profiles;
  v_name text;
  v_avatar text;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  if not public.account_is_active() then
    raise exception 'active account required';
  end if;

  if p_profile_settings is not null
     and jsonb_typeof(p_profile_settings) <> 'object' then
    raise exception 'profile settings must be an object';
  end if;

  if p_display_name is not null then
    v_name := nullif(trim(p_display_name), '');
    if v_name is null or length(v_name) > 200 then
      raise exception 'invalid display name';
    end if;
  end if;

  if p_avatar_url is not null then
    v_avatar := nullif(trim(p_avatar_url), '');
    if v_avatar is not null
       and (length(v_avatar) > 4096 or v_avatar !~ '^https://') then
      raise exception 'avatar URL must use HTTPS';
    end if;
  end if;

  update public.profiles
  set display_name = case when p_display_name is null then display_name else v_name end,
      avatar_url = case when p_avatar_url is null then avatar_url else v_avatar end,
      profile_settings = case
        when p_profile_settings is null then profile_settings
        else p_profile_settings
      end,
      updated_at = now()
  where id = auth.uid()
  returning * into v_row;

  if v_row.id is null then
    raise exception 'profile not found';
  end if;

  return jsonb_build_object(
    'id', v_row.id,
    'display_name', v_row.display_name,
    'avatar_url', v_row.avatar_url,
    'profile_settings', coalesce(v_row.profile_settings, '{}'::jsonb),
    'updated_at', v_row.updated_at
  );
end;
$function$;

revoke all on function public.update_my_profile_preferences(text,text,jsonb) from public;
revoke all on function public.update_my_profile_preferences(text,text,jsonb) from anon;
grant execute on function public.update_my_profile_preferences(text,text,jsonb) to authenticated;
grant execute on function public.update_my_profile_preferences(text,text,jsonb) to service_role;
