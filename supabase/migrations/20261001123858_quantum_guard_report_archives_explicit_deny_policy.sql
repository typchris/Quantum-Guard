create policy "report archives deny direct authenticated access"
on public.report_archives
for all
to authenticated
using (false)
with check (false);
