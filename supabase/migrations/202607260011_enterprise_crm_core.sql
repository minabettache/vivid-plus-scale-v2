-- =========================================================
-- VIVID+ MIGRATION 011
-- ENTERPRISE CRM CORE
-- Customer profiles, notes, tags, segments, consent,
-- campaigns, communications, automations, referrals, leads,
-- and an append-only customer timeline.
-- =========================================================

begin;

-- =========================================================
-- ENUMS
-- =========================================================

do $$ begin
  create type public.crm_note_visibility as enum ('private','team','management');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.crm_segment_type as enum ('static','dynamic');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.crm_campaign_status as enum (
    'draft','scheduled','running','paused','completed','cancelled'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.crm_channel as enum ('email','sms','push','in_app');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.crm_message_status as enum (
    'queued','scheduled','sending','sent','delivered','failed',
    'bounced','opened','clicked','unsubscribed','cancelled'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.crm_consent_status as enum (
    'unknown','opted_in','opted_out','transactional_only'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.crm_automation_status as enum ('draft','active','paused','archived');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.crm_lead_status as enum (
    'new','contacted','qualified','converted','lost','archived'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.crm_timeline_event_type as enum (
    'customer_created','membership_created','profile_updated','note_added',
    'tag_added','tag_removed','segment_added','segment_removed',
    'visit','purchase','refund','loyalty','message','campaign',
    'consent_changed','referral','lead','custom'
  );
exception when duplicate_object then null; end $$;

-- =========================================================
-- PERMISSIONS
-- =========================================================

insert into public.permissions (code, module, description, is_sensitive)
values
  ('crm.read',              'crm', 'View CRM customer profiles, tags, segments, and timeline.', false),
  ('crm.manage',            'crm', 'Manage customer CRM profiles, tags, segments, and notes.', true),
  ('crm.notes_private',     'crm', 'View and create private CRM notes.', true),
  ('crm.marketing_read',    'crm', 'View campaigns, automations, and communication results.', false),
  ('crm.marketing_manage',  'crm', 'Create, schedule, pause, and manage marketing campaigns.', true),
  ('crm.consent_manage',    'crm', 'Manage customer communication consent and suppression.', true),
  ('crm.leads_manage',      'crm', 'Create and manage leads and referral opportunities.', true),
  ('crm.export',            'crm', 'Export customer and campaign data.', true)
on conflict ((lower(code))) do update
set
  module = excluded.module,
  description = excluded.description,
  is_sensitive = excluded.is_sensitive;

-- =========================================================
-- CUSTOMER CRM PROFILE
-- =========================================================

create table if not exists public.customer_crm_profiles (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  membership_id uuid not null references public.memberships(id) on delete restrict,
  customer_id uuid not null references public.customers(id) on delete restrict,
  assigned_employee_id uuid references public.employees(id) on delete set null,
  preferred_location_id uuid references public.business_locations(id) on delete set null,
  acquisition_source text,
  acquisition_campaign text,
  customer_stage text not null default 'active',
  engagement_score integer not null default 0,
  churn_risk_score integer not null default 0,
  lifetime_value_cents bigint not null default 0,
  average_order_value_cents bigint not null default 0,
  total_orders integer not null default 0,
  last_purchase_at timestamptz,
  next_follow_up_at timestamptz,
  internal_summary text,
  preferences jsonb not null default '{}'::jsonb,
  custom_fields jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint customer_crm_profiles_stage_not_blank check (length(trim(customer_stage)) > 0),
  constraint customer_crm_profiles_engagement_range check (engagement_score between 0 and 100),
  constraint customer_crm_profiles_churn_range check (churn_risk_score between 0 and 100),
  constraint customer_crm_profiles_value_nonnegative check (
    lifetime_value_cents >= 0 and average_order_value_cents >= 0 and total_orders >= 0
  ),
  constraint customer_crm_profiles_preferences_object check (jsonb_typeof(preferences) = 'object'),
  constraint customer_crm_profiles_custom_fields_object check (jsonb_typeof(custom_fields) = 'object'),
  constraint customer_crm_profiles_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint customer_crm_profiles_version_positive check (version >= 1)
);

create unique index if not exists customer_crm_profiles_membership_uq
  on public.customer_crm_profiles (membership_id)
  where deleted_at is null;

create unique index if not exists customer_crm_profiles_business_customer_uq
  on public.customer_crm_profiles (business_id, customer_id)
  where deleted_at is null;

create index if not exists customer_crm_profiles_follow_up_idx
  on public.customer_crm_profiles (business_id, next_follow_up_at)
  where deleted_at is null and next_follow_up_at is not null;

create index if not exists customer_crm_profiles_scores_idx
  on public.customer_crm_profiles (business_id, churn_risk_score desc, engagement_score desc)
  where deleted_at is null;

-- =========================================================
-- NOTES
-- =========================================================

create table if not exists public.customer_notes (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  membership_id uuid not null references public.memberships(id) on delete restrict,
  customer_id uuid not null references public.customers(id) on delete restrict,
  author_employee_id uuid references public.employees(id) on delete set null,
  visibility public.crm_note_visibility not null default 'team',
  title text,
  body text not null,
  is_pinned boolean not null default false,
  follow_up_at timestamptz,
  resolved_at timestamptz,
  resolved_by_employee_id uuid references public.employees(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint customer_notes_body_not_blank check (length(trim(body)) > 0),
  constraint customer_notes_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint customer_notes_version_positive check (version >= 1)
);

create index if not exists customer_notes_membership_idx
  on public.customer_notes (membership_id, is_pinned desc, created_at desc)
  where deleted_at is null;

create index if not exists customer_notes_follow_up_idx
  on public.customer_notes (business_id, follow_up_at)
  where deleted_at is null and follow_up_at is not null and resolved_at is null;

-- =========================================================
-- TAGS
-- =========================================================

create table if not exists public.customer_tags (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  code text not null,
  name text not null,
  description text,
  color_hex text,
  is_active boolean not null default true,
  display_order integer not null default 100,
  metadata jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint customer_tags_code_format check (code ~ '^[a-z][a-z0-9_]*$'),
  constraint customer_tags_name_not_blank check (length(trim(name)) > 0),
  constraint customer_tags_color_format check (color_hex is null or color_hex ~ '^#[0-9A-Fa-f]{6}$'),
  constraint customer_tags_display_nonnegative check (display_order >= 0),
  constraint customer_tags_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint customer_tags_version_positive check (version >= 1)
);

create unique index if not exists customer_tags_business_code_uq
  on public.customer_tags (business_id, lower(code))
  where deleted_at is null;

create table if not exists public.customer_tag_assignments (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  membership_id uuid not null references public.memberships(id) on delete restrict,
  customer_id uuid not null references public.customers(id) on delete restrict,
  tag_id uuid not null references public.customer_tags(id) on delete restrict,
  assigned_by_employee_id uuid references public.employees(id) on delete set null,
  source text not null default 'manual',
  metadata jsonb not null default '{}'::jsonb,
  assigned_at timestamptz not null default now(),
  removed_at timestamptz,
  removed_by_employee_id uuid references public.employees(id) on delete set null,
  constraint customer_tag_assignments_source_not_blank check (length(trim(source)) > 0),
  constraint customer_tag_assignments_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint customer_tag_assignments_removed_time check (removed_at is null or removed_at >= assigned_at)
);

create unique index if not exists customer_tag_assignments_active_uq
  on public.customer_tag_assignments (membership_id, tag_id)
  where removed_at is null;

create index if not exists customer_tag_assignments_tag_idx
  on public.customer_tag_assignments (business_id, tag_id, assigned_at desc)
  where removed_at is null;

-- =========================================================
-- SEGMENTS
-- =========================================================

create table if not exists public.customer_segments (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  code text not null,
  name text not null,
  description text,
  segment_type public.crm_segment_type not null default 'static',
  filter_definition jsonb not null default '{}'::jsonb,
  estimated_member_count integer not null default 0,
  is_active boolean not null default true,
  last_refreshed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint customer_segments_code_format check (code ~ '^[a-z][a-z0-9_]*$'),
  constraint customer_segments_name_not_blank check (length(trim(name)) > 0),
  constraint customer_segments_filter_object check (jsonb_typeof(filter_definition) = 'object'),
  constraint customer_segments_count_nonnegative check (estimated_member_count >= 0),
  constraint customer_segments_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint customer_segments_version_positive check (version >= 1)
);

create unique index if not exists customer_segments_business_code_uq
  on public.customer_segments (business_id, lower(code))
  where deleted_at is null;

create table if not exists public.customer_segment_members (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  segment_id uuid not null references public.customer_segments(id) on delete cascade,
  membership_id uuid not null references public.memberships(id) on delete restrict,
  customer_id uuid not null references public.customers(id) on delete restrict,
  source text not null default 'manual',
  matched_snapshot jsonb not null default '{}'::jsonb,
  added_at timestamptz not null default now(),
  removed_at timestamptz,
  constraint customer_segment_members_source_not_blank check (length(trim(source)) > 0),
  constraint customer_segment_members_snapshot_object check (jsonb_typeof(matched_snapshot) = 'object'),
  constraint customer_segment_members_removed_time check (removed_at is null or removed_at >= added_at)
);

create unique index if not exists customer_segment_members_active_uq
  on public.customer_segment_members (segment_id, membership_id)
  where removed_at is null;

create index if not exists customer_segment_members_membership_idx
  on public.customer_segment_members (membership_id, added_at desc)
  where removed_at is null;

-- =========================================================
-- COMMUNICATION CONSENT
-- =========================================================

create table if not exists public.customer_communication_preferences (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  membership_id uuid not null references public.memberships(id) on delete restrict,
  customer_id uuid not null references public.customers(id) on delete restrict,
  channel public.crm_channel not null,
  consent_status public.crm_consent_status not null default 'unknown',
  consent_source text,
  consent_evidence jsonb not null default '{}'::jsonb,
  consented_at timestamptz,
  opted_out_at timestamptz,
  suppression_reason text,
  quiet_hours_start time,
  quiet_hours_end time,
  preferred_send_timezone text,
  version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint customer_comm_preferences_evidence_object check (jsonb_typeof(consent_evidence) = 'object'),
  constraint customer_comm_preferences_version_positive check (version >= 1),
  constraint customer_comm_preferences_consent_time check (
    consent_status <> 'opted_in' or consented_at is not null
  ),
  constraint customer_comm_preferences_optout_time check (
    consent_status <> 'opted_out' or opted_out_at is not null
  )
);

create unique index if not exists customer_comm_preferences_channel_uq
  on public.customer_communication_preferences (membership_id, channel);

-- =========================================================
-- CAMPAIGNS AND MESSAGES
-- =========================================================

create table if not exists public.crm_campaigns (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  location_id uuid references public.business_locations(id) on delete set null,
  segment_id uuid references public.customer_segments(id) on delete set null,
  code text not null,
  name text not null,
  description text,
  channel public.crm_channel not null,
  status public.crm_campaign_status not null default 'draft',
  subject_template text,
  content_template text not null,
  scheduled_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  audience_count integer not null default 0,
  sent_count integer not null default 0,
  delivered_count integer not null default 0,
  failed_count integer not null default 0,
  opened_count integer not null default 0,
  clicked_count integer not null default 0,
  unsubscribed_count integer not null default 0,
  settings jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint crm_campaigns_code_not_blank check (length(trim(code)) > 0),
  constraint crm_campaigns_name_not_blank check (length(trim(name)) > 0),
  constraint crm_campaigns_content_not_blank check (length(trim(content_template)) > 0),
  constraint crm_campaigns_counts_nonnegative check (
    audience_count >= 0 and sent_count >= 0 and delivered_count >= 0
    and failed_count >= 0 and opened_count >= 0 and clicked_count >= 0
    and unsubscribed_count >= 0
  ),
  constraint crm_campaigns_settings_object check (jsonb_typeof(settings) = 'object'),
  constraint crm_campaigns_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint crm_campaigns_version_positive check (version >= 1)
);

create unique index if not exists crm_campaigns_business_code_uq
  on public.crm_campaigns (business_id, lower(code))
  where deleted_at is null;

create index if not exists crm_campaigns_status_schedule_idx
  on public.crm_campaigns (business_id, status, scheduled_at)
  where deleted_at is null;

create table if not exists public.crm_messages (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  location_id uuid references public.business_locations(id) on delete set null,
  campaign_id uuid references public.crm_campaigns(id) on delete set null,
  membership_id uuid not null references public.memberships(id) on delete restrict,
  customer_id uuid not null references public.customers(id) on delete restrict,
  channel public.crm_channel not null,
  status public.crm_message_status not null default 'queued',
  recipient_address text not null,
  subject_rendered text,
  content_rendered text not null,
  provider text,
  provider_message_id text,
  idempotency_key text,
  scheduled_at timestamptz,
  sent_at timestamptz,
  delivered_at timestamptz,
  opened_at timestamptz,
  clicked_at timestamptz,
  failed_at timestamptz,
  failure_code text,
  failure_message text,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint crm_messages_recipient_not_blank check (length(trim(recipient_address)) > 0),
  constraint crm_messages_content_not_blank check (length(trim(content_rendered)) > 0),
  constraint crm_messages_idempotency_not_blank check (idempotency_key is null or length(trim(idempotency_key)) > 0),
  constraint crm_messages_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists crm_messages_idempotency_uq
  on public.crm_messages (business_id, idempotency_key)
  where idempotency_key is not null;

create index if not exists crm_messages_campaign_status_idx
  on public.crm_messages (campaign_id, status, created_at)
  where campaign_id is not null;

create index if not exists crm_messages_membership_idx
  on public.crm_messages (membership_id, created_at desc);

-- =========================================================
-- AUTOMATIONS
-- =========================================================

create table if not exists public.crm_automations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  code text not null,
  name text not null,
  description text,
  status public.crm_automation_status not null default 'draft',
  trigger_type text not null,
  trigger_definition jsonb not null default '{}'::jsonb,
  action_definition jsonb not null default '{}'::jsonb,
  cooldown_minutes integer not null default 0,
  max_runs_per_membership integer,
  last_run_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint crm_automations_code_format check (code ~ '^[a-z][a-z0-9_]*$'),
  constraint crm_automations_name_not_blank check (length(trim(name)) > 0),
  constraint crm_automations_trigger_not_blank check (length(trim(trigger_type)) > 0),
  constraint crm_automations_trigger_object check (jsonb_typeof(trigger_definition) = 'object'),
  constraint crm_automations_action_object check (jsonb_typeof(action_definition) = 'object'),
  constraint crm_automations_cooldown_nonnegative check (cooldown_minutes >= 0),
  constraint crm_automations_max_runs_positive check (max_runs_per_membership is null or max_runs_per_membership >= 1),
  constraint crm_automations_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint crm_automations_version_positive check (version >= 1)
);

create unique index if not exists crm_automations_business_code_uq
  on public.crm_automations (business_id, lower(code))
  where deleted_at is null;

create table if not exists public.crm_automation_runs (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  automation_id uuid not null references public.crm_automations(id) on delete restrict,
  membership_id uuid references public.memberships(id) on delete restrict,
  customer_id uuid references public.customers(id) on delete restrict,
  trigger_event_type text not null,
  trigger_event_id uuid,
  status text not null default 'queued',
  idempotency_key text,
  input_payload jsonb not null default '{}'::jsonb,
  output_payload jsonb,
  error_message text,
  queued_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  constraint crm_automation_runs_event_not_blank check (length(trim(trigger_event_type)) > 0),
  constraint crm_automation_runs_status_not_blank check (length(trim(status)) > 0),
  constraint crm_automation_runs_input_object check (jsonb_typeof(input_payload) = 'object'),
  constraint crm_automation_runs_output_object check (output_payload is null or jsonb_typeof(output_payload) = 'object')
);

create unique index if not exists crm_automation_runs_idempotency_uq
  on public.crm_automation_runs (business_id, idempotency_key)
  where idempotency_key is not null;

-- =========================================================
-- REFERRALS AND LEADS
-- =========================================================

create table if not exists public.crm_referrals (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  referrer_membership_id uuid not null references public.memberships(id) on delete restrict,
  referred_customer_id uuid references public.customers(id) on delete set null,
  referred_membership_id uuid references public.memberships(id) on delete set null,
  referral_code text not null,
  status text not null default 'invited',
  channel public.crm_channel,
  reward_ledger_entry_id uuid references public.loyalty_ledger(id) on delete set null,
  invited_at timestamptz not null default now(),
  accepted_at timestamptz,
  converted_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  constraint crm_referrals_code_not_blank check (length(trim(referral_code)) > 0),
  constraint crm_referrals_status_not_blank check (length(trim(status)) > 0),
  constraint crm_referrals_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists crm_referrals_business_code_uq
  on public.crm_referrals (business_id, lower(referral_code));

create table if not exists public.crm_leads (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  location_id uuid references public.business_locations(id) on delete set null,
  converted_customer_id uuid references public.customers(id) on delete set null,
  converted_membership_id uuid references public.memberships(id) on delete set null,
  assigned_employee_id uuid references public.employees(id) on delete set null,
  first_name text,
  last_name text,
  email text,
  phone text,
  source text,
  status public.crm_lead_status not null default 'new',
  estimated_value_cents bigint not null default 0,
  notes text,
  next_follow_up_at timestamptz,
  converted_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint crm_leads_identity_check check (
    coalesce(length(trim(first_name)),0) > 0
    or coalesce(length(trim(last_name)),0) > 0
    or coalesce(length(trim(email)),0) > 0
    or coalesce(length(trim(phone)),0) > 0
  ),
  constraint crm_leads_value_nonnegative check (estimated_value_cents >= 0),
  constraint crm_leads_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint crm_leads_version_positive check (version >= 1),
  constraint crm_leads_conversion_state check (
    status <> 'converted'
    or (converted_customer_id is not null and converted_membership_id is not null and converted_at is not null)
  )
);

create index if not exists crm_leads_status_follow_up_idx
  on public.crm_leads (business_id, status, next_follow_up_at)
  where deleted_at is null;

-- =========================================================
-- APPEND-ONLY CUSTOMER TIMELINE
-- =========================================================

create table if not exists public.customer_timeline_events (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  location_id uuid references public.business_locations(id) on delete set null,
  membership_id uuid not null references public.memberships(id) on delete restrict,
  customer_id uuid not null references public.customers(id) on delete restrict,
  event_type public.crm_timeline_event_type not null,
  event_code text,
  title text not null,
  description text,
  source_table text,
  source_id uuid,
  actor_employee_id uuid references public.employees(id) on delete set null,
  occurred_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint customer_timeline_events_title_not_blank check (length(trim(title)) > 0),
  constraint customer_timeline_events_code_not_blank check (event_code is null or length(trim(event_code)) > 0),
  constraint customer_timeline_events_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create index if not exists customer_timeline_events_membership_idx
  on public.customer_timeline_events (membership_id, occurred_at desc, created_at desc);

create index if not exists customer_timeline_events_business_type_idx
  on public.customer_timeline_events (business_id, event_type, occurred_at desc);

-- =========================================================
-- RELATIONSHIP VALIDATION
-- =========================================================

create or replace function public.validate_crm_membership_customer(
  p_business_id uuid,
  p_membership_id uuid,
  p_customer_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.memberships m
    where m.id = p_membership_id
      and m.business_id = p_business_id
      and m.customer_id = p_customer_id
      and m.deleted_at is null
  );
$$;

create or replace function public.validate_customer_crm_profile_relationships()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not public.validate_crm_membership_customer(new.business_id, new.membership_id, new.customer_id) then
    raise exception 'CRM profile membership and customer must belong to the same business.';
  end if;

  if new.preferred_location_id is not null and not exists (
    select 1 from public.business_locations l
    where l.id = new.preferred_location_id
      and l.business_id = new.business_id
      and l.deleted_at is null
  ) then
    raise exception 'Preferred location must belong to the same business.';
  end if;

  if new.assigned_employee_id is not null and not exists (
    select 1 from public.employees e
    where e.id = new.assigned_employee_id
      and e.business_id = new.business_id
      and e.deleted_at is null
  ) then
    raise exception 'Assigned employee must belong to the same business.';
  end if;

  return new;
end;
$$;

create or replace function public.validate_crm_membership_row()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not public.validate_crm_membership_customer(new.business_id, new.membership_id, new.customer_id) then
    raise exception 'CRM membership and customer must belong to the same business.';
  end if;
  return new;
end;
$$;

create or replace function public.validate_customer_tag_assignment()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not public.validate_crm_membership_customer(new.business_id, new.membership_id, new.customer_id) then
    raise exception 'Tag assignment membership and customer must belong to the same business.';
  end if;

  if not exists (
    select 1 from public.customer_tags t
    where t.id = new.tag_id
      and t.business_id = new.business_id
      and t.deleted_at is null
  ) then
    raise exception 'Tag must belong to the same business.';
  end if;

  return new;
end;
$$;

create or replace function public.validate_customer_segment_member()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not public.validate_crm_membership_customer(new.business_id, new.membership_id, new.customer_id) then
    raise exception 'Segment membership and customer must belong to the same business.';
  end if;

  if not exists (
    select 1 from public.customer_segments s
    where s.id = new.segment_id
      and s.business_id = new.business_id
      and s.deleted_at is null
  ) then
    raise exception 'Segment must belong to the same business.';
  end if;

  return new;
end;
$$;

create or replace function public.prevent_crm_timeline_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  raise exception 'Customer timeline events are append-only.';
end;
$$;

-- =========================================================
-- TIMELINE RPC
-- =========================================================

create or replace function public.post_customer_timeline_event(
  p_business_id uuid,
  p_membership_id uuid,
  p_customer_id uuid,
  p_event_type public.crm_timeline_event_type,
  p_title text,
  p_description text default null,
  p_location_id uuid default null,
  p_event_code text default null,
  p_source_table text default null,
  p_source_id uuid default null,
  p_actor_employee_id uuid default null,
  p_occurred_at timestamptz default now(),
  p_metadata jsonb default '{}'::jsonb
)
returns public.customer_timeline_events
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_event public.customer_timeline_events%rowtype;
begin
  if not public.validate_crm_membership_customer(p_business_id, p_membership_id, p_customer_id) then
    raise exception 'Membership and customer do not belong to this business.';
  end if;

  if p_title is null or length(trim(p_title)) = 0 then
    raise exception 'Timeline title is required.';
  end if;

  if p_metadata is null or jsonb_typeof(p_metadata) <> 'object' then
    raise exception 'Timeline metadata must be a JSON object.';
  end if;

  if auth.uid() is not null and not public.has_permission(p_business_id, 'crm.manage', p_location_id) then
    raise exception 'Permission denied to post CRM timeline events.';
  end if;

  insert into public.customer_timeline_events (
    business_id, location_id, membership_id, customer_id,
    event_type, event_code, title, description,
    source_table, source_id, actor_employee_id,
    occurred_at, metadata, created_by
  )
  values (
    p_business_id, p_location_id, p_membership_id, p_customer_id,
    p_event_type, p_event_code, trim(p_title), p_description,
    p_source_table, p_source_id, p_actor_employee_id,
    coalesce(p_occurred_at, now()), p_metadata, auth.uid()
  )
  returning * into v_event;

  return v_event;
end;
$$;

-- =========================================================
-- CRM PROFILE REFRESH RPC
-- =========================================================

create or replace function public.refresh_customer_crm_metrics(
  p_business_id uuid,
  p_membership_id uuid
)
returns public.customer_crm_profiles
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_membership public.memberships%rowtype;
  v_orders integer;
  v_spend bigint;
  v_last_purchase timestamptz;
  v_profile public.customer_crm_profiles%rowtype;
begin
  select * into v_membership
  from public.memberships
  where id = p_membership_id
    and business_id = p_business_id
    and deleted_at is null;

  if not found then
    raise exception 'Membership not found.';
  end if;

  if auth.uid() is not null and not public.has_permission(p_business_id, 'crm.manage') then
    raise exception 'Permission denied to refresh CRM metrics.';
  end if;

  select
    count(*)::integer,
    coalesce(sum(total_cents - refunded_cents), 0)::bigint,
    max(completed_at)
  into v_orders, v_spend, v_last_purchase
  from public.transactions
  where business_id = p_business_id
    and membership_id = p_membership_id
    and status in ('completed','partially_refunded','refunded');

  insert into public.customer_crm_profiles (
    business_id, membership_id, customer_id,
    lifetime_value_cents, average_order_value_cents,
    total_orders, last_purchase_at, created_by, updated_by
  )
  values (
    p_business_id, v_membership.id, v_membership.customer_id,
    greatest(v_spend,0),
    case when v_orders > 0 then greatest(v_spend,0) / v_orders else 0 end,
    v_orders, v_last_purchase, auth.uid(), auth.uid()
  )
  on conflict (membership_id) where deleted_at is null
  do update set
    lifetime_value_cents = excluded.lifetime_value_cents,
    average_order_value_cents = excluded.average_order_value_cents,
    total_orders = excluded.total_orders,
    last_purchase_at = excluded.last_purchase_at,
    updated_by = auth.uid(),
    updated_at = now()
  returning * into v_profile;

  return v_profile;
end;
$$;

-- =========================================================
-- TRIGGERS
-- =========================================================

drop trigger if exists customer_crm_profiles_validate on public.customer_crm_profiles;
create trigger customer_crm_profiles_validate
before insert or update on public.customer_crm_profiles
for each row execute function public.validate_customer_crm_profile_relationships();

drop trigger if exists customer_notes_validate on public.customer_notes;
create trigger customer_notes_validate
before insert or update on public.customer_notes
for each row execute function public.validate_crm_membership_row();

drop trigger if exists customer_tag_assignments_validate on public.customer_tag_assignments;
create trigger customer_tag_assignments_validate
before insert or update on public.customer_tag_assignments
for each row execute function public.validate_customer_tag_assignment();

drop trigger if exists customer_segment_members_validate on public.customer_segment_members;
create trigger customer_segment_members_validate
before insert or update on public.customer_segment_members
for each row execute function public.validate_customer_segment_member();

drop trigger if exists customer_comm_preferences_validate on public.customer_communication_preferences;
create trigger customer_comm_preferences_validate
before insert or update on public.customer_communication_preferences
for each row execute function public.validate_crm_membership_row();

drop trigger if exists crm_messages_validate on public.crm_messages;
create trigger crm_messages_validate
before insert or update on public.crm_messages
for each row execute function public.validate_crm_membership_row();

drop trigger if exists customer_timeline_events_validate on public.customer_timeline_events;
create trigger customer_timeline_events_validate
before insert on public.customer_timeline_events
for each row execute function public.validate_crm_membership_row();

drop trigger if exists customer_timeline_events_block_update on public.customer_timeline_events;
create trigger customer_timeline_events_block_update
before update on public.customer_timeline_events
for each row execute function public.prevent_crm_timeline_mutation();

drop trigger if exists customer_timeline_events_block_delete on public.customer_timeline_events;
create trigger customer_timeline_events_block_delete
before delete on public.customer_timeline_events
for each row execute function public.prevent_crm_timeline_mutation();

-- Business immutability
drop trigger if exists customer_crm_profiles_prevent_business_change on public.customer_crm_profiles;
create trigger customer_crm_profiles_prevent_business_change
before update on public.customer_crm_profiles
for each row execute function public.prevent_business_id_change();

drop trigger if exists customer_notes_prevent_business_change on public.customer_notes;
create trigger customer_notes_prevent_business_change
before update on public.customer_notes
for each row execute function public.prevent_business_id_change();

drop trigger if exists customer_tags_prevent_business_change on public.customer_tags;
create trigger customer_tags_prevent_business_change
before update on public.customer_tags
for each row execute function public.prevent_business_id_change();

drop trigger if exists customer_segments_prevent_business_change on public.customer_segments;
create trigger customer_segments_prevent_business_change
before update on public.customer_segments
for each row execute function public.prevent_business_id_change();

drop trigger if exists crm_campaigns_prevent_business_change on public.crm_campaigns;
create trigger crm_campaigns_prevent_business_change
before update on public.crm_campaigns
for each row execute function public.prevent_business_id_change();

drop trigger if exists crm_automations_prevent_business_change on public.crm_automations;
create trigger crm_automations_prevent_business_change
before update on public.crm_automations
for each row execute function public.prevent_business_id_change();

drop trigger if exists crm_leads_prevent_business_change on public.crm_leads;
create trigger crm_leads_prevent_business_change
before update on public.crm_leads
for each row execute function public.prevent_business_id_change();

-- Updated-at triggers
drop trigger if exists customer_crm_profiles_set_updated_at on public.customer_crm_profiles;
create trigger customer_crm_profiles_set_updated_at
before update on public.customer_crm_profiles
for each row execute function public.set_updated_at();

drop trigger if exists customer_notes_set_updated_at on public.customer_notes;
create trigger customer_notes_set_updated_at
before update on public.customer_notes
for each row execute function public.set_updated_at();

drop trigger if exists customer_tags_set_updated_at on public.customer_tags;
create trigger customer_tags_set_updated_at
before update on public.customer_tags
for each row execute function public.set_updated_at();

drop trigger if exists customer_segments_set_updated_at on public.customer_segments;
create trigger customer_segments_set_updated_at
before update on public.customer_segments
for each row execute function public.set_updated_at();

drop trigger if exists customer_comm_preferences_set_updated_at on public.customer_communication_preferences;
create trigger customer_comm_preferences_set_updated_at
before update on public.customer_communication_preferences
for each row execute function public.set_updated_at();

drop trigger if exists crm_campaigns_set_updated_at on public.crm_campaigns;
create trigger crm_campaigns_set_updated_at
before update on public.crm_campaigns
for each row execute function public.set_updated_at();

drop trigger if exists crm_automations_set_updated_at on public.crm_automations;
create trigger crm_automations_set_updated_at
before update on public.crm_automations
for each row execute function public.set_updated_at();

drop trigger if exists crm_leads_set_updated_at on public.crm_leads;
create trigger crm_leads_set_updated_at
before update on public.crm_leads
for each row execute function public.set_updated_at();

-- Version triggers
drop trigger if exists customer_crm_profiles_increment_version on public.customer_crm_profiles;
create trigger customer_crm_profiles_increment_version
before update on public.customer_crm_profiles
for each row execute function public.increment_record_version();

drop trigger if exists customer_notes_increment_version on public.customer_notes;
create trigger customer_notes_increment_version
before update on public.customer_notes
for each row execute function public.increment_record_version();

drop trigger if exists customer_tags_increment_version on public.customer_tags;
create trigger customer_tags_increment_version
before update on public.customer_tags
for each row execute function public.increment_record_version();

drop trigger if exists customer_segments_increment_version on public.customer_segments;
create trigger customer_segments_increment_version
before update on public.customer_segments
for each row execute function public.increment_record_version();

drop trigger if exists customer_comm_preferences_increment_version on public.customer_communication_preferences;
create trigger customer_comm_preferences_increment_version
before update on public.customer_communication_preferences
for each row execute function public.increment_record_version();

drop trigger if exists crm_campaigns_increment_version on public.crm_campaigns;
create trigger crm_campaigns_increment_version
before update on public.crm_campaigns
for each row execute function public.increment_record_version();

drop trigger if exists crm_automations_increment_version on public.crm_automations;
create trigger crm_automations_increment_version
before update on public.crm_automations
for each row execute function public.increment_record_version();

drop trigger if exists crm_leads_increment_version on public.crm_leads;
create trigger crm_leads_increment_version
before update on public.crm_leads
for each row execute function public.increment_record_version();

-- =========================================================
-- DEFAULT TAGS AND ROLE PERMISSIONS
-- =========================================================

insert into public.customer_tags (
  business_id, code, name, description, display_order
)
select b.id, v.code, v.name, v.description, v.display_order
from public.businesses b
cross join (
  values
    ('vip', 'VIP', 'High-value or priority customer.', 10),
    ('birthday', 'Birthday', 'Customer eligible for birthday engagement.', 20),
    ('regular', 'Regular', 'Frequently returning customer.', 30),
    ('at_risk', 'At Risk', 'Customer showing signs of churn.', 40),
    ('do_not_contact', 'Do Not Contact', 'Customer requires communication suppression.', 50)
) as v(code, name, description, display_order)
where b.deleted_at is null
  and not exists (
    select 1 from public.customer_tags t
    where t.business_id = b.id
      and lower(t.code) = lower(v.code)
      and t.deleted_at is null
  );

create or replace function public.provision_crm_role_permissions(p_business_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
begin
  insert into public.role_permissions (business_id, role_id, permission_id)
  select p_business_id, r.id, p.id
  from public.business_roles r
  cross join public.permissions p
  where r.business_id = p_business_id
    and r.deleted_at is null
    and r.code in ('owner','administrator')
    and p.module = 'crm'
    and not exists (
      select 1 from public.role_permissions rp
      where rp.role_id = r.id and rp.permission_id = p.id
    );

  insert into public.role_permissions (business_id, role_id, permission_id)
  select p_business_id, r.id, p.id
  from public.business_roles r
  cross join public.permissions p
  where r.business_id = p_business_id
    and r.deleted_at is null
    and r.code = 'manager'
    and p.code in (
      'crm.read','crm.manage','crm.notes_private','crm.marketing_read',
      'crm.marketing_manage','crm.consent_manage','crm.leads_manage'
    )
    and not exists (
      select 1 from public.role_permissions rp
      where rp.role_id = r.id and rp.permission_id = p.id
    );

  insert into public.role_permissions (business_id, role_id, permission_id)
  select p_business_id, r.id, p.id
  from public.business_roles r
  cross join public.permissions p
  where r.business_id = p_business_id
    and r.deleted_at is null
    and r.code in ('cashier','staff')
    and p.code in ('crm.read')
    and not exists (
      select 1 from public.role_permissions rp
      where rp.role_id = r.id and rp.permission_id = p.id
    );

  insert into public.role_permissions (business_id, role_id, permission_id)
  select p_business_id, r.id, p.id
  from public.business_roles r
  cross join public.permissions p
  where r.business_id = p_business_id
    and r.deleted_at is null
    and r.code = 'auditor'
    and p.code in ('crm.read','crm.marketing_read')
    and not exists (
      select 1 from public.role_permissions rp
      where rp.role_id = r.id and rp.permission_id = p.id
    );
end;
$$;

select public.provision_crm_role_permissions(b.id)
from public.businesses b
where b.deleted_at is null;

-- =========================================================
-- ROW LEVEL SECURITY
-- =========================================================

alter table public.customer_crm_profiles enable row level security;
alter table public.customer_crm_profiles force row level security;
alter table public.customer_notes enable row level security;
alter table public.customer_notes force row level security;
alter table public.customer_tags enable row level security;
alter table public.customer_tags force row level security;
alter table public.customer_tag_assignments enable row level security;
alter table public.customer_tag_assignments force row level security;
alter table public.customer_segments enable row level security;
alter table public.customer_segments force row level security;
alter table public.customer_segment_members enable row level security;
alter table public.customer_segment_members force row level security;
alter table public.customer_communication_preferences enable row level security;
alter table public.customer_communication_preferences force row level security;
alter table public.crm_campaigns enable row level security;
alter table public.crm_campaigns force row level security;
alter table public.crm_messages enable row level security;
alter table public.crm_messages force row level security;
alter table public.crm_automations enable row level security;
alter table public.crm_automations force row level security;
alter table public.crm_automation_runs enable row level security;
alter table public.crm_automation_runs force row level security;
alter table public.crm_referrals enable row level security;
alter table public.crm_referrals force row level security;
alter table public.crm_leads enable row level security;
alter table public.crm_leads force row level security;
alter table public.customer_timeline_events enable row level security;
alter table public.customer_timeline_events force row level security;

-- Standard CRM read/manage
drop policy if exists customer_crm_profiles_read on public.customer_crm_profiles;
create policy customer_crm_profiles_read on public.customer_crm_profiles
for select to authenticated
using (public.has_permission(business_id, 'crm.read'));

drop policy if exists customer_crm_profiles_manage on public.customer_crm_profiles;
create policy customer_crm_profiles_manage on public.customer_crm_profiles
to authenticated
using (public.has_permission(business_id, 'crm.manage'))
with check (public.has_permission(business_id, 'crm.manage'));

drop policy if exists customer_notes_read on public.customer_notes;
create policy customer_notes_read on public.customer_notes
for select to authenticated
using (
  public.has_permission(business_id, 'crm.read')
  and (
    visibility <> 'private'
    or public.has_permission(business_id, 'crm.notes_private')
    or author_employee_id = public.current_employee_id(business_id)
  )
);

drop policy if exists customer_notes_manage on public.customer_notes;
create policy customer_notes_manage on public.customer_notes
to authenticated
using (
  public.has_permission(business_id, 'crm.manage')
  and (
    visibility <> 'private'
    or public.has_permission(business_id, 'crm.notes_private')
    or author_employee_id = public.current_employee_id(business_id)
  )
)
with check (
  public.has_permission(business_id, 'crm.manage')
  and (
    visibility <> 'private'
    or public.has_permission(business_id, 'crm.notes_private')
    or author_employee_id = public.current_employee_id(business_id)
  )
);

drop policy if exists customer_tags_read on public.customer_tags;
create policy customer_tags_read on public.customer_tags
for select to authenticated
using (public.has_permission(business_id, 'crm.read'));

drop policy if exists customer_tags_manage on public.customer_tags;
create policy customer_tags_manage on public.customer_tags
to authenticated
using (public.has_permission(business_id, 'crm.manage'))
with check (public.has_permission(business_id, 'crm.manage'));

drop policy if exists customer_tag_assignments_read on public.customer_tag_assignments;
create policy customer_tag_assignments_read on public.customer_tag_assignments
for select to authenticated
using (public.has_permission(business_id, 'crm.read'));

drop policy if exists customer_tag_assignments_manage on public.customer_tag_assignments;
create policy customer_tag_assignments_manage on public.customer_tag_assignments
to authenticated
using (public.has_permission(business_id, 'crm.manage'))
with check (public.has_permission(business_id, 'crm.manage'));

drop policy if exists customer_segments_read on public.customer_segments;
create policy customer_segments_read on public.customer_segments
for select to authenticated
using (public.has_permission(business_id, 'crm.read'));

drop policy if exists customer_segments_manage on public.customer_segments;
create policy customer_segments_manage on public.customer_segments
to authenticated
using (public.has_permission(business_id, 'crm.manage'))
with check (public.has_permission(business_id, 'crm.manage'));

drop policy if exists customer_segment_members_read on public.customer_segment_members;
create policy customer_segment_members_read on public.customer_segment_members
for select to authenticated
using (public.has_permission(business_id, 'crm.read'));

drop policy if exists customer_segment_members_manage on public.customer_segment_members;
create policy customer_segment_members_manage on public.customer_segment_members
to authenticated
using (public.has_permission(business_id, 'crm.manage'))
with check (public.has_permission(business_id, 'crm.manage'));

drop policy if exists customer_comm_preferences_read on public.customer_communication_preferences;
create policy customer_comm_preferences_read on public.customer_communication_preferences
for select to authenticated
using (
  public.has_permission(business_id, 'crm.read')
  or public.has_permission(business_id, 'crm.marketing_read')
);

drop policy if exists customer_comm_preferences_manage on public.customer_communication_preferences;
create policy customer_comm_preferences_manage on public.customer_communication_preferences
to authenticated
using (public.has_permission(business_id, 'crm.consent_manage'))
with check (public.has_permission(business_id, 'crm.consent_manage'));

drop policy if exists crm_campaigns_read on public.crm_campaigns;
create policy crm_campaigns_read on public.crm_campaigns
for select to authenticated
using (public.has_permission(business_id, 'crm.marketing_read', location_id));

drop policy if exists crm_campaigns_manage on public.crm_campaigns;
create policy crm_campaigns_manage on public.crm_campaigns
to authenticated
using (public.has_permission(business_id, 'crm.marketing_manage', location_id))
with check (public.has_permission(business_id, 'crm.marketing_manage', location_id));

drop policy if exists crm_messages_read on public.crm_messages;
create policy crm_messages_read on public.crm_messages
for select to authenticated
using (public.has_permission(business_id, 'crm.marketing_read', location_id));

drop policy if exists crm_messages_manage on public.crm_messages;
create policy crm_messages_manage on public.crm_messages
to authenticated
using (public.has_permission(business_id, 'crm.marketing_manage', location_id))
with check (public.has_permission(business_id, 'crm.marketing_manage', location_id));

drop policy if exists crm_automations_read on public.crm_automations;
create policy crm_automations_read on public.crm_automations
for select to authenticated
using (public.has_permission(business_id, 'crm.marketing_read'));

drop policy if exists crm_automations_manage on public.crm_automations;
create policy crm_automations_manage on public.crm_automations
to authenticated
using (public.has_permission(business_id, 'crm.marketing_manage'))
with check (public.has_permission(business_id, 'crm.marketing_manage'));

drop policy if exists crm_automation_runs_read on public.crm_automation_runs;
create policy crm_automation_runs_read on public.crm_automation_runs
for select to authenticated
using (public.has_permission(business_id, 'crm.marketing_read'));

drop policy if exists crm_automation_runs_manage on public.crm_automation_runs;
create policy crm_automation_runs_manage on public.crm_automation_runs
to authenticated
using (public.has_permission(business_id, 'crm.marketing_manage'))
with check (public.has_permission(business_id, 'crm.marketing_manage'));

drop policy if exists crm_referrals_read on public.crm_referrals;
create policy crm_referrals_read on public.crm_referrals
for select to authenticated
using (public.has_permission(business_id, 'crm.read'));

drop policy if exists crm_referrals_manage on public.crm_referrals;
create policy crm_referrals_manage on public.crm_referrals
to authenticated
using (public.has_permission(business_id, 'crm.leads_manage'))
with check (public.has_permission(business_id, 'crm.leads_manage'));

drop policy if exists crm_leads_read on public.crm_leads;
create policy crm_leads_read on public.crm_leads
for select to authenticated
using (public.has_permission(business_id, 'crm.read', location_id));

drop policy if exists crm_leads_manage on public.crm_leads;
create policy crm_leads_manage on public.crm_leads
to authenticated
using (public.has_permission(business_id, 'crm.leads_manage', location_id))
with check (public.has_permission(business_id, 'crm.leads_manage', location_id));

drop policy if exists customer_timeline_events_read on public.customer_timeline_events;
create policy customer_timeline_events_read on public.customer_timeline_events
for select to authenticated
using (public.has_permission(business_id, 'crm.read', location_id));

-- Timeline inserts are performed through the secured RPC.
-- No direct authenticated insert/update/delete policy is intentionally provided.

-- =========================================================
-- GRANTS
-- =========================================================

grant select, insert, update on public.customer_crm_profiles to authenticated;
grant select, insert, update on public.customer_notes to authenticated;
grant select, insert, update on public.customer_tags to authenticated;
grant select, insert, update on public.customer_tag_assignments to authenticated;
grant select, insert, update on public.customer_segments to authenticated;
grant select, insert, update on public.customer_segment_members to authenticated;
grant select, insert, update on public.customer_communication_preferences to authenticated;
grant select, insert, update on public.crm_campaigns to authenticated;
grant select, insert, update on public.crm_messages to authenticated;
grant select, insert, update on public.crm_automations to authenticated;
grant select, insert, update on public.crm_automation_runs to authenticated;
grant select, insert, update on public.crm_referrals to authenticated;
grant select, insert, update on public.crm_leads to authenticated;
grant select on public.customer_timeline_events to authenticated;

grant execute on function public.post_customer_timeline_event(
  uuid,uuid,uuid,public.crm_timeline_event_type,text,text,uuid,text,text,uuid,uuid,timestamptz,jsonb
) to authenticated;

grant execute on function public.refresh_customer_crm_metrics(uuid,uuid) to authenticated;

comment on table public.customer_crm_profiles is
  'Business-specific CRM intelligence and operational profile attached to a membership.';
comment on table public.customer_notes is
  'Employee-authored customer notes with team, management, or private visibility.';
comment on table public.customer_tags is
  'Tenant-defined reusable customer classification tags.';
comment on table public.customer_segments is
  'Static or dynamic CRM audiences used for analysis and campaigns.';
comment on table public.customer_communication_preferences is
  'Per-business, per-channel customer consent and communication preferences.';
comment on table public.crm_campaigns is
  'Marketing campaign definitions, schedules, and aggregate delivery metrics.';
comment on table public.crm_messages is
  'Individual customer communication delivery ledger.';
comment on table public.crm_automations is
  'Configurable trigger-and-action customer marketing automation definitions.';
comment on table public.crm_referrals is
  'Referral invitations and conversion lifecycle.';
comment on table public.crm_leads is
  'Prospective customers before conversion into platform customer and membership records.';
comment on table public.customer_timeline_events is
  'Append-only customer activity timeline spanning CRM, sales, visits, loyalty, and messaging.';

commit;
