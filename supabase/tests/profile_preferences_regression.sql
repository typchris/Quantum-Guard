BEGIN;
DO $test$
DECLARE
  u uuid:=gen_random_uuid();
  result jsonb;
  denied boolean:=false;
BEGIN
  INSERT INTO auth.users(id,email) VALUES(u,u||'@audit.invalid');

  PERFORM set_config('request.jwt.claim.sub',u::text,true);
  PERFORM set_config('role','authenticated',true);

  BEGIN
    UPDATE public.profiles SET account_status='active' WHERE id=u;
  EXCEPTION WHEN insufficient_privilege THEN
    denied:=true;
  END;
  IF NOT denied THEN
    RAISE EXCEPTION 'FAIL direct profile update unexpectedly allowed';
  END IF;

  SELECT public.update_my_profile_preferences(
    'Audit User',
    'https://example.com/avatar.png',
    '{"theme":"dark","compact":true}'::jsonb
  ) INTO result;

  IF result->>'display_name' <> 'Audit User' THEN
    RAISE EXCEPTION 'FAIL display name update';
  END IF;
  IF result->'profile_settings'->>'theme' <> 'dark' THEN
    RAISE EXCEPTION 'FAIL profile settings update';
  END IF;

  denied:=false;
  BEGIN
    PERFORM public.update_my_profile_preferences(null,'http://example.com/a.png',null);
  EXCEPTION WHEN raise_exception THEN
    denied:=true;
  END;
  IF NOT denied THEN
    RAISE EXCEPTION 'FAIL insecure avatar URL allowed';
  END IF;

  PERFORM set_config('role','postgres',true);
  UPDATE public.profiles SET account_status='suspended' WHERE id=u;

  PERFORM set_config('request.jwt.claim.sub',u::text,true);
  PERFORM set_config('role','authenticated',true);
  denied:=false;
  BEGIN
    PERFORM public.update_my_profile_preferences('Suspended User',null,'{}'::jsonb);
  EXCEPTION WHEN raise_exception THEN
    denied:=true;
  END;
  IF NOT denied THEN
    RAISE EXCEPTION 'FAIL suspended user updated profile preferences';
  END IF;

  PERFORM set_config('role','postgres',true);
END $test$;

SELECT 'PASS: profile preferences update only through checked RPC; insecure avatar and suspended user denied' AS result;
ROLLBACK;
