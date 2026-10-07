alter policy "owner creates organization"
on public.organizations
with check (owner_id = (select auth.uid()));

alter policy "device visible to owner or org admin"
on public.devices
using ((assigned_user_id = (select auth.uid())) or public.is_org_admin(organization_id));

alter policy "user enrolls own device"
on public.devices
with check ((assigned_user_id = (select auth.uid())) and public.is_org_member(organization_id));

alter policy "device owner or org admin updates device"
on public.devices
using ((assigned_user_id = (select auth.uid())) or public.is_org_admin(organization_id))
with check ((assigned_user_id = (select auth.uid())) or public.is_org_admin(organization_id));

alter policy "policy admins or assigned devices read"
on public.policies
using (
  public.is_org_admin(organization_id)
  or exists (
    select 1
    from public.device_policy_assignments a
    join public.devices d on d.id=a.device_id
    where a.policy_id=policies.id
      and d.assigned_user_id=(select auth.uid())
  )
);

alter policy "org admin creates commands"
on public.device_commands
with check (public.is_org_admin(organization_id) and created_by=(select auth.uid()));
