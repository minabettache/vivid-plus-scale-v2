-- =========================================================
-- VIVID+ MIGRATION 013
-- AI BUSINESS INTELLIGENCE CORE
-- Model registry, feature snapshots, forecasts, anomaly
-- detection, recommendations, executive insights, AI jobs,
-- assistant query history, feedback, and secure tenant RLS.
-- =========================================================

begin;

-- =========================================================
-- ENUMS
-- =========================================================

do $$ begin
  create type public.ai_model_status as enum (
    'draft','training','active','paused','retired','failed'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.ai_model_type as enum (
    'forecasting','classification','regression','ranking',
    'anomaly_detection','recommendation','language'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.ai_job_status as enum (
    'queued','running','succeeded','failed','cancelled'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.ai_job_type as enum (
    'feature_refresh','model_training','forecast_generation',
    'anomaly_scan','recommendation_generation','insight_generation',
    'assistant_query','backfill'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.ai_forecast_granularity as enum (
    'hour','day','week','month'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.ai_forecast_metric as enum (
    'revenue','transactions','units_sold','gross_profit',
    'customer_visits','inventory_demand','cash_flow'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.ai_anomaly_type as enum (
    'revenue_drop','revenue_spike','refund_spike','discount_abuse',
    'cash_variance','inventory_shrinkage','inventory_overstock',
    'inventory_stockout_risk','employee_risk','customer_churn',
    'payment_failure','margin_drop','custom'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.ai_severity as enum (
    'info','low','medium','high','critical'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.ai_recommendation_type as enum (
    'reorder_inventory','reduce_inventory','adjust_price',
    'launch_promotion','contact_customer','offer_reward',
    'review_employee_activity','review_refunds','review_cash',
    'optimize_schedule','custom'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.ai_recommendation_status as enum (
    'new','reviewed','accepted','dismissed','implemented','expired'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.ai_insight_type as enum (
    'sales','profitability','inventory','customer','employee',
    'marketing','finance','operations','risk','custom'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.ai_feedback_rating as enum (
    'helpful','not_helpful','incorrect','unsafe','other'
  );
exception when duplicate_object then null; end $$;

-- =========================================================
-- PERMISSIONS
-- =========================================================

insert into public.permissions (code, module, description, is_sensitive)
values
  ('ai.read',                 'ai', 'View AI forecasts, recommendations, anomalies, and insights.', true),
  ('ai.manage',               'ai', 'Manage AI models, jobs, settings, and model lifecycle.', true),
  ('ai.run',                  'ai', 'Run AI feature refreshes, scans, forecasts, and recommendations.', true),
  ('ai.assistant',            'ai', 'Use the VIVID+ AI business assistant.', true),
  ('ai.feedback',             'ai', 'Submit feedback on AI outputs.', false),
  ('ai.override',             'ai', 'Override, accept, dismiss, or implement AI recommendations.', true),
  ('ai.export',               'ai', 'Export AI datasets, forecasts, and model outputs.', true),
  ('ai.audit',                'ai', 'View sensitive AI execution, lineage, and audit records.', true)
on conflict ((lower(code))) do update
set module = excluded.module,
    description = excluded.description,
    is_sensitive = excluded.is_sensitive;

-- =========================================================
-- MODEL REGISTRY
-- =========================================================

create table if not exists public.ai_models (
  id uuid primary key default gen_random_uuid(),
  business_id uuid references public.businesses(id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  model_type public.ai_model_type not null,
  version text not null default '1.0.0',
  status public.ai_model_status not null default 'draft',
  provider text,
  provider_model text,
  endpoint_reference text,
  feature_schema jsonb not null default '{}'::jsonb,
  output_schema jsonb not null default '{}'::jsonb,
  training_config jsonb not null default '{}'::jsonb,
  runtime_config jsonb not null default '{}'::jsonb,
  evaluation_metrics jsonb not null default '{}'::jsonb,
  trained_at timestamptz,
  activated_at timestamptz,
  retired_at timestamptz,
  last_error text,
  metadata jsonb not null default '{}'::jsonb,
  record_version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint ai_models_code_format check (code ~ '^[a-z][a-z0-9_]*$'),
  constraint ai_models_name_not_blank check (length(trim(name)) > 0),
  constraint ai_models_version_not_blank check (length(trim(version)) > 0),
  constraint ai_models_feature_schema_object check (jsonb_typeof(feature_schema) = 'object'),
  constraint ai_models_output_schema_object check (jsonb_typeof(output_schema) = 'object'),
  constraint ai_models_training_config_object check (jsonb_typeof(training_config) = 'object'),
  constraint ai_models_runtime_config_object check (jsonb_typeof(runtime_config) = 'object'),
  constraint ai_models_evaluation_metrics_object check (jsonb_typeof(evaluation_metrics) = 'object'),
  constraint ai_models_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint ai_models_record_version_positive check (record_version >= 1)
);

create unique index if not exists ai_models_global_code_version_uq
  on public.ai_models (coalesce(business_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(code), lower(version))
  where deleted_at is null;

create index if not exists ai_models_business_status_idx
  on public.ai_models (business_id, status, model_type)
  where deleted_at is null;

-- =========================================================
-- FEATURE DEFINITIONS AND SNAPSHOTS
-- =========================================================

create table if not exists public.ai_feature_definitions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid references public.businesses(id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  entity_type text not null,
  data_type text not null,
  expression_sql text,
  source_tables text[] not null default '{}',
  refresh_interval_minutes integer,
  is_sensitive boolean not null default false,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  record_version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint ai_feature_definitions_code_format check (code ~ '^[a-z][a-z0-9_]*$'),
  constraint ai_feature_definitions_name_not_blank check (length(trim(name)) > 0),
  constraint ai_feature_definitions_entity_not_blank check (length(trim(entity_type)) > 0),
  constraint ai_feature_definitions_type_not_blank check (length(trim(data_type)) > 0),
  constraint ai_feature_definitions_refresh_positive check (
    refresh_interval_minutes is null or refresh_interval_minutes >= 1
  ),
  constraint ai_feature_definitions_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint ai_feature_definitions_record_version_positive check (record_version >= 1)
);

create unique index if not exists ai_feature_definitions_scope_code_uq
  on public.ai_feature_definitions (
    coalesce(business_id, '00000000-0000-0000-0000-000000000000'::uuid),
    lower(code)
  )
  where deleted_at is null;

create table if not exists public.ai_feature_snapshots (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  location_id uuid references public.business_locations(id) on delete set null,
  feature_definition_id uuid references public.ai_feature_definitions(id) on delete set null,
  entity_type text not null,
  entity_id uuid,
  feature_code text not null,
  numeric_value numeric(24,8),
  text_value text,
  boolean_value boolean,
  json_value jsonb,
  effective_at timestamptz not null,
  expires_at timestamptz,
  source_hash text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint ai_feature_snapshots_entity_not_blank check (length(trim(entity_type)) > 0),
  constraint ai_feature_snapshots_code_not_blank check (length(trim(feature_code)) > 0),
  constraint ai_feature_snapshots_exactly_one_value check (
    num_nonnulls(numeric_value, text_value, boolean_value, json_value) = 1
  ),
  constraint ai_feature_snapshots_json_valid check (
    json_value is null or jsonb_typeof(json_value) in ('object','array','string','number','boolean')
  ),
  constraint ai_feature_snapshots_time_check check (
    expires_at is null or expires_at > effective_at
  ),
  constraint ai_feature_snapshots_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create index if not exists ai_feature_snapshots_entity_idx
  on public.ai_feature_snapshots (
    business_id, entity_type, entity_id, feature_code, effective_at desc
  );

create index if not exists ai_feature_snapshots_location_idx
  on public.ai_feature_snapshots (
    business_id, location_id, feature_code, effective_at desc
  )
  where location_id is not null;

-- =========================================================
-- AI JOBS
-- =========================================================

create table if not exists public.ai_jobs (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  location_id uuid references public.business_locations(id) on delete set null,
  model_id uuid references public.ai_models(id) on delete set null,
  job_type public.ai_job_type not null,
  status public.ai_job_status not null default 'queued',
  priority integer not null default 100,
  idempotency_key text,
  requested_by uuid references auth.users(id) on delete set null,
  requested_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  input_payload jsonb not null default '{}'::jsonb,
  output_payload jsonb,
  error_code text,
  error_message text,
  retry_count integer not null default 0,
  max_retries integer not null default 3,
  next_retry_at timestamptz,
  worker_id text,
  trace_id text,
  metadata jsonb not null default '{}'::jsonb,
  constraint ai_jobs_priority_range check (priority between 0 and 1000),
  constraint ai_jobs_retry_nonnegative check (retry_count >= 0 and max_retries >= 0),
  constraint ai_jobs_input_object check (jsonb_typeof(input_payload) = 'object'),
  constraint ai_jobs_output_object check (output_payload is null or jsonb_typeof(output_payload) = 'object'),
  constraint ai_jobs_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint ai_jobs_time_order check (
    (started_at is null or started_at >= requested_at)
    and (completed_at is null or started_at is null or completed_at >= started_at)
  )
);

create unique index if not exists ai_jobs_idempotency_uq
  on public.ai_jobs (business_id, idempotency_key)
  where idempotency_key is not null;

create index if not exists ai_jobs_queue_idx
  on public.ai_jobs (status, priority, requested_at)
  where status in ('queued','running');

create index if not exists ai_jobs_business_history_idx
  on public.ai_jobs (business_id, job_type, requested_at desc);

-- =========================================================
-- FORECASTS
-- =========================================================

create table if not exists public.ai_forecasts (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  location_id uuid references public.business_locations(id) on delete set null,
  model_id uuid references public.ai_models(id) on delete set null,
  job_id uuid references public.ai_jobs(id) on delete set null,
  metric public.ai_forecast_metric not null,
  granularity public.ai_forecast_granularity not null,
  entity_type text,
  entity_id uuid,
  period_start timestamptz not null,
  period_end timestamptz not null,
  predicted_value numeric(24,8) not null,
  lower_bound numeric(24,8),
  upper_bound numeric(24,8),
  confidence_score numeric(8,6),
  actual_value numeric(24,8),
  generated_at timestamptz not null default now(),
  model_version text,
  feature_snapshot_at timestamptz,
  explanation jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  constraint ai_forecasts_period_check check (period_end > period_start),
  constraint ai_forecasts_bounds_check check (
    (lower_bound is null or lower_bound <= predicted_value)
    and (upper_bound is null or upper_bound >= predicted_value)
  ),
  constraint ai_forecasts_confidence_range check (
    confidence_score is null or confidence_score between 0 and 1
  ),
  constraint ai_forecasts_explanation_object check (jsonb_typeof(explanation) = 'object'),
  constraint ai_forecasts_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists ai_forecasts_scope_period_uq
  on public.ai_forecasts (
    business_id,
    coalesce(location_id, '00000000-0000-0000-0000-000000000000'::uuid),
    metric,
    granularity,
    coalesce(entity_type,''),
    coalesce(entity_id, '00000000-0000-0000-0000-000000000000'::uuid),
    period_start,
    period_end,
    coalesce(model_version,'')
  );

create index if not exists ai_forecasts_business_metric_idx
  on public.ai_forecasts (
    business_id, metric, granularity, period_start
  );

-- =========================================================
-- ANOMALY DETECTION
-- =========================================================

create table if not exists public.ai_anomalies (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  location_id uuid references public.business_locations(id) on delete set null,
  model_id uuid references public.ai_models(id) on delete set null,
  job_id uuid references public.ai_jobs(id) on delete set null,
  anomaly_type public.ai_anomaly_type not null,
  severity public.ai_severity not null default 'medium',
  entity_type text,
  entity_id uuid,
  title text not null,
  description text,
  detected_at timestamptz not null default now(),
  period_start timestamptz,
  period_end timestamptz,
  observed_value numeric(24,8),
  expected_value numeric(24,8),
  deviation_score numeric(24,8),
  confidence_score numeric(8,6),
  evidence jsonb not null default '{}'::jsonb,
  is_acknowledged boolean not null default false,
  acknowledged_at timestamptz,
  acknowledged_by uuid references auth.users(id) on delete set null,
  resolution_status text,
  resolution_notes text,
  resolved_at timestamptz,
  resolved_by uuid references auth.users(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  constraint ai_anomalies_title_not_blank check (length(trim(title)) > 0),
  constraint ai_anomalies_period_check check (
    period_end is null or period_start is null or period_end >= period_start
  ),
  constraint ai_anomalies_confidence_range check (
    confidence_score is null or confidence_score between 0 and 1
  ),
  constraint ai_anomalies_evidence_object check (jsonb_typeof(evidence) = 'object'),
  constraint ai_anomalies_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create index if not exists ai_anomalies_open_idx
  on public.ai_anomalies (
    business_id, severity, detected_at desc
  )
  where resolved_at is null;

create index if not exists ai_anomalies_entity_idx
  on public.ai_anomalies (
    business_id, entity_type, entity_id, detected_at desc
  )
  where entity_id is not null;

-- =========================================================
-- RECOMMENDATIONS
-- =========================================================

create table if not exists public.ai_recommendations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  location_id uuid references public.business_locations(id) on delete set null,
  model_id uuid references public.ai_models(id) on delete set null,
  job_id uuid references public.ai_jobs(id) on delete set null,
  recommendation_type public.ai_recommendation_type not null,
  status public.ai_recommendation_status not null default 'new',
  severity public.ai_severity not null default 'medium',
  entity_type text,
  entity_id uuid,
  title text not null,
  summary text,
  rationale text,
  recommended_action jsonb not null default '{}'::jsonb,
  expected_impact jsonb not null default '{}'::jsonb,
  confidence_score numeric(8,6),
  priority_score numeric(12,6),
  generated_at timestamptz not null default now(),
  expires_at timestamptz,
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete set null,
  implemented_at timestamptz,
  implementation_reference text,
  dismissal_reason text,
  metadata jsonb not null default '{}'::jsonb,
  record_version integer not null default 1,
  constraint ai_recommendations_title_not_blank check (length(trim(title)) > 0),
  constraint ai_recommendations_action_object check (jsonb_typeof(recommended_action) = 'object'),
  constraint ai_recommendations_impact_object check (jsonb_typeof(expected_impact) = 'object'),
  constraint ai_recommendations_confidence_range check (
    confidence_score is null or confidence_score between 0 and 1
  ),
  constraint ai_recommendations_expiry_check check (
    expires_at is null or expires_at > generated_at
  ),
  constraint ai_recommendations_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint ai_recommendations_record_version_positive check (record_version >= 1)
);

create index if not exists ai_recommendations_active_idx
  on public.ai_recommendations (
    business_id, status, severity, priority_score desc, generated_at desc
  )
  where status in ('new','reviewed','accepted');

-- =========================================================
-- EXECUTIVE INSIGHTS
-- =========================================================

create table if not exists public.ai_insights (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  location_id uuid references public.business_locations(id) on delete set null,
  model_id uuid references public.ai_models(id) on delete set null,
  job_id uuid references public.ai_jobs(id) on delete set null,
  insight_type public.ai_insight_type not null,
  severity public.ai_severity not null default 'info',
  title text not null,
  summary text not null,
  narrative text,
  period_start timestamptz,
  period_end timestamptz,
  metric_name text,
  metric_value numeric(24,8),
  comparison_value numeric(24,8),
  change_percent numeric(18,6),
  supporting_data jsonb not null default '{}'::jsonb,
  generated_at timestamptz not null default now(),
  expires_at timestamptz,
  is_pinned boolean not null default false,
  is_archived boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  constraint ai_insights_title_not_blank check (length(trim(title)) > 0),
  constraint ai_insights_summary_not_blank check (length(trim(summary)) > 0),
  constraint ai_insights_period_check check (
    period_end is null or period_start is null or period_end >= period_start
  ),
  constraint ai_insights_supporting_data_object check (jsonb_typeof(supporting_data) = 'object'),
  constraint ai_insights_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create index if not exists ai_insights_feed_idx
  on public.ai_insights (
    business_id, is_pinned desc, severity, generated_at desc
  )
  where is_archived = false;

-- =========================================================
-- AI ASSISTANT
-- =========================================================

create table if not exists public.ai_assistant_threads (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  location_id uuid references public.business_locations(id) on delete set null,
  employee_id uuid references public.employees(id) on delete set null,
  title text,
  context jsonb not null default '{}'::jsonb,
  is_archived boolean not null default false,
  last_message_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ai_assistant_threads_context_object check (jsonb_typeof(context) = 'object'),
  constraint ai_assistant_threads_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create index if not exists ai_assistant_threads_employee_idx
  on public.ai_assistant_threads (
    business_id, employee_id, last_message_at desc
  )
  where is_archived = false;

create table if not exists public.ai_assistant_messages (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  thread_id uuid not null references public.ai_assistant_threads(id) on delete cascade,
  model_id uuid references public.ai_models(id) on delete set null,
  job_id uuid references public.ai_jobs(id) on delete set null,
  role text not null,
  content text not null,
  structured_content jsonb not null default '{}'::jsonb,
  query_plan jsonb,
  source_references jsonb not null default '[]'::jsonb,
  token_usage jsonb not null default '{}'::jsonb,
  latency_ms integer,
  safety_flags jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint ai_assistant_messages_role_check check (
    role in ('system','user','assistant','tool')
  ),
  constraint ai_assistant_messages_content_not_blank check (length(trim(content)) > 0),
  constraint ai_assistant_messages_structured_object check (jsonb_typeof(structured_content) = 'object'),
  constraint ai_assistant_messages_query_plan_object check (
    query_plan is null or jsonb_typeof(query_plan) = 'object'
  ),
  constraint ai_assistant_messages_sources_array check (jsonb_typeof(source_references) = 'array'),
  constraint ai_assistant_messages_token_usage_object check (jsonb_typeof(token_usage) = 'object'),
  constraint ai_assistant_messages_safety_object check (jsonb_typeof(safety_flags) = 'object'),
  constraint ai_assistant_messages_latency_nonnegative check (
    latency_ms is null or latency_ms >= 0
  )
);

create index if not exists ai_assistant_messages_thread_idx
  on public.ai_assistant_messages (thread_id, created_at);

-- =========================================================
-- FEEDBACK AND OVERRIDES
-- =========================================================

create table if not exists public.ai_feedback (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  employee_id uuid references public.employees(id) on delete set null,
  target_type text not null,
  target_id uuid not null,
  rating public.ai_feedback_rating not null,
  comments text,
  correction_payload jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint ai_feedback_target_type_not_blank check (length(trim(target_type)) > 0),
  constraint ai_feedback_correction_object check (
    correction_payload is null or jsonb_typeof(correction_payload) = 'object'
  )
);

create unique index if not exists ai_feedback_user_target_uq
  on public.ai_feedback (
    business_id,
    coalesce(created_by, '00000000-0000-0000-0000-000000000000'::uuid),
    target_type,
    target_id
  );

create table if not exists public.ai_decision_audit (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  location_id uuid references public.business_locations(id) on delete set null,
  target_type text not null,
  target_id uuid not null,
  previous_status text,
  new_status text not null,
  decision text not null,
  reason text,
  decided_by uuid references auth.users(id) on delete set null,
  decided_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  constraint ai_decision_audit_target_type_not_blank check (length(trim(target_type)) > 0),
  constraint ai_decision_audit_status_not_blank check (length(trim(new_status)) > 0),
  constraint ai_decision_audit_decision_not_blank check (length(trim(decision)) > 0),
  constraint ai_decision_audit_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create index if not exists ai_decision_audit_target_idx
  on public.ai_decision_audit (business_id, target_type, target_id, decided_at desc);

-- =========================================================
-- VALIDATION FUNCTIONS
-- =========================================================

create or replace function public.validate_ai_business_location()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.location_id is not null and not exists (
    select 1
    from public.business_locations l
    where l.id = new.location_id
      and l.business_id = new.business_id
      and l.deleted_at is null
  ) then
    raise exception 'AI location must belong to the same business.';
  end if;
  return new;
end;
$$;

create or replace function public.validate_ai_model_scope()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.model_id is not null and not exists (
    select 1
    from public.ai_models m
    where m.id = new.model_id
      and m.deleted_at is null
      and (m.business_id is null or m.business_id = new.business_id)
  ) then
    raise exception 'AI model must be global or belong to the same business.';
  end if;
  return new;
end;
$$;

create or replace function public.prevent_ai_audit_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  raise exception 'AI decision audit records are append-only.';
end;
$$;

create or replace function public.increment_ai_record_version()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.record_version = old.record_version + 1;
  return new;
end;
$$;

-- =========================================================
-- JOB AND OUTPUT RPCS
-- =========================================================

create or replace function public.enqueue_ai_job(
  p_business_id uuid,
  p_job_type public.ai_job_type,
  p_location_id uuid default null,
  p_model_id uuid default null,
  p_priority integer default 100,
  p_idempotency_key text default null,
  p_input_payload jsonb default '{}'::jsonb
)
returns public.ai_jobs
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_job public.ai_jobs%rowtype;
begin
  if auth.uid() is not null
     and not public.has_permission(p_business_id, 'ai.run', p_location_id) then
    raise exception 'Permission denied to run AI jobs.';
  end if;

  if p_input_payload is null or jsonb_typeof(p_input_payload) <> 'object' then
    raise exception 'AI job input payload must be a JSON object.';
  end if;

  if p_location_id is not null and not exists (
    select 1 from public.business_locations
    where id = p_location_id
      and business_id = p_business_id
      and deleted_at is null
  ) then
    raise exception 'Location does not belong to this business.';
  end if;

  if p_model_id is not null and not exists (
    select 1 from public.ai_models
    where id = p_model_id
      and deleted_at is null
      and (business_id is null or business_id = p_business_id)
  ) then
    raise exception 'Model is not available to this business.';
  end if;

  insert into public.ai_jobs (
    business_id, location_id, model_id, job_type,
    priority, idempotency_key, requested_by, input_payload
  )
  values (
    p_business_id, p_location_id, p_model_id, p_job_type,
    greatest(0, least(1000, p_priority)), p_idempotency_key,
    auth.uid(), p_input_payload
  )
  on conflict (business_id, idempotency_key)
    where idempotency_key is not null
  do update set requested_at = excluded.requested_at
  returning * into v_job;

  return v_job;
end;
$$;

create or replace function public.update_ai_job_status(
  p_job_id uuid,
  p_status public.ai_job_status,
  p_output_payload jsonb default null,
  p_error_code text default null,
  p_error_message text default null,
  p_worker_id text default null
)
returns public.ai_jobs
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_job public.ai_jobs%rowtype;
begin
  select * into v_job
  from public.ai_jobs
  where id = p_job_id
  for update;

  if not found then
    raise exception 'AI job not found.';
  end if;

  if auth.uid() is not null
     and not public.has_permission(v_job.business_id, 'ai.manage', v_job.location_id) then
    raise exception 'Permission denied to update AI jobs.';
  end if;

  update public.ai_jobs
  set status = p_status,
      started_at = case
        when p_status = 'running' and started_at is null then now()
        else started_at
      end,
      completed_at = case
        when p_status in ('succeeded','failed','cancelled') then now()
        else completed_at
      end,
      output_payload = coalesce(p_output_payload, output_payload),
      error_code = p_error_code,
      error_message = p_error_message,
      worker_id = coalesce(p_worker_id, worker_id)
  where id = p_job_id
  returning * into v_job;

  return v_job;
end;
$$;

create or replace function public.set_ai_recommendation_status(
  p_recommendation_id uuid,
  p_status public.ai_recommendation_status,
  p_reason text default null,
  p_implementation_reference text default null
)
returns public.ai_recommendations
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_rec public.ai_recommendations%rowtype;
  v_previous text;
begin
  select * into v_rec
  from public.ai_recommendations
  where id = p_recommendation_id
  for update;

  if not found then
    raise exception 'AI recommendation not found.';
  end if;

  if auth.uid() is not null
     and not public.has_permission(v_rec.business_id, 'ai.override', v_rec.location_id) then
    raise exception 'Permission denied to update AI recommendations.';
  end if;

  v_previous := v_rec.status::text;

  update public.ai_recommendations
  set status = p_status,
      reviewed_at = case when p_status in ('reviewed','accepted','dismissed','implemented') then now() else reviewed_at end,
      reviewed_by = case when p_status in ('reviewed','accepted','dismissed','implemented') then auth.uid() else reviewed_by end,
      implemented_at = case when p_status='implemented' then now() else implemented_at end,
      implementation_reference = case when p_status='implemented' then p_implementation_reference else implementation_reference end,
      dismissal_reason = case when p_status='dismissed' then p_reason else dismissal_reason end
  where id = p_recommendation_id
  returning * into v_rec;

  insert into public.ai_decision_audit (
    business_id, location_id, target_type, target_id,
    previous_status, new_status, decision, reason, decided_by
  )
  values (
    v_rec.business_id, v_rec.location_id, 'recommendation', v_rec.id,
    v_previous, v_rec.status::text, p_status::text, p_reason, auth.uid()
  );

  return v_rec;
end;
$$;

-- =========================================================
-- SIMPLE BASELINE INSIGHT FUNCTIONS
-- =========================================================

create or replace function public.generate_daily_sales_baseline(
  p_business_id uuid,
  p_location_id uuid,
  p_target_date date
)
returns public.ai_forecasts
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_avg numeric(24,8);
  v_std numeric(24,8);
  v_forecast public.ai_forecasts%rowtype;
begin
  if auth.uid() is not null
     and not public.has_permission(p_business_id, 'ai.run', p_location_id) then
    raise exception 'Permission denied to generate forecasts.';
  end if;

  select
    coalesce(avg(day_total),0),
    coalesce(stddev_pop(day_total),0)
  into v_avg, v_std
  from (
    select
      t.occurred_at::date as sale_date,
      sum(t.total_cents - t.refunded_cents)::numeric as day_total
    from public.transactions t
    where t.business_id = p_business_id
      and (p_location_id is null or t.location_id = p_location_id)
      and t.status::text in ('completed','partially_refunded','refunded')
      and t.occurred_at::date >= p_target_date - 56
      and t.occurred_at::date < p_target_date
      and extract(isodow from t.occurred_at::date) = extract(isodow from p_target_date)
    group by t.occurred_at::date
  ) d;

  insert into public.ai_forecasts (
    business_id, location_id, metric, granularity,
    period_start, period_end, predicted_value,
    lower_bound, upper_bound, confidence_score,
    model_version, explanation, metadata
  )
  values (
    p_business_id, p_location_id, 'revenue', 'day',
    p_target_date::timestamptz,
    (p_target_date + 1)::timestamptz,
    greatest(v_avg,0),
    greatest(v_avg - (1.96 * v_std),0),
    greatest(v_avg + (1.96 * v_std),0),
    case when v_avg = 0 then 0 else 0.65 end,
    'baseline-weekday-v1',
    jsonb_build_object(
      'method','weekday_average',
      'lookback_days',56,
      'standard_deviation',v_std
    ),
    jsonb_build_object('generated_by','database_baseline')
  )
  on conflict (
    business_id,
    coalesce(location_id, '00000000-0000-0000-0000-000000000000'::uuid),
    metric,
    granularity,
    coalesce(entity_type,''),
    coalesce(entity_id, '00000000-0000-0000-0000-000000000000'::uuid),
    period_start,
    period_end,
    coalesce(model_version,'')
  )
  do update set
    predicted_value = excluded.predicted_value,
    lower_bound = excluded.lower_bound,
    upper_bound = excluded.upper_bound,
    confidence_score = excluded.confidence_score,
    generated_at = now(),
    explanation = excluded.explanation,
    metadata = excluded.metadata
  returning * into v_forecast;

  return v_forecast;
end;
$$;

create or replace function public.detect_revenue_anomaly(
  p_business_id uuid,
  p_location_id uuid,
  p_target_date date
)
returns public.ai_anomalies
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_actual numeric(24,8);
  v_expected numeric(24,8);
  v_deviation numeric(24,8);
  v_type public.ai_anomaly_type;
  v_severity public.ai_severity;
  v_anomaly public.ai_anomalies%rowtype;
begin
  if auth.uid() is not null
     and not public.has_permission(p_business_id, 'ai.run', p_location_id) then
    raise exception 'Permission denied to run anomaly detection.';
  end if;

  select coalesce(sum(total_cents - refunded_cents),0)::numeric
  into v_actual
  from public.transactions
  where business_id = p_business_id
    and (p_location_id is null or location_id = p_location_id)
    and status::text in ('completed','partially_refunded','refunded')
    and occurred_at::date = p_target_date;

  select predicted_value
  into v_expected
  from public.ai_forecasts
  where business_id = p_business_id
    and (location_id is not distinct from p_location_id)
    and metric = 'revenue'
    and granularity = 'day'
    and period_start::date = p_target_date
  order by generated_at desc
  limit 1;

  if v_expected is null then
    perform public.generate_daily_sales_baseline(p_business_id,p_location_id,p_target_date);
    select predicted_value into v_expected
    from public.ai_forecasts
    where business_id = p_business_id
      and (location_id is not distinct from p_location_id)
      and metric='revenue'
      and granularity='day'
      and period_start::date=p_target_date
    order by generated_at desc
    limit 1;
  end if;

  if coalesce(v_expected,0) = 0 then
    v_deviation := 0;
  else
    v_deviation := ((v_actual - v_expected) / v_expected) * 100;
  end if;

  v_type := case when v_deviation < 0 then 'revenue_drop' else 'revenue_spike' end;
  v_severity := case
    when abs(v_deviation) >= 50 then 'critical'
    when abs(v_deviation) >= 30 then 'high'
    when abs(v_deviation) >= 15 then 'medium'
    else 'low'
  end;

  insert into public.ai_anomalies (
    business_id, location_id, anomaly_type, severity,
    title, description, detected_at, period_start, period_end,
    observed_value, expected_value, deviation_score,
    confidence_score, evidence, metadata
  )
  values (
    p_business_id, p_location_id, v_type, v_severity,
    case when v_deviation < 0 then 'Revenue below expected range' else 'Revenue above expected range' end,
    'Daily revenue differed from the weekday baseline by ' || round(v_deviation,2)::text || '%.',
    now(),
    p_target_date::timestamptz,
    (p_target_date + 1)::timestamptz,
    v_actual, v_expected, v_deviation, 0.65,
    jsonb_build_object(
      'actual_revenue_cents',v_actual,
      'expected_revenue_cents',v_expected,
      'deviation_percent',v_deviation
    ),
    jsonb_build_object('detector','database_baseline_v1')
  )
  returning * into v_anomaly;

  return v_anomaly;
end;
$$;

-- =========================================================
-- TRIGGERS
-- =========================================================

do $$
declare
  t text;
begin
  foreach t in array array[
    'ai_jobs','ai_feature_snapshots','ai_forecasts','ai_anomalies',
    'ai_recommendations','ai_insights','ai_assistant_threads',
    'ai_decision_audit'
  ]
  loop
    execute format('drop trigger if exists %I on public.%I', t || '_validate_location', t);
    execute format(
      'create trigger %I before insert or update on public.%I for each row execute function public.validate_ai_business_location()',
      t || '_validate_location', t
    );
  end loop;
end $$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'ai_jobs','ai_forecasts','ai_anomalies','ai_recommendations',
    'ai_insights','ai_assistant_messages'
  ]
  loop
    execute format('drop trigger if exists %I on public.%I', t || '_validate_model', t);
    execute format(
      'create trigger %I before insert or update on public.%I for each row execute function public.validate_ai_model_scope()',
      t || '_validate_model', t
    );
  end loop;
end $$;

drop trigger if exists ai_decision_audit_block_update on public.ai_decision_audit;
create trigger ai_decision_audit_block_update
before update on public.ai_decision_audit
for each row execute function public.prevent_ai_audit_mutation();

drop trigger if exists ai_decision_audit_block_delete on public.ai_decision_audit;
create trigger ai_decision_audit_block_delete
before delete on public.ai_decision_audit
for each row execute function public.prevent_ai_audit_mutation();

-- updated_at
drop trigger if exists ai_models_set_updated_at on public.ai_models;
create trigger ai_models_set_updated_at
before update on public.ai_models
for each row execute function public.set_updated_at();

drop trigger if exists ai_feature_definitions_set_updated_at on public.ai_feature_definitions;
create trigger ai_feature_definitions_set_updated_at
before update on public.ai_feature_definitions
for each row execute function public.set_updated_at();

drop trigger if exists ai_recommendations_set_updated_at on public.ai_recommendations;
create trigger ai_recommendations_set_updated_at
before update on public.ai_recommendations
for each row execute function public.set_updated_at();

drop trigger if exists ai_assistant_threads_set_updated_at on public.ai_assistant_threads;
create trigger ai_assistant_threads_set_updated_at
before update on public.ai_assistant_threads
for each row execute function public.set_updated_at();

-- versions
drop trigger if exists ai_models_increment_version on public.ai_models;
create trigger ai_models_increment_version
before update on public.ai_models
for each row execute function public.increment_ai_record_version();

drop trigger if exists ai_feature_definitions_increment_version on public.ai_feature_definitions;
create trigger ai_feature_definitions_increment_version
before update on public.ai_feature_definitions
for each row execute function public.increment_ai_record_version();

drop trigger if exists ai_recommendations_increment_version on public.ai_recommendations;
create trigger ai_recommendations_increment_version
before update on public.ai_recommendations
for each row execute function public.increment_ai_record_version();

-- =========================================================
-- DEFAULT GLOBAL MODELS
-- =========================================================

insert into public.ai_models (
  business_id, code, name, description, model_type, version,
  status, provider, provider_model, feature_schema,
  output_schema, runtime_config, metadata
)
select
  null,
  v.code,
  v.name,
  v.description,
  v.model_type::public.ai_model_type,
  '1.0.0',
  'active',
  'vivid_internal',
  v.provider_model,
  v.feature_schema::jsonb,
  v.output_schema::jsonb,
  '{}'::jsonb,
  jsonb_build_object('system_model',true)
from (
  values
    (
      'sales_forecast',
      'Sales Forecast',
      'Forecasts revenue, transaction volume, and customer visits.',
      'forecasting',
      'baseline_sales_v1',
      '{"lookback_days":"integer","location_id":"uuid"}',
      '{"predicted_value":"number","lower_bound":"number","upper_bound":"number"}'
    ),
    (
      'inventory_demand',
      'Inventory Demand Forecast',
      'Predicts product demand, stockout risk, and reorder quantities.',
      'forecasting',
      'inventory_demand_v1',
      '{"product_id":"uuid","location_id":"uuid","sales_history":"array"}',
      '{"predicted_units":"number","stockout_date":"date","reorder_quantity":"number"}'
    ),
    (
      'customer_churn',
      'Customer Churn Risk',
      'Estimates customer churn risk and recommended retention actions.',
      'classification',
      'customer_churn_v1',
      '{"membership_id":"uuid","visit_history":"array","spend_history":"array"}',
      '{"churn_probability":"number","risk_band":"string","reasons":"array"}'
    ),
    (
      'fraud_anomaly',
      'Operational Fraud and Anomaly Detection',
      'Detects suspicious refunds, discounts, cash variances, and inventory shrinkage.',
      'anomaly_detection',
      'fraud_anomaly_v1',
      '{"transactions":"array","refunds":"array","cash_events":"array","inventory_events":"array"}',
      '{"risk_score":"number","anomaly_type":"string","evidence":"object"}'
    ),
    (
      'business_assistant',
      'VIVID+ Business Assistant',
      'Natural-language assistant for business, operational, CRM, and financial analysis.',
      'language',
      'assistant_v1',
      '{"question":"string","business_context":"object"}',
      '{"answer":"string","sources":"array","actions":"array"}'
    )
) as v(
  code,name,description,model_type,provider_model,feature_schema,output_schema
)
where not exists (
  select 1
  from public.ai_models m
  where m.business_id is null
    and lower(m.code)=lower(v.code)
    and lower(m.version)='1.0.0'
    and m.deleted_at is null
);

-- =========================================================
-- DEFAULT FEATURE DEFINITIONS
-- =========================================================

insert into public.ai_feature_definitions (
  business_id, code, name, description, entity_type,
  data_type, source_tables, refresh_interval_minutes,
  is_sensitive, metadata
)
select
  null,
  v.code,
  v.name,
  v.description,
  v.entity_type,
  v.data_type,
  v.source_tables,
  v.refresh_minutes,
  v.is_sensitive,
  jsonb_build_object('system_feature',true)
from (
  values
    ('daily_revenue','Daily Revenue','Net completed revenue by business and location.','location','numeric',array['transactions'],60,false),
    ('daily_transaction_count','Daily Transaction Count','Completed transaction volume by day.','location','numeric',array['transactions'],60,false),
    ('average_ticket','Average Ticket','Average completed transaction total.','location','numeric',array['transactions'],60,false),
    ('refund_rate','Refund Rate','Refunded amount divided by gross transaction amount.','location','numeric',array['transactions','pos_refunds'],60,true),
    ('inventory_days_remaining','Inventory Days Remaining','Estimated days until stockout by product and location.','product','numeric',array['inventory_balances','transaction_items'],360,false),
    ('customer_days_since_visit','Customer Days Since Visit','Days since membership last visit.','membership','numeric',array['memberships','visits'],1440,true),
    ('customer_lifetime_value','Customer Lifetime Value','Net lifetime customer value in cents.','membership','numeric',array['memberships','transactions'],1440,true),
    ('employee_refund_rate','Employee Refund Rate','Refund amount associated with employee activity.','employee','numeric',array['transactions','pos_refunds'],1440,true),
    ('cash_variance','Cash Variance','Register expected cash compared with counted cash.','register_session','numeric',array['register_sessions','cash_drawer_events'],60,true),
    ('gross_margin_rate','Gross Margin Rate','Net revenue less estimated cost divided by net revenue.','location','numeric',array['transactions'],60,true)
) as v(
  code,name,description,entity_type,data_type,source_tables,refresh_minutes,is_sensitive
)
where not exists (
  select 1
  from public.ai_feature_definitions f
  where f.business_id is null
    and lower(f.code)=lower(v.code)
    and f.deleted_at is null
);

-- =========================================================
-- ROLE PROVISIONING
-- =========================================================

create or replace function public.provision_ai_role_permissions(p_business_id uuid)
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
    and p.module = 'ai'
    and not exists (
      select 1
      from public.role_permissions rp
      where rp.role_id = r.id
        and rp.permission_id = p.id
    );

  insert into public.role_permissions (business_id, role_id, permission_id)
  select p_business_id, r.id, p.id
  from public.business_roles r
  cross join public.permissions p
  where r.business_id = p_business_id
    and r.deleted_at is null
    and r.code = 'manager'
    and p.code in (
      'ai.read','ai.run','ai.assistant','ai.feedback','ai.override'
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
    and p.code in ('ai.read','ai.assistant','ai.feedback')
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
    and p.code in ('ai.read','ai.export','ai.audit')
    and not exists (
      select 1 from public.role_permissions rp
      where rp.role_id = r.id and rp.permission_id = p.id
    );
end;
$$;

select public.provision_ai_role_permissions(b.id)
from public.businesses b
where b.deleted_at is null;

-- =========================================================
-- ROW LEVEL SECURITY
-- =========================================================

do $$
declare
  t text;
begin
  foreach t in array array[
    'ai_models','ai_feature_definitions','ai_feature_snapshots','ai_jobs',
    'ai_forecasts','ai_anomalies','ai_recommendations','ai_insights',
    'ai_assistant_threads','ai_assistant_messages','ai_feedback','ai_decision_audit'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('alter table public.%I force row level security', t);
  end loop;
end $$;

-- Models and features
drop policy if exists ai_models_read on public.ai_models;
create policy ai_models_read on public.ai_models
for select to authenticated
using (
  business_id is null
  or public.has_permission(business_id,'ai.read')
);

drop policy if exists ai_models_manage on public.ai_models;
create policy ai_models_manage on public.ai_models
to authenticated
using (
  business_id is not null
  and public.has_permission(business_id,'ai.manage')
)
with check (
  business_id is not null
  and public.has_permission(business_id,'ai.manage')
);

drop policy if exists ai_feature_definitions_read on public.ai_feature_definitions;
create policy ai_feature_definitions_read on public.ai_feature_definitions
for select to authenticated
using (
  business_id is null
  or public.has_permission(business_id,'ai.read')
);

drop policy if exists ai_feature_definitions_manage on public.ai_feature_definitions;
create policy ai_feature_definitions_manage on public.ai_feature_definitions
to authenticated
using (
  business_id is not null
  and public.has_permission(business_id,'ai.manage')
)
with check (
  business_id is not null
  and public.has_permission(business_id,'ai.manage')
);

drop policy if exists ai_feature_snapshots_read on public.ai_feature_snapshots;
create policy ai_feature_snapshots_read on public.ai_feature_snapshots
for select to authenticated
using (public.has_permission(business_id,'ai.read',location_id));

drop policy if exists ai_feature_snapshots_manage on public.ai_feature_snapshots;
create policy ai_feature_snapshots_manage on public.ai_feature_snapshots
to authenticated
using (public.has_permission(business_id,'ai.manage',location_id))
with check (public.has_permission(business_id,'ai.manage',location_id));

-- Jobs
drop policy if exists ai_jobs_read on public.ai_jobs;
create policy ai_jobs_read on public.ai_jobs
for select to authenticated
using (public.has_permission(business_id,'ai.read',location_id));

drop policy if exists ai_jobs_create on public.ai_jobs;
create policy ai_jobs_create on public.ai_jobs
for insert to authenticated
with check (public.has_permission(business_id,'ai.run',location_id));

drop policy if exists ai_jobs_manage on public.ai_jobs;
create policy ai_jobs_manage on public.ai_jobs
for update to authenticated
using (public.has_permission(business_id,'ai.manage',location_id))
with check (public.has_permission(business_id,'ai.manage',location_id));

-- Outputs
drop policy if exists ai_forecasts_read on public.ai_forecasts;
create policy ai_forecasts_read on public.ai_forecasts
for select to authenticated
using (public.has_permission(business_id,'ai.read',location_id));

drop policy if exists ai_forecasts_manage on public.ai_forecasts;
create policy ai_forecasts_manage on public.ai_forecasts
to authenticated
using (public.has_permission(business_id,'ai.manage',location_id))
with check (public.has_permission(business_id,'ai.manage',location_id));

drop policy if exists ai_anomalies_read on public.ai_anomalies;
create policy ai_anomalies_read on public.ai_anomalies
for select to authenticated
using (public.has_permission(business_id,'ai.read',location_id));

drop policy if exists ai_anomalies_manage on public.ai_anomalies;
create policy ai_anomalies_manage on public.ai_anomalies
to authenticated
using (public.has_permission(business_id,'ai.override',location_id))
with check (public.has_permission(business_id,'ai.override',location_id));

drop policy if exists ai_recommendations_read on public.ai_recommendations;
create policy ai_recommendations_read on public.ai_recommendations
for select to authenticated
using (public.has_permission(business_id,'ai.read',location_id));

drop policy if exists ai_recommendations_manage on public.ai_recommendations;
create policy ai_recommendations_manage on public.ai_recommendations
to authenticated
using (public.has_permission(business_id,'ai.override',location_id))
with check (public.has_permission(business_id,'ai.override',location_id));

drop policy if exists ai_insights_read on public.ai_insights;
create policy ai_insights_read on public.ai_insights
for select to authenticated
using (public.has_permission(business_id,'ai.read',location_id));

drop policy if exists ai_insights_manage on public.ai_insights;
create policy ai_insights_manage on public.ai_insights
to authenticated
using (public.has_permission(business_id,'ai.manage',location_id))
with check (public.has_permission(business_id,'ai.manage',location_id));

-- Assistant
drop policy if exists ai_assistant_threads_read on public.ai_assistant_threads;
create policy ai_assistant_threads_read on public.ai_assistant_threads
for select to authenticated
using (
  public.has_permission(business_id,'ai.assistant',location_id)
  and (
    employee_id is null
    or employee_id = public.current_employee_id(business_id)
    or public.has_permission(business_id,'ai.audit',location_id)
  )
);

drop policy if exists ai_assistant_threads_manage on public.ai_assistant_threads;
create policy ai_assistant_threads_manage on public.ai_assistant_threads
to authenticated
using (
  public.has_permission(business_id,'ai.assistant',location_id)
  and (
    employee_id is null
    or employee_id = public.current_employee_id(business_id)
    or public.has_permission(business_id,'ai.audit',location_id)
  )
)
with check (
  public.has_permission(business_id,'ai.assistant',location_id)
  and (
    employee_id is null
    or employee_id = public.current_employee_id(business_id)
  )
);

drop policy if exists ai_assistant_messages_read on public.ai_assistant_messages;
create policy ai_assistant_messages_read on public.ai_assistant_messages
for select to authenticated
using (
  exists (
    select 1
    from public.ai_assistant_threads t
    where t.id = thread_id
      and t.business_id = ai_assistant_messages.business_id
      and public.has_permission(t.business_id,'ai.assistant',t.location_id)
      and (
        t.employee_id is null
        or t.employee_id = public.current_employee_id(t.business_id)
        or public.has_permission(t.business_id,'ai.audit',t.location_id)
      )
  )
);

drop policy if exists ai_assistant_messages_create on public.ai_assistant_messages;
create policy ai_assistant_messages_create on public.ai_assistant_messages
for insert to authenticated
with check (
  exists (
    select 1
    from public.ai_assistant_threads t
    where t.id = thread_id
      and t.business_id = ai_assistant_messages.business_id
      and public.has_permission(t.business_id,'ai.assistant',t.location_id)
      and (
        t.employee_id is null
        or t.employee_id = public.current_employee_id(t.business_id)
      )
  )
);

-- Feedback and audit
drop policy if exists ai_feedback_read on public.ai_feedback;
create policy ai_feedback_read on public.ai_feedback
for select to authenticated
using (
  created_by = auth.uid()
  or public.has_permission(business_id,'ai.audit')
);

drop policy if exists ai_feedback_create on public.ai_feedback;
create policy ai_feedback_create on public.ai_feedback
for insert to authenticated
with check (public.has_permission(business_id,'ai.feedback'));

drop policy if exists ai_feedback_update on public.ai_feedback;
create policy ai_feedback_update on public.ai_feedback
for update to authenticated
using (created_by = auth.uid())
with check (created_by = auth.uid());

drop policy if exists ai_decision_audit_read on public.ai_decision_audit;
create policy ai_decision_audit_read on public.ai_decision_audit
for select to authenticated
using (public.has_permission(business_id,'ai.audit',location_id));

-- No direct authenticated mutation policy for append-only decision audit.

-- =========================================================
-- GRANTS
-- =========================================================

grant select, insert, update on public.ai_models to authenticated;
grant select, insert, update on public.ai_feature_definitions to authenticated;
grant select, insert, update on public.ai_feature_snapshots to authenticated;
grant select, insert, update on public.ai_jobs to authenticated;
grant select, insert, update on public.ai_forecasts to authenticated;
grant select, insert, update on public.ai_anomalies to authenticated;
grant select, insert, update on public.ai_recommendations to authenticated;
grant select, insert, update on public.ai_insights to authenticated;
grant select, insert, update on public.ai_assistant_threads to authenticated;
grant select, insert on public.ai_assistant_messages to authenticated;
grant select, insert, update on public.ai_feedback to authenticated;
grant select on public.ai_decision_audit to authenticated;

grant execute on function public.enqueue_ai_job(
  uuid,public.ai_job_type,uuid,uuid,integer,text,jsonb
) to authenticated;

grant execute on function public.update_ai_job_status(
  uuid,public.ai_job_status,jsonb,text,text,text
) to authenticated;

grant execute on function public.set_ai_recommendation_status(
  uuid,public.ai_recommendation_status,text,text
) to authenticated;

grant execute on function public.generate_daily_sales_baseline(
  uuid,uuid,date
) to authenticated;

grant execute on function public.detect_revenue_anomaly(
  uuid,uuid,date
) to authenticated;

comment on table public.ai_models is
  'Tenant-aware AI model registry supporting global and business-specific models.';
comment on table public.ai_feature_snapshots is
  'Time-versioned feature values used for AI inference and explainability.';
comment on table public.ai_jobs is
  'Durable AI execution queue with idempotency, retries, lineage, and result payloads.';
comment on table public.ai_forecasts is
  'Forecast outputs for revenue, demand, visits, transactions, gross profit, and cash flow.';
comment on table public.ai_anomalies is
  'Detected operational, financial, inventory, employee, and customer anomalies.';
comment on table public.ai_recommendations is
  'Prioritized AI recommendations with review, acceptance, dismissal, and implementation lifecycle.';
comment on table public.ai_assistant_messages is
  'Business assistant conversation messages with query plans, sources, safety flags, and token usage.';
comment on table public.ai_decision_audit is
  'Append-only audit trail of human decisions on AI outputs.';

commit;
