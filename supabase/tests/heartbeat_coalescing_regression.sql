BEGIN;
DO $test$
DECLARE
  u uuid:=gen_random_uuid();
  org uuid:=gen_random_uuid();
  dev uuid:=gen_random_uuid();
  d_updated timestamptz;
  p_updated timestamptz;
  sentinel timestamptz:='2000-01-01 00:00:00+00';
BEGIN
  INSERT INTO auth.users(id,email) VALUES (u,u||'@audit.invalid');
  INSERT INTO public.organizations(id,name,owner_id) VALUES (org,'Heartbeat Audit',u);
  INSERT INTO public.organization_members(organization_id,user_id,role) VALUES (org,u,'owner');
  INSERT INTO public.devices(id,organization_id,assigned_user_id,device_name,platform,control_status)
  VALUES (dev,org,u,'Heartbeat Device','windows','active');
  INSERT INTO public.device_user_assignments(device_id,user_id,role,is_primary_admin)
  VALUES (dev,u,'owner',true);

  PERFORM set_config('request.jwt.claim.sub',u::text,true);
  PERFORM set_config('role','authenticated',true);

  PERFORM public.device_heartbeat(dev,'1.11.0-preview.4','host-a','User','Windows 11');

  PERFORM set_config('role','postgres',true);
  UPDATE public.devices SET updated_at=sentinel WHERE id=dev;
  UPDATE public.profiles SET updated_at=sentinel WHERE id=u;

  PERFORM set_config('role','authenticated',true);
  PERFORM public.device_heartbeat(dev,'1.11.0-preview.4','host-a','User','Windows 11');

  PERFORM set_config('role','postgres',true);
  SELECT updated_at INTO d_updated FROM public.devices WHERE id=dev;
  SELECT updated_at INTO p_updated FROM public.profiles WHERE id=u;

  IF d_updated <> sentinel THEN
    RAISE EXCEPTION 'FAIL unchanged heartbeat rewrote device row';
  END IF;
  IF p_updated <> sentinel THEN
    RAISE EXCEPTION 'FAIL unchanged heartbeat rewrote profile row';
  END IF;

  UPDATE public.devices SET updated_at=sentinel WHERE id=dev;

  PERFORM set_config('role','authenticated',true);
  PERFORM public.device_heartbeat(dev,'1.11.0-preview.5','host-a','User','Windows 11');

  PERFORM set_config('role','postgres',true);
  SELECT updated_at INTO d_updated FROM public.devices WHERE id=dev;

  IF d_updated = sentinel THEN
    RAISE EXCEPTION 'FAIL changed heartbeat metadata was not written';
  END IF;

  IF (SELECT agent_version FROM public.devices WHERE id=dev) <> '1.11.0-preview.5' THEN
    RAISE EXCEPTION 'FAIL changed agent version not persisted';
  END IF;
END $test$;

SELECT 'PASS: frequent identical heartbeats are coalesced while real metadata changes write immediately' AS result;
ROLLBACK;
