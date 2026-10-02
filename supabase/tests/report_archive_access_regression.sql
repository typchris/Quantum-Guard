-- Rollback-only regression for private report archive access.
BEGIN;
DO $test$
DECLARE
  u uuid:=gen_random_uuid();
  org uuid:=gen_random_uuid();
  dev uuid:=gen_random_uuid();
  reserved jsonb;
  report_id uuid;
  fetched jsonb;
  denied boolean:=false;
BEGIN
  INSERT INTO auth.users(id,email) VALUES (u,u||'@audit.invalid');
  INSERT INTO public.organizations(id,name,owner_id) VALUES (org,'Archive Audit',u);
  INSERT INTO public.organization_members(organization_id,user_id,role) VALUES (org,u,'owner');
  INSERT INTO public.devices(id,organization_id,assigned_user_id,device_name,platform,control_status)
  VALUES (dev,org,u,'Archive Device','windows','active');
  INSERT INTO public.device_user_assignments(device_id,user_id,role,is_primary_admin)
  VALUES (dev,u,'owner',true);

  PERFORM set_config('request.jwt.claim.sub',u::text,true);
  PERFORM set_config('role','authenticated',true);

  BEGIN
    PERFORM 1 FROM public.report_archives LIMIT 1;
  EXCEPTION WHEN insufficient_privilege THEN
    denied:=true;
  END;

  IF NOT denied THEN
    RAISE EXCEPTION 'FAIL direct report_archives read allowed';
  END IF;

  SELECT public.reserve_report_archive(dev,1024,repeat('a',64)) INTO reserved;
  report_id := (reserved->>'id')::uuid;
  IF report_id IS NULL THEN
    RAISE EXCEPTION 'FAIL reserve did not return id';
  END IF;

  PERFORM public.complete_report_archive(report_id);
  SELECT public.get_report_archive(report_id) INTO fetched;

  IF (fetched->>'id')::uuid <> report_id THEN
    RAISE EXCEPTION 'FAIL get_report_archive did not return reserved report';
  END IF;

  PERFORM set_config('role','postgres',true);
END $test$;

SELECT 'PASS: report archive direct table access denied while checked RPC flow works' AS result;
ROLLBACK;
