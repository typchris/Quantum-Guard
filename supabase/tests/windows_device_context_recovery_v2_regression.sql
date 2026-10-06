begin;
do $test$
declare
  u uuid := gen_random_uuid();
  org uuid := gen_random_uuid();
  dev uuid := gen_random_uuid();
  ctx jsonb;
  ctx2 jsonb;
  install text := 'w-context-regression-0123456789';
begin
  insert into auth.users(id,email) values (u,u||'@context-v2.invalid');
  insert into public.organizations(id,name,owner_id) values (org,'Context V2 Regression',u);
  insert into public.organization_members(organization_id,user_id,role) values (org,u,'owner');
  insert into public.qg_entitlements(
    organization_id,plan_code,status,device_limit,valid_until,provider,provider_subscription_id
  ) values (
    org,'family','active',5,now()+interval '1 day','manual','context-v2-'||org::text
  );

  perform set_config('request.jwt.claim.sub',u::text,true);

  insert into public.devices(
    id,organization_id,assigned_user_id,device_name,platform,
    device_status,control_status,hostname,installation_id
  ) values (
    dev,org,u,'Context Windows','windows',
    'online','active','WIN-CONTEXT',null
  );
  insert into public.device_user_assignments(device_id,user_id,role,is_primary_admin)
  values(dev,u,'owner',true);

  perform set_config('role','authenticated',true);

  ctx := public.recover_my_device_context_v2(
    install,'windows','WIN-CONTEXT','Context Windows'
  );

  if ctx is null or ctx->>'device_id' is distinct from dev::text then
    raise exception 'FAIL legacy context recovery';
  end if;

  perform set_config('role','postgres',true);
  update public.devices set installation_id=install where id=dev;
  perform set_config('role','authenticated',true);

  ctx2 := public.recover_my_device_context_v2(
    install,'windows','WRONG-HOST','Wrong Name'
  );

  if ctx2 is null or ctx2->>'device_id' is distinct from dev::text then
    raise exception 'FAIL installation identity recovery';
  end if;

  if public.recover_my_device_context_v2(
    'w-different-installation-12345678','windows','WIN-CONTEXT','Context Windows'
  ) is not null then
    raise exception 'FAIL mismatched stable installation fell back to claimed device';
  end if;
end
$test$;

select 'PASS: authoritative device context recovery prefers installation identity and restricts fallback to legacy rows' as result;
rollback;
