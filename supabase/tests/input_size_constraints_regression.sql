BEGIN;
DO $test$
DECLARE
  u uuid:=gen_random_uuid();
  org uuid:=gen_random_uuid();
  dev uuid:=gen_random_uuid();
  denied boolean:=false;
BEGIN
  INSERT INTO auth.users(id,email) VALUES (u,u||'@audit.invalid');
  INSERT INTO public.organizations(id,name,owner_id) VALUES (org,'Bounds Audit',u);
  INSERT INTO public.organization_members(organization_id,user_id,role) VALUES (org,u,'owner');
  INSERT INTO public.devices(id,organization_id,assigned_user_id,device_name,platform,control_status)
  VALUES (dev,org,u,'Bounds Device','windows','active');
  INSERT INTO public.device_user_assignments(device_id,user_id,role,is_primary_admin)
  VALUES (dev,u,'owner',true);

  PERFORM set_config('request.jwt.claim.sub',u::text,true);
  PERFORM set_config('role','authenticated',true);

  PERFORM public.device_heartbeat(dev,'1.11.0-preview.4','good-host','User','Windows 11');

  BEGIN
    PERFORM public.device_heartbeat(dev,'1.11.0-preview.4',repeat('h',256),'User','Windows 11');
  EXCEPTION WHEN check_violation THEN
    denied:=true;
  END;

  IF NOT denied THEN
    RAISE EXCEPTION 'FAIL oversized hostname was accepted';
  END IF;

  PERFORM set_config('role','postgres',true);
END $test$;

SELECT 'PASS: normal heartbeat accepted and oversized device metadata rejected' AS result;
ROLLBACK;
