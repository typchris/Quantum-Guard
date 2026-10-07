alter table public.profiles
  add constraint profiles_display_name_len_check check (display_name is null or length(display_name) <= 200),
  add constraint profiles_email_len_check check (email is null or length(email) <= 320),
  add constraint profiles_avatar_url_len_check check (avatar_url is null or length(avatar_url) <= 4096),
  add constraint profiles_blocked_reason_len_check check (blocked_reason is null or length(blocked_reason) <= 500),
  add constraint profiles_settings_size_check check (octet_length(profile_settings::text) <= 65536);

alter table public.organizations
  add constraint organizations_name_len_check check (length(trim(name)) between 2 and 200);

alter table public.devices
  add constraint devices_name_len_check check (length(trim(device_name)) between 1 and 200),
  add constraint devices_agent_version_len_check check (agent_version is null or length(agent_version) <= 100),
  add constraint devices_hostname_len_check check (hostname is null or length(hostname) <= 255),
  add constraint devices_current_user_name_len_check check (current_user_name is null or length(current_user_name) <= 255),
  add constraint devices_os_version_len_check check (os_version is null or length(os_version) <= 255);

alter table public.policies
  add constraint policies_name_len_check check (length(trim(name)) between 1 and 200),
  add constraint policies_settings_size_check check (octet_length(settings::text) <= 1048576);

alter table public.device_commands
  add constraint device_commands_type_len_check check (length(command_type) between 1 and 100),
  add constraint device_commands_payload_size_check check (octet_length(payload::text) <= 262144),
  add constraint device_commands_result_size_check check (result is null or octet_length(result::text) <= 262144);

alter table public.device_events
  add constraint device_events_type_len_check check (length(event_type) between 1 and 100),
  add constraint device_events_detail_size_check check (detail is null or octet_length(detail::text) <= 65536);

alter table public.device_pair_codes
  add constraint device_pair_codes_format_check check (code ~ '^[A-F0-9]{10}$');

alter table public.admin_audit_log
  add constraint admin_audit_log_action_len_check check (length(action) between 1 and 100),
  add constraint admin_audit_log_detail_size_check check (detail is null or octet_length(detail::text) <= 65536);
