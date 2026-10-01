-- Rollback-only regression for account-wide multi-organization changes.
BEGIN;
DO $test$
DECLARE
 caller uuid:=gen_random_uuid();
 target uuid:=gen_random_uuid();
 org_a uuid:=gen_random_uuid();
 org_b uuid:=gen_random_uuid();
 dev_a uuid:=gen_random_uuid();
 dev_b uuid:=gen_random_uuid();
 result jsonb;
 command_count integer;
 audit_count integer;
BEGIN
 INSERT INTO auth.users(id,email) VALUES
  (caller,caller||'@audit.invalid'),
  (target,target||'@audit.invalid');
 INSERT INTO public.organizations(id,name,owner_id) VALUES
  (org_a,'Multi A',caller),
  (org_b,'Multi B',caller);
 INSERT INTO public.organization_members VALUES
  (org_a,caller,'owner',now()),
  (org_b,caller,'owner',now()),
  (org_a,target,'client',now()),
  (org_b,target,'client',now());
 INSERT INTO public.devices(id,organization_id,assigned_user_id,device_name,platform) VALUES
  (dev_a,org_a,target,'Target A','windows'),
  (dev_b,org_b,target,'Target B','windows');

 PERFORM set_config('request.jwt.claim.sub',caller::text,true);
 PERFORM set_config('role','authenticated',true);

 SELECT public.apply_account_status_change(target,'suspended','multi-org regression') INTO result;

 IF coalesce((result->>'organizations_affected')::int,0) <> 2 THEN
   RAISE EXCEPTION 'FAIL expected 2 organizations: %', result;
 END IF;
 IF coalesce((result->>'devices_notified')::int,0) <> 2 THEN
   RAISE EXCEPTION 'FAIL expected 2 devices: %', result;
 END IF;

 PERFORM set_config('role','postgres',true);
 IF (SELECT account_status FROM public.profiles WHERE id=target) <> 'suspended' THEN
   RAISE EXCEPTION 'FAIL profile not suspended';
 END IF;

 SELECT count(*) INTO command_count
 FROM public.device_commands
 WHERE device_id in (dev_a,dev_b)
   AND command_type='account_suspended'
   AND created_by=caller;
 IF command_count <> 2 THEN
   RAISE EXCEPTION 'FAIL expected 2 commands, got %',command_count;
 END IF;

 SELECT count(*) INTO audit_count
 FROM public.admin_audit_log
 WHERE organization_id in (org_a,org_b)
   AND actor_user_id=caller
   AND target_user_id=target
   AND action='account_suspended';
 IF audit_count <> 2 THEN
   RAISE EXCEPTION 'FAIL expected 2 audit rows, got %',audit_count;
 END IF;
END $test$;
SELECT 'PASS: account status transaction spans both organizations, both devices, and both audit rows' AS result;
ROLLBACK;
