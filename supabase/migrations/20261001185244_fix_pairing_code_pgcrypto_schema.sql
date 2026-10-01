-- Fix pairing-code generation when pgcrypto is installed in the Supabase extensions schema.
-- The RPC intentionally keeps a restricted search_path and schema-qualifies pgcrypto.

create or replace function public.create_pairing_code(
  p_organization_id uuid,
  p_expires_minutes integer default 15
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  new_code text;
  mins integer;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;
  if not public.is_org_admin(p_organization_id) then
    raise exception 'organization administrator required';
  end if;

  mins := greatest(5, least(coalesce(p_expires_minutes, 15), 120));

  delete from public.device_pair_codes
  where expires_at < now() - interval '1 day';

  loop
    new_code := upper(substr(encode(extensions.gen_random_bytes(8), 'hex'), 1, 10));
    exit when not exists (
      select 1
      from public.device_pair_codes
      where code = new_code
    );
  end loop;

  insert into public.device_pair_codes(
    organization_id,
    code,
    created_by,
    expires_at
  )
  values (
    p_organization_id,
    new_code,
    auth.uid(),
    now() + make_interval(mins => mins)
  );

  return new_code;
end;
$$;

revoke all on function public.create_pairing_code(uuid, integer) from public;
grant execute on function public.create_pairing_code(uuid, integer) to authenticated;
