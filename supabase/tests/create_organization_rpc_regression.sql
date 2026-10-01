BEGIN;
DO $test$
DECLARE
  u uuid:=gen_random_uuid();
  org_id uuid;
  denied boolean:=false;
BEGIN
  INSERT INTO auth.users(id,email) VALUES(u,u||'@audit.invalid');
  PERFORM set_config('request.jwt.claim.sub',u::text,true);
  PERFORM set_config('role','authenticated',true);

  BEGIN
    INSERT INTO public.organizations(name,owner_id) VALUES('Direct Denied',u);
  EXCEPTION WHEN insufficient_privilege THEN
    denied:=true;
  END;
  IF NOT denied THEN RAISE EXCEPTION 'FAIL direct organization insert allowed'; END IF;

  SELECT public.create_organization('RPC Allowed') INTO org_id;
  IF org_id IS NULL THEN RAISE EXCEPTION 'FAIL create_organization returned null'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.organization_members
    WHERE organization_id=org_id AND user_id=u AND role='owner'
  ) THEN
    RAISE EXCEPTION 'FAIL create_organization did not create owner membership';
  END IF;

  PERFORM set_config('role','postgres',true);
END $test$;

SELECT 'PASS: direct organization insert denied and create_organization RPC works' AS result;
ROLLBACK;
