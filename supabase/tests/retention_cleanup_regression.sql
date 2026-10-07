BEGIN;
DO $test$
DECLARE
  u uuid := gen_random_uuid();
  org uuid := gen_random_uuid();
  dev uuid := gen_random_uuid();
  old_policy uuid := gen_random_uuid();
  new_policy uuid := gen_random_uuid();
  pair_id uuid := gen_random_uuid();
  cmd_id uuid := gen_random_uuid();
  info_event bigint;
  critical_event bigint;
  result jsonb;
BEGIN
  INSERT INTO auth.users(id,email) VALUES (u,u||'@retention.invalid');
  INSERT INTO public.organizations(id,name,owner_id)
  VALUES (org,'Retention Audit',u);
  INSERT INTO public.organization_members(organization_id,user_id,role)
  VALUES (org,u,'owner');
  INSERT INTO public.devices(id,organization_id,assigned_user_id,device_name,platform,control_status)
  VALUES (dev,org,u,'Retention Device','windows','active');

  INSERT INTO public.device_pair_codes(
    id,organization_id,code,created_by,expires_at,used_at,used_by,created_at
  ) VALUES (
    pair_id,org,'A1B2C3D4E5',u,now()-interval '2 days',
    now()-interval '2 days',u,now()-interval '3 days'
  );

  INSERT INTO public.device_commands(
    id,organization_id,device_id,command_type,payload,status,created_by,
    created_at,received_at,completed_at,result
  ) VALUES (
    cmd_id,org,dev,'retention_test','{}','completed',u,
    now()-interval '32 days',now()-interval '32 days',
    now()-interval '31 days','{}'
  );

  INSERT INTO public.device_events(
    organization_id,device_id,event_type,severity,detail,created_at
  ) VALUES (
    org,dev,'retention_info','info','{}',now()-interval '31 days'
  ) RETURNING id INTO info_event;

  INSERT INTO public.device_events(
    organization_id,device_id,event_type,severity,detail,created_at
  ) VALUES (
    org,dev,'retention_critical','critical','{}',now()-interval '31 days'
  ) RETURNING id INTO critical_event;

  INSERT INTO public.policies(
    id,organization_id,name,version,settings,updated_by,created_at,updated_at
  ) VALUES
    (old_policy,org,'Retention Policy',1,'{}',u,now()-interval '40 days',now()-interval '31 days'),
    (new_policy,org,'Retention Policy',2,'{}',u,now(),now());

  INSERT INTO public.device_policy_assignments(device_id,policy_id,assigned_by,assigned_at)
  VALUES (dev,new_policy,u,now());

  SELECT public.run_quantum_guard_retention_cleanup() INTO result;

  IF EXISTS (SELECT 1 FROM public.device_pair_codes WHERE id=pair_id) THEN
    RAISE EXCEPTION 'FAIL old pairing code not deleted';
  END IF;
  IF EXISTS (SELECT 1 FROM public.device_commands WHERE id=cmd_id) THEN
    RAISE EXCEPTION 'FAIL old completed command not deleted';
  END IF;
  IF EXISTS (SELECT 1 FROM public.device_events WHERE id=info_event) THEN
    RAISE EXCEPTION 'FAIL old routine info event not deleted';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.device_events WHERE id=critical_event) THEN
    RAISE EXCEPTION 'FAIL old critical event should have been retained';
  END IF;
  IF EXISTS (SELECT 1 FROM public.policies WHERE id=old_policy) THEN
    RAISE EXCEPTION 'FAIL old unassigned policy version not deleted';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.policies WHERE id=new_policy) THEN
    RAISE EXCEPTION 'FAIL assigned current policy was deleted';
  END IF;

  IF (result->>'pairing_codes_deleted')::int < 1
     OR (result->>'device_commands_deleted')::int < 1
     OR (result->>'routine_events_deleted')::int < 1
     OR (result->>'unassigned_policy_versions_deleted')::int < 1 THEN
    RAISE EXCEPTION 'FAIL cleanup result counts missing expected deletions: %', result;
  END IF;
END $test$;

SELECT 'PASS: automatic retention deletes only intended stale control-plane rows' AS result;
ROLLBACK;
