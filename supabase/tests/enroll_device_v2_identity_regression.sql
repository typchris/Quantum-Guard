BEGIN;
DO $test$
DECLARE
  u uuid:=gen_random_uuid();
  org uuid:=gen_random_uuid();
  dev uuid:=gen_random_uuid();
  returned uuid;
  returned_again uuid;
  ctx jsonb;
  install text:='w-regression-0123456789abcdef';
  role_after text;
  device_count bigint;
BEGIN
  INSERT INTO auth.users(id,email) VALUES (u,u||'@enroll-v2.invalid');
  INSERT INTO public.organizations(id,name,owner_id) VALUES (org,'Enroll V2 Regression',u);
  INSERT INTO public.organization_members(organization_id,user_id,role) VALUES (org,u,'owner');
  INSERT INTO public.qg_entitlements(
    organization_id,plan_code,status,device_limit,valid_until,provider,provider_subscription_id
  ) VALUES (
    org,'family','active',5,now()+interval '1 day','manual','regression-test-'||org::text
  );

  PERFORM set_config('request.jwt.claim.sub',u::text,true);

  INSERT INTO public.devices(
    id,organization_id,assigned_user_id,device_name,platform,device_status,control_status,hostname
  ) VALUES (
    dev,org,u,'Legacy Windows Device','windows','offline','active','WIN-REGRESSION'
  );
  INSERT INTO public.device_user_assignments(device_id,user_id,role,is_primary_admin)
  VALUES (dev,u,'admin',false);

  PERFORM set_config('role','authenticated',true);

  returned:=public.enroll_device_v2(
    org,'Legacy Windows Device','windows','1.12.4',
    'WIN-REGRESSION','Windows 11',install
  );

  IF returned IS DISTINCT FROM dev THEN
    RAISE EXCEPTION 'FAIL legacy device id was not preserved';
  END IF;

  returned_again:=public.enroll_device_v2(
    org,'Legacy Windows Device','windows','1.12.4',
    'WIN-REGRESSION','Windows 11',install
  );

  IF returned_again IS DISTINCT FROM dev THEN
    RAISE EXCEPTION 'FAIL repeat enrollment did not return same device';
  END IF;

  ctx:=public.get_my_device_context(dev);

  PERFORM set_config('role','postgres',true);

  SELECT count(*) INTO device_count
  FROM public.devices
  WHERE organization_id=org AND platform='windows';

  IF device_count<>1 THEN
    RAISE EXCEPTION 'FAIL duplicate Windows device created';
  END IF;

  IF (SELECT installation_id FROM public.devices WHERE id=dev) IS DISTINCT FROM install THEN
    RAISE EXCEPTION 'FAIL installation identity not claimed';
  END IF;

  SELECT role INTO role_after
  FROM public.device_user_assignments
  WHERE device_id=dev AND user_id=u;

  IF role_after IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'FAIL existing device-specific role was changed';
  END IF;

  IF ctx->>'installation_id' IS DISTINCT FROM install THEN
    RAISE EXCEPTION 'FAIL device context does not expose installation identity';
  END IF;
END $test$;

SELECT 'PASS: enroll_device_v2 preserves device id and role, prevents duplicate enrollment, and exposes installation identity' AS result;
ROLLBACK;
