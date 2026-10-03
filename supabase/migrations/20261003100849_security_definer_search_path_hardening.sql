-- Quantum Guard security hardening
-- Applied live to Supabase as migration 20261003100849.
-- Keep pg_temp last in SECURITY DEFINER search paths so untrusted temporary
-- objects cannot shadow public objects referenced by privileged functions.

alter function public.ack_device_command(uuid,text,jsonb) set search_path = public, pg_temp;
alter function public.can_administer_user(uuid) set search_path = public, pg_temp;
alter function public.create_organization(text) set search_path = public, pg_temp;
alter function public.create_pairing_code(uuid,integer) set search_path = public, pg_temp;
alter function public.delete_expired_pairing_codes() set search_path = public, pg_temp;
alter function public.device_effective_role(uuid) set search_path = public, pg_temp;
alter function public.get_my_device_context(uuid) set search_path = public, pg_temp;
alter function public.handle_new_auth_user() set search_path = public, pg_temp;
alter function public.is_org_admin(uuid) set search_path = public, pg_temp;
alter function public.is_org_member(uuid) set search_path = public, pg_temp;
alter function public.is_org_owner(uuid) set search_path = public, pg_temp;
alter function public.list_organization_members(uuid) set search_path = public, pg_temp;
alter function public.owns_device(uuid) set search_path = public, pg_temp;
alter function public.redeem_pairing_code(text,text,text,text) set search_path = public, pg_temp;
alter function public.set_organization_member_role(uuid,uuid,text) set search_path = public, pg_temp;
