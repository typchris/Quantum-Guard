BEGIN;
DO $test$
DECLARE
  owner_u uuid:=gen_random_uuid();
  admin_u uuid:=gen_random_uuid();
  client_u uuid:=gen_random_uuid();
  outsider_u uuid:=gen_random_uuid();
  org uuid:=gen_random_uuid();
  denied boolean;
  result jsonb;
BEGIN
  INSERT INTO auth.users(id,email) VALUES
    (owner_u,owner_u||'@audit.invalid'),
    (admin_u,admin_u||'@audit.invalid'),
    (client_u,client_u||'@audit.invalid'),
    (outsider_u,outsider_u||'@audit.invalid');
  INSERT INTO public.organizations(id,name,owner_id) VALUES(org,'AuthZ Audit',owner_u);
  INSERT INTO public.organization_members VALUES
    (org,owner_u,'owner',now()),
    (org,admin_u,'admin',now()),
    (org,client_u,'client',now());

  PERFORM set_config('request.jwt.claim.sub',admin_u::text,true);
  PERFORM set_config('role','authenticated',true);
  SELECT public.apply_account_status_change(client_u,'suspended','authz regression') INTO result;
  IF result->>'status' <> 'suspended' THEN
    RAISE EXCEPTION 'FAIL admin could not suspend client';
  END IF;

  PERFORM set_config('role','postgres',true);
  UPDATE public.profiles SET account_status='active' WHERE id=client_u;

  PERFORM set_config('request.jwt.claim.sub',admin_u::text,true);
  PERFORM set_config('role','authenticated',true);

  denied:=false;
  BEGIN
    PERFORM public.apply_account_status_change(owner_u,'suspended','should deny owner');
  EXCEPTION WHEN raise_exception THEN
    denied:=true;
  END;
  IF NOT denied THEN RAISE EXCEPTION 'FAIL admin could modify owner'; END IF;

  denied:=false;
  BEGIN
    PERFORM public.apply_account_status_change(admin_u,'suspended','should deny self');
  EXCEPTION WHEN raise_exception THEN
    denied:=true;
  END;
  IF NOT denied THEN RAISE EXCEPTION 'FAIL admin self-suspend allowed'; END IF;

  PERFORM set_config('request.jwt.claim.sub',owner_u::text,true);
  SELECT public.apply_account_status_change(admin_u,'suspended','owner manages admin') INTO result;
  IF result->>'status' <> 'suspended' THEN
    RAISE EXCEPTION 'FAIL owner could not suspend admin';
  END IF;

  PERFORM set_config('role','postgres',true);
  UPDATE public.profiles SET account_status='active' WHERE id=client_u;
  PERFORM set_config('request.jwt.claim.sub',outsider_u::text,true);
  PERFORM set_config('role','authenticated',true);

  denied:=false;
  BEGIN
    PERFORM public.apply_account_status_change(client_u,'blocked','outsider attempt');
  EXCEPTION WHEN raise_exception THEN
    denied:=true;
  END;
  IF NOT denied THEN RAISE EXCEPTION 'FAIL outsider account action allowed'; END IF;

  PERFORM set_config('role','postgres',true);
END $test$;

SELECT 'PASS: account action owner/admin/client/outsider authorization boundaries hold' AS result;
ROLLBACK;
