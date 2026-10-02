BEGIN;
DO $test$
DECLARE
  owner_u uuid:=gen_random_uuid();
  client_u uuid:=gen_random_uuid();
  org uuid:=gen_random_uuid();
  pair_code text;
  denied boolean:=false;
  exp timestamptz;
BEGIN
  INSERT INTO auth.users(id,email) VALUES
    (owner_u,owner_u||'@audit.invalid'),
    (client_u,client_u||'@audit.invalid');

  INSERT INTO public.organizations(id,name,owner_id)
  VALUES(org,'Pairing Audit',owner_u);

  INSERT INTO public.organization_members VALUES
    (org,owner_u,'owner',now()),
    (org,client_u,'client',now());

  PERFORM set_config('request.jwt.claim.sub',owner_u::text,true);
  PERFORM set_config('role','authenticated',true);

  SELECT public.create_pairing_code(org,1) INTO pair_code;

  IF pair_code !~ '^[A-F0-9]{10}$' THEN
    RAISE EXCEPTION 'FAIL invalid pairing code format: %', pair_code;
  END IF;

  PERFORM set_config('role','postgres',true);

  SELECT dpc.expires_at INTO exp
  FROM public.device_pair_codes dpc
  WHERE dpc.code=pair_code;

  IF exp < now() + interval '4 minutes'
     OR exp > now() + interval '6 minutes' THEN
    RAISE EXCEPTION 'FAIL minimum expiry clamp not applied';
  END IF;

  PERFORM set_config('request.jwt.claim.sub',client_u::text,true);
  PERFORM set_config('role','authenticated',true);

  BEGIN
    PERFORM public.create_pairing_code(org,15);
  EXCEPTION WHEN raise_exception THEN
    denied:=true;
  END;

  IF NOT denied THEN
    RAISE EXCEPTION 'FAIL client pairing code creation allowed';
  END IF;

  PERFORM set_config('role','postgres',true);
END $test$;

SELECT 'PASS: owner pairing code generation works, format/expiry clamp hold, client creation denied' AS result;
ROLLBACK;
