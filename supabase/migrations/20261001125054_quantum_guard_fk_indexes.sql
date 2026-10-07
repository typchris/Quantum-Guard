create index if not exists policies_organization_id_idx on public.policies(organization_id);
create index if not exists report_archives_device_id_idx on public.report_archives(device_id);
create index if not exists report_archives_uploaded_by_idx on public.report_archives(uploaded_by);
