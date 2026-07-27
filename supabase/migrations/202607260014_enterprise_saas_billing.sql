-- =========================================================
-- VIVID+ MIGRATION 014
-- ENTERPRISE SAAS BILLING FOUNDATION
-- Plans, features, pricing, business billing profiles,
-- subscriptions, items, entitlements, lifecycle validation,
-- secure tenant RLS, triggers, and default catalog seeds.
-- =========================================================

begin;

-- =========================================================
-- ENUMS
-- =========================================================

do $$ begin
  create type public.billing_interval as enum (
    'month','quarter','year','custom'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.billing_price_model as enum (
    'flat','per_seat','metered','tiered','volume','package','custom'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.subscription_status as enum (
    'incomplete','trialing','active','past_due','paused',
    'cancelled','expired','unpaid'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.subscription_change_type as enum (
    'upgrade','downgrade','pause','resume','cancel','reactivate','custom'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.entitlement_value_type as enum (
    'boolean','integer','numeric','text','json'
  );
exception when duplicate_object then null; end $$;

-- =========================================================
-- PERMISSIONS
-- =========================================================

insert into public.permissions (code, module, description, is_sensitive)
values
  ('billing.read',         'billing', 'View billing profile, plans, subscriptions, and entitlements.', true),
  ('billing.manage',       'billing', 'Manage billing profile and subscription configuration.', true),
  ('billing.subscribe',    'billing', 'Start, change, pause, resume, or cancel subscriptions.', true),
  ('billing.entitlements', 'billing', 'View effective business feature entitlements.', false),
  ('billing.audit',        'billing', 'View billing lifecycle and subscription change history.', true)
on conflict ((lower(code))) do update
set module = excluded.module,
    description = excluded.description,
    is_sensitive = excluded.is_sensitive;

-- =========================================================
-- PLAN CATALOG
-- =========================================================

create table if not exists public.billing_plans (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  name text not null,
  description text,
  is_public boolean not null default true,
  is_active boolean not null default true,
  is_custom boolean not null default false,
  sort_order integer not null default 100,
  trial_days integer not null default 0,
  default_currency char(3) not null default 'USD',
  metadata jsonb not null default '{}'::jsonb,
  record_version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint billing_plans_code_format check (code ~ '^[a-z][a-z0-9_]*$'),
  constraint billing_plans_name_not_blank check (length(trim(name)) > 0),
  constraint billing_plans_trial_days_nonnegative check (trial_days >= 0),
  constraint billing_plans_sort_order_nonnegative check (sort_order >= 0),
  constraint billing_plans_currency_format check (default_currency ~ '^[A-Z]{3}$'),
  constraint billing_plans_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint billing_plans_record_version_positive check (record_version >= 1)
);

create unique index if not exists billing_plans_code_uq
  on public.billing_plans (lower(code))
  where deleted_at is null;

create index if not exists billing_plans_public_sort_idx
  on public.billing_plans (is_public, is_active, sort_order)
  where deleted_at is null;

create table if not exists public.billing_features (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  name text not null,
  description text,
  module text not null,
  value_type public.entitlement_value_type not null default 'boolean',
  unit_name text,
  is_active boolean not null default true,
  is_customer_visible boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  record_version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint billing_features_code_format check (code ~ '^[a-z][a-z0-9_.]*$'),
  constraint billing_features_name_not_blank check (length(trim(name)) > 0),
  constraint billing_features_module_not_blank check (length(trim(module)) > 0),
  constraint billing_features_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint billing_features_record_version_positive check (record_version >= 1)
);

create unique index if not exists billing_features_code_uq
  on public.billing_features (lower(code))
  where deleted_at is null;

create index if not exists billing_features_module_idx
  on public.billing_features (module, is_active)
  where deleted_at is null;

create table if not exists public.billing_plan_features (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.billing_plans(id) on delete cascade,
  feature_id uuid not null references public.billing_features(id) on delete cascade,
  is_enabled boolean not null default true,
  boolean_value boolean,
  integer_value bigint,
  numeric_value numeric(24,8),
  text_value text,
  json_value jsonb,
  soft_limit numeric(24,8),
  hard_limit numeric(24,8),
  overage_allowed boolean not null default false,
  overage_unit_amount_cents bigint,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint billing_plan_features_values_check check (
    num_nonnulls(boolean_value, integer_value, numeric_value, text_value, json_value) <= 1
  ),
  constraint billing_plan_features_json_valid check (
    json_value is null or jsonb_typeof(json_value) in ('object','array','string','number','boolean')
  ),
  constraint billing_plan_features_limits_check check (
    (soft_limit is null or soft_limit >= 0)
    and (hard_limit is null or hard_limit >= 0)
    and (soft_limit is null or hard_limit is null or soft_limit <= hard_limit)
  ),
  constraint billing_plan_features_overage_amount_check check (
    overage_unit_amount_cents is null or overage_unit_amount_cents >= 0
  ),
  constraint billing_plan_features_metadata_object check (jsonb_typeof(metadata) = 'object'),
  unique (plan_id, feature_id)
);

create index if not exists billing_plan_features_feature_idx
  on public.billing_plan_features (feature_id, plan_id);

create table if not exists public.billing_plan_prices (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.billing_plans(id) on delete cascade,
  code text not null,
  currency char(3) not null default 'USD',
  interval public.billing_interval not null,
  interval_count integer not null default 1,
  price_model public.billing_price_model not null default 'flat',
  unit_amount_cents bigint not null default 0,
  included_quantity numeric(24,8),
  minimum_quantity numeric(24,8),
  maximum_quantity numeric(24,8),
  trial_days_override integer,
  tiers jsonb not null default '[]'::jsonb,
  is_default boolean not null default false,
  is_active boolean not null default true,
  external_provider text,
  external_price_id text,
  metadata jsonb not null default '{}'::jsonb,
  record_version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint billing_plan_prices_code_format check (code ~ '^[a-z][a-z0-9_]*$'),
  constraint billing_plan_prices_currency_format check (currency ~ '^[A-Z]{3}$'),
  constraint billing_plan_prices_interval_count_positive check (interval_count >= 1),
  constraint billing_plan_prices_amount_nonnegative check (unit_amount_cents >= 0),
  constraint billing_plan_prices_quantity_check check (
    (included_quantity is null or included_quantity >= 0)
    and (minimum_quantity is null or minimum_quantity >= 0)
    and (maximum_quantity is null or maximum_quantity >= 0)
    and (minimum_quantity is null or maximum_quantity is null or minimum_quantity <= maximum_quantity)
  ),
  constraint billing_plan_prices_trial_days_nonnegative check (
    trial_days_override is null or trial_days_override >= 0
  ),
  constraint billing_plan_prices_tiers_array check (jsonb_typeof(tiers) = 'array'),
  constraint billing_plan_prices_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint billing_plan_prices_record_version_positive check (record_version >= 1)
);

create unique index if not exists billing_plan_prices_code_uq
  on public.billing_plan_prices (plan_id, lower(code), currency)
  where deleted_at is null;

create unique index if not exists billing_plan_prices_default_uq
  on public.billing_plan_prices (plan_id, currency, interval)
  where is_default = true and is_active = true and deleted_at is null;

create unique index if not exists billing_plan_prices_external_uq
  on public.billing_plan_prices (lower(external_provider), external_price_id)
  where external_provider is not null
    and external_price_id is not null
    and deleted_at is null;

-- =========================================================
-- BUSINESS BILLING PROFILE
-- =========================================================

create table if not exists public.business_billing_profiles (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  legal_name text,
  billing_email text,
  billing_phone text,
  currency char(3) not null default 'USD',
  timezone text not null default 'America/New_York',
  tax_id_type text,
  tax_id_value text,
  tax_exempt boolean not null default false,
  address_line1 text,
  address_line2 text,
  city text,
  region text,
  postal_code text,
  country_code char(2) not null default 'US',
  invoice_prefix text,
  invoice_notes text,
  external_customer_ids jsonb not null default '{}'::jsonb,
  billing_settings jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  record_version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint business_billing_profiles_currency_format check (currency ~ '^[A-Z]{3}$'),
  constraint business_billing_profiles_country_format check (country_code ~ '^[A-Z]{2}$'),
  constraint business_billing_profiles_email_check check (
    billing_email is null or position('@' in billing_email) > 1
  ),
  constraint business_billing_profiles_external_ids_object check (jsonb_typeof(external_customer_ids) = 'object'),
  constraint business_billing_profiles_settings_object check (jsonb_typeof(billing_settings) = 'object'),
  constraint business_billing_profiles_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint business_billing_profiles_record_version_positive check (record_version >= 1)
);

create unique index if not exists business_billing_profiles_business_uq
  on public.business_billing_profiles (business_id)
  where deleted_at is null;

-- =========================================================
-- SUBSCRIPTIONS
-- =========================================================

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  billing_profile_id uuid references public.business_billing_profiles(id) on delete set null,
  plan_id uuid not null references public.billing_plans(id) on delete restrict,
  price_id uuid references public.billing_plan_prices(id) on delete restrict,
  status public.subscription_status not null default 'incomplete',
  currency char(3) not null default 'USD',
  quantity numeric(24,8) not null default 1,
  seat_quantity integer not null default 1,
  trial_start timestamptz,
  trial_end timestamptz,
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  cancel_at timestamptz,
  cancelled_at timestamptz,
  ended_at timestamptz,
  paused_at timestamptz,
  resume_at timestamptz,
  external_provider text,
  external_subscription_id text,
  provider_status text,
  idempotency_key text,
  metadata jsonb not null default '{}'::jsonb,
  record_version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint subscriptions_currency_format check (currency ~ '^[A-Z]{3}$'),
  constraint subscriptions_quantity_positive check (quantity > 0),
  constraint subscriptions_seat_quantity_positive check (seat_quantity >= 1),
  constraint subscriptions_trial_order check (
    trial_start is null or trial_end is null or trial_end > trial_start
  ),
  constraint subscriptions_period_order check (
    current_period_start is null or current_period_end is null or current_period_end > current_period_start
  ),
  constraint subscriptions_cancel_order check (
    cancel_at is null or created_at is null or cancel_at >= created_at
  ),
  constraint subscriptions_resume_order check (
    resume_at is null or paused_at is null or resume_at >= paused_at
  ),
  constraint subscriptions_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint subscriptions_record_version_positive check (record_version >= 1)
);

create unique index if not exists subscriptions_one_current_business_uq
  on public.subscriptions (business_id)
  where status in ('incomplete','trialing','active','past_due','paused','unpaid')
    and deleted_at is null;

create unique index if not exists subscriptions_external_uq
  on public.subscriptions (lower(external_provider), external_subscription_id)
  where external_provider is not null
    and external_subscription_id is not null
    and deleted_at is null;

create unique index if not exists subscriptions_idempotency_uq
  on public.subscriptions (business_id, idempotency_key)
  where idempotency_key is not null;

create index if not exists subscriptions_status_period_idx
  on public.subscriptions (status, current_period_end)
  where deleted_at is null;

create table if not exists public.subscription_items (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  price_id uuid not null references public.billing_plan_prices(id) on delete restrict,
  feature_id uuid references public.billing_features(id) on delete set null,
  item_code text not null,
  description text,
  quantity numeric(24,8) not null default 1,
  unit_amount_cents bigint not null default 0,
  included_quantity numeric(24,8),
  usage_meter_code text,
  effective_from timestamptz not null default now(),
  effective_until timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint subscription_items_code_format check (item_code ~ '^[a-z][a-z0-9_]*$'),
  constraint subscription_items_quantity_positive check (quantity > 0),
  constraint subscription_items_amount_nonnegative check (unit_amount_cents >= 0),
  constraint subscription_items_included_quantity_nonnegative check (
    included_quantity is null or included_quantity >= 0
  ),
  constraint subscription_items_effective_order check (
    effective_until is null or effective_until > effective_from
  ),
  constraint subscription_items_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists subscription_items_active_code_uq
  on public.subscription_items (subscription_id, lower(item_code))
  where deleted_at is null and effective_until is null;

create index if not exists subscription_items_business_subscription_idx
  on public.subscription_items (business_id, subscription_id)
  where deleted_at is null;

create table if not exists public.subscription_entitlements (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  feature_id uuid not null references public.billing_features(id) on delete restrict,
  source text not null default 'plan',
  is_enabled boolean not null default true,
  boolean_value boolean,
  integer_value bigint,
  numeric_value numeric(24,8),
  text_value text,
  json_value jsonb,
  soft_limit numeric(24,8),
  hard_limit numeric(24,8),
  consumed_quantity numeric(24,8) not null default 0,
  effective_from timestamptz not null default now(),
  effective_until timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint subscription_entitlements_source_not_blank check (length(trim(source)) > 0),
  constraint subscription_entitlements_values_check check (
    num_nonnulls(boolean_value, integer_value, numeric_value, text_value, json_value) <= 1
  ),
  constraint subscription_entitlements_json_valid check (
    json_value is null or jsonb_typeof(json_value) in ('object','array','string','number','boolean')
  ),
  constraint subscription_entitlements_limits_check check (
    consumed_quantity >= 0
    and (soft_limit is null or soft_limit >= 0)
    and (hard_limit is null or hard_limit >= 0)
    and (soft_limit is null or hard_limit is null or soft_limit <= hard_limit)
  ),
  constraint subscription_entitlements_effective_order check (
    effective_until is null or effective_until > effective_from
  ),
  constraint subscription_entitlements_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists subscription_entitlements_active_feature_uq
  on public.subscription_entitlements (subscription_id, feature_id)
  where effective_until is null;

create index if not exists subscription_entitlements_business_feature_idx
  on public.subscription_entitlements (business_id, feature_id, is_enabled)
  where effective_until is null;

create table if not exists public.subscription_change_events (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  change_type public.subscription_change_type not null,
  previous_plan_id uuid references public.billing_plans(id) on delete set null,
  new_plan_id uuid references public.billing_plans(id) on delete set null,
  previous_status public.subscription_status,
  new_status public.subscription_status,
  effective_at timestamptz not null default now(),
  reason text,
  idempotency_key text,
  requested_by uuid references auth.users(id) on delete set null,
  approved_by uuid references auth.users(id) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint subscription_change_events_payload_object check (jsonb_typeof(payload) = 'object')
);

create unique index if not exists subscription_change_events_idempotency_uq
  on public.subscription_change_events (business_id, idempotency_key)
  where idempotency_key is not null;

create index if not exists subscription_change_events_history_idx
  on public.subscription_change_events (subscription_id, effective_at desc);

-- =========================================================
-- VALIDATION FUNCTIONS
-- =========================================================

create or replace function public.increment_billing_record_version()
returns trigger
language plpgsql
as $$
begin
  new.record_version := old.record_version + 1;
  return new;
end;
$$;

create or replace function public.validate_subscription_scope()
returns trigger
language plpgsql
as $$
declare
  v_profile_business_id uuid;
  v_price_plan_id uuid;
begin
  if new.billing_profile_id is not null then
    select business_id into v_profile_business_id
    from public.business_billing_profiles
    where id = new.billing_profile_id and deleted_at is null;

    if v_profile_business_id is distinct from new.business_id then
      raise exception 'Billing profile must belong to the same business.';
    end if;
  end if;

  if new.price_id is not null then
    select plan_id into v_price_plan_id
    from public.billing_plan_prices
    where id = new.price_id and deleted_at is null and is_active = true;

    if v_price_plan_id is distinct from new.plan_id then
      raise exception 'Subscription price must belong to the selected plan.';
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.validate_subscription_child_scope()
returns trigger
language plpgsql
as $$
declare
  v_subscription_business_id uuid;
  v_subscription_plan_id uuid;
  v_price_plan_id uuid;
begin
  select business_id, plan_id
  into v_subscription_business_id, v_subscription_plan_id
  from public.subscriptions
  where id = new.subscription_id and deleted_at is null;

  if v_subscription_business_id is null then
    raise exception 'Subscription does not exist or is deleted.';
  end if;

  if v_subscription_business_id is distinct from new.business_id then
    raise exception 'Subscription child row must belong to the same business.';
  end if;

  if tg_table_name = 'subscription_items' then
    select plan_id into v_price_plan_id
    from public.billing_plan_prices
    where id = new.price_id and deleted_at is null;

    if v_price_plan_id is distinct from v_subscription_plan_id then
      raise exception 'Subscription item price must belong to the subscription plan.';
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.refresh_subscription_entitlements(
  p_subscription_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_business_id uuid;
  v_plan_id uuid;
  v_count integer;
begin
  select business_id, plan_id
  into v_business_id, v_plan_id
  from public.subscriptions
  where id = p_subscription_id and deleted_at is null;

  if v_business_id is null then
    raise exception 'Subscription not found.';
  end if;

  if auth.uid() is not null
     and not public.has_permission(v_business_id, 'billing.manage', null) then
    raise exception 'Permission denied to refresh subscription entitlements.';
  end if;

  update public.subscription_entitlements
  set effective_until = now(),
      updated_at = now(),
      updated_by = auth.uid()
  where subscription_id = p_subscription_id
    and effective_until is null;

  insert into public.subscription_entitlements (
    business_id, subscription_id, feature_id, source, is_enabled,
    boolean_value, integer_value, numeric_value, text_value, json_value,
    soft_limit, hard_limit, effective_from, metadata,
    created_by, updated_by
  )
  select
    v_business_id,
    p_subscription_id,
    pf.feature_id,
    'plan',
    pf.is_enabled,
    pf.boolean_value,
    pf.integer_value,
    pf.numeric_value,
    pf.text_value,
    pf.json_value,
    pf.soft_limit,
    pf.hard_limit,
    now(),
    jsonb_build_object('plan_id',v_plan_id,'plan_feature_id',pf.id),
    auth.uid(),
    auth.uid()
  from public.billing_plan_features pf
  join public.billing_features f on f.id = pf.feature_id
  where pf.plan_id = v_plan_id
    and f.is_active = true
    and f.deleted_at is null;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.has_entitlement(
  p_business_id uuid,
  p_feature_code text
)
returns boolean
language sql
stable
security definer
set search_path = public, auth
set row_security = off
as $$
  select exists (
    select 1
    from public.subscription_entitlements e
    join public.billing_features f on f.id = e.feature_id
    join public.subscriptions s on s.id = e.subscription_id
    where e.business_id = p_business_id
      and lower(f.code) = lower(p_feature_code)
      and e.is_enabled = true
      and e.effective_from <= now()
      and (e.effective_until is null or e.effective_until > now())
      and s.status in ('trialing','active','past_due')
      and s.deleted_at is null
  );
$$;

-- =========================================================
-- TRIGGERS
-- =========================================================

drop trigger if exists subscriptions_validate_scope on public.subscriptions;
create trigger subscriptions_validate_scope
before insert or update on public.subscriptions
for each row execute function public.validate_subscription_scope();

drop trigger if exists subscription_items_validate_scope on public.subscription_items;
create trigger subscription_items_validate_scope
before insert or update on public.subscription_items
for each row execute function public.validate_subscription_child_scope();

drop trigger if exists subscription_entitlements_validate_scope on public.subscription_entitlements;
create trigger subscription_entitlements_validate_scope
before insert or update on public.subscription_entitlements
for each row execute function public.validate_subscription_child_scope();

do $$
declare
  t text;
begin
  foreach t in array array[
    'billing_plans','billing_features','billing_plan_prices',
    'business_billing_profiles','subscriptions'
  ]
  loop
    execute format('drop trigger if exists %I on public.%I', t || '_set_updated_at', t);
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      t || '_set_updated_at', t
    );
    execute format('drop trigger if exists %I on public.%I', t || '_increment_version', t);
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.increment_billing_record_version()',
      t || '_increment_version', t
    );
  end loop;
end $$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'billing_plan_features','subscription_items','subscription_entitlements'
  ]
  loop
    execute format('drop trigger if exists %I on public.%I', t || '_set_updated_at', t);
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      t || '_set_updated_at', t
    );
  end loop;
end $$;

-- =========================================================
-- ROW LEVEL SECURITY
-- =========================================================

alter table public.billing_plans enable row level security;
alter table public.billing_features enable row level security;
alter table public.billing_plan_features enable row level security;
alter table public.billing_plan_prices enable row level security;
alter table public.business_billing_profiles enable row level security;
alter table public.subscriptions enable row level security;
alter table public.subscription_items enable row level security;
alter table public.subscription_entitlements enable row level security;
alter table public.subscription_change_events enable row level security;

create policy billing_plans_authenticated_read
on public.billing_plans for select to authenticated
using (is_active = true and deleted_at is null);

create policy billing_features_authenticated_read
on public.billing_features for select to authenticated
using (is_active = true and deleted_at is null);

create policy billing_plan_features_authenticated_read
on public.billing_plan_features for select to authenticated
using (exists (
  select 1 from public.billing_plans p
  where p.id = plan_id and p.is_active = true and p.deleted_at is null
));

create policy billing_plan_prices_authenticated_read
on public.billing_plan_prices for select to authenticated
using (is_active = true and deleted_at is null);

create policy business_billing_profiles_read
on public.business_billing_profiles for select to authenticated
using (
  public.has_permission(business_id, 'billing.read', null)
  or public.is_business_owner(business_id)
);

create policy business_billing_profiles_manage
on public.business_billing_profiles to authenticated
using (
  public.has_permission(business_id, 'billing.manage', null)
  or public.is_business_owner(business_id)
)
with check (
  public.has_permission(business_id, 'billing.manage', null)
  or public.is_business_owner(business_id)
);

create policy subscriptions_read
on public.subscriptions for select to authenticated
using (
  public.has_permission(business_id, 'billing.read', null)
  or public.is_business_owner(business_id)
);

create policy subscriptions_manage
on public.subscriptions to authenticated
using (
  public.has_permission(business_id, 'billing.subscribe', null)
  or public.is_business_owner(business_id)
)
with check (
  public.has_permission(business_id, 'billing.subscribe', null)
  or public.is_business_owner(business_id)
);

create policy subscription_items_read
on public.subscription_items for select to authenticated
using (
  public.has_permission(business_id, 'billing.read', null)
  or public.is_business_owner(business_id)
);

create policy subscription_items_manage
on public.subscription_items to authenticated
using (
  public.has_permission(business_id, 'billing.subscribe', null)
  or public.is_business_owner(business_id)
)
with check (
  public.has_permission(business_id, 'billing.subscribe', null)
  or public.is_business_owner(business_id)
);

create policy subscription_entitlements_read
on public.subscription_entitlements for select to authenticated
using (
  public.has_permission(business_id, 'billing.entitlements', null)
  or public.has_permission(business_id, 'billing.read', null)
  or public.is_business_member(business_id)
);

create policy subscription_entitlements_manage
on public.subscription_entitlements to authenticated
using (
  public.has_permission(business_id, 'billing.manage', null)
  or public.is_business_owner(business_id)
)
with check (
  public.has_permission(business_id, 'billing.manage', null)
  or public.is_business_owner(business_id)
);

create policy subscription_change_events_read
on public.subscription_change_events for select to authenticated
using (
  public.has_permission(business_id, 'billing.audit', null)
  or public.is_business_owner(business_id)
);

create policy subscription_change_events_insert
on public.subscription_change_events for insert to authenticated
with check (
  public.has_permission(business_id, 'billing.subscribe', null)
  or public.is_business_owner(business_id)
);

-- =========================================================
-- GRANTS
-- =========================================================

grant select on public.billing_plans to authenticated;
grant select on public.billing_features to authenticated;
grant select on public.billing_plan_features to authenticated;
grant select on public.billing_plan_prices to authenticated;
grant select, insert, update, delete on public.business_billing_profiles to authenticated;
grant select, insert, update, delete on public.subscriptions to authenticated;
grant select, insert, update, delete on public.subscription_items to authenticated;
grant select, insert, update, delete on public.subscription_entitlements to authenticated;
grant select, insert on public.subscription_change_events to authenticated;

grant all on public.billing_plans to service_role;
grant all on public.billing_features to service_role;
grant all on public.billing_plan_features to service_role;
grant all on public.billing_plan_prices to service_role;
grant all on public.business_billing_profiles to service_role;
grant all on public.subscriptions to service_role;
grant all on public.subscription_items to service_role;
grant all on public.subscription_entitlements to service_role;
grant all on public.subscription_change_events to service_role;

revoke all on function public.refresh_subscription_entitlements(uuid) from public;
grant execute on function public.refresh_subscription_entitlements(uuid) to authenticated;
grant execute on function public.refresh_subscription_entitlements(uuid) to service_role;

revoke all on function public.has_entitlement(uuid,text) from public;
grant execute on function public.has_entitlement(uuid,text) to authenticated;
grant execute on function public.has_entitlement(uuid,text) to service_role;

-- =========================================================
-- DEFAULT FEATURES
-- =========================================================

insert into public.billing_features (
  code, name, description, module, value_type, unit_name, metadata
)
values
  ('platform.pos', 'Point of Sale', 'Access to VIVID+ point-of-sale capabilities.', 'pos', 'boolean', null, '{"system_feature":true}'),
  ('platform.crm', 'Customer Relationship Management', 'Access to customer profiles, visits, memberships, and CRM workflows.', 'crm', 'boolean', null, '{"system_feature":true}'),
  ('platform.inventory', 'Inventory Management', 'Access to inventory balances, movements, and controls.', 'inventory', 'boolean', null, '{"system_feature":true}'),
  ('platform.accounting', 'Accounting', 'Access to accounting and financial operations.', 'accounting', 'boolean', null, '{"system_feature":true}'),
  ('platform.ai', 'AI Business Intelligence', 'Access to AI forecasts, recommendations, anomalies, and assistant workflows.', 'ai', 'boolean', null, '{"system_feature":true}'),
  ('limits.locations', 'Business Locations', 'Maximum number of active business locations.', 'platform', 'integer', 'locations', '{"system_feature":true}'),
  ('limits.users', 'Users and Employees', 'Maximum number of active employees or licensed users.', 'platform', 'integer', 'users', '{"system_feature":true}'),
  ('limits.api_requests_monthly', 'Monthly API Requests', 'Included monthly API request allowance.', 'platform', 'integer', 'requests', '{"system_feature":true}'),
  ('support.level', 'Support Level', 'Customer support service level.', 'platform', 'text', null, '{"system_feature":true}')
on conflict ((lower(code))) do update
set name = excluded.name,
    description = excluded.description,
    module = excluded.module,
    value_type = excluded.value_type,
    unit_name = excluded.unit_name,
    is_active = true,
    metadata = excluded.metadata,
    updated_at = now();

-- =========================================================
-- DEFAULT PLANS
-- =========================================================

insert into public.billing_plans (
  code, name, description, is_public, is_active, is_custom,
  sort_order, trial_days, default_currency, metadata
)
values
  ('starter', 'Starter', 'Essential tools for a new or single-location business.', true, true, false, 10, 14, 'USD', '{"system_plan":true}'),
  ('professional', 'Professional', 'Advanced operations, reporting, accounting, and AI for growing businesses.', true, true, false, 20, 14, 'USD', '{"system_plan":true}'),
  ('enterprise', 'Enterprise', 'Multi-location controls, advanced security, higher limits, and premium support.', true, true, false, 30, 30, 'USD', '{"system_plan":true}'),
  ('custom', 'Custom', 'Contract-defined plan with negotiated pricing and entitlements.', false, true, true, 100, 0, 'USD', '{"system_plan":true}')
on conflict ((lower(code))) do update
set name = excluded.name,
    description = excluded.description,
    is_public = excluded.is_public,
    is_active = excluded.is_active,
    is_custom = excluded.is_custom,
    sort_order = excluded.sort_order,
    trial_days = excluded.trial_days,
    default_currency = excluded.default_currency,
    metadata = excluded.metadata,
    updated_at = now();

insert into public.billing_plan_prices (
  plan_id, code, currency, interval, interval_count,
  price_model, unit_amount_cents, is_default, is_active, metadata
)
select p.id, v.price_code, 'USD', v.interval::public.billing_interval, 1,
       'flat'::public.billing_price_model, v.amount_cents, true, true,
       jsonb_build_object('system_price',true)
from (
  values
    ('starter','starter_monthly','month',9900::bigint),
    ('starter','starter_annual','year',99000::bigint),
    ('professional','professional_monthly','month',19900::bigint),
    ('professional','professional_annual','year',199000::bigint),
    ('enterprise','enterprise_monthly','month',49900::bigint),
    ('enterprise','enterprise_annual','year',499000::bigint)
) as v(plan_code,price_code,interval,amount_cents)
join public.billing_plans p on lower(p.code)=lower(v.plan_code) and p.deleted_at is null
where not exists (
  select 1 from public.billing_plan_prices bp
  where bp.plan_id=p.id
    and lower(bp.code)=lower(v.price_code)
    and bp.currency='USD'
    and bp.deleted_at is null
);

-- Starter entitlements
insert into public.billing_plan_features (
  plan_id, feature_id, is_enabled,
  boolean_value, integer_value, text_value, metadata
)
select p.id, f.id, true,
       case when f.value_type='boolean' then v.bool_value end,
       case when f.value_type='integer' then v.int_value end,
       case when f.value_type='text' then v.text_value end,
       jsonb_build_object('system_entitlement',true)
from (
  values
    ('platform.pos',true,null::bigint,null::text),
    ('platform.crm',true,null::bigint,null::text),
    ('platform.inventory',true,null::bigint,null::text),
    ('platform.accounting',false,null::bigint,null::text),
    ('platform.ai',false,null::bigint,null::text),
    ('limits.locations',null,1::bigint,null::text),
    ('limits.users',null,5::bigint,null::text),
    ('limits.api_requests_monthly',null,10000::bigint,null::text),
    ('support.level',null,null::bigint,'standard')
) as v(feature_code,bool_value,int_value,text_value)
join public.billing_plans p on p.code='starter' and p.deleted_at is null
join public.billing_features f on f.code=v.feature_code and f.deleted_at is null
on conflict (plan_id,feature_id) do update
set is_enabled=excluded.is_enabled,
    boolean_value=excluded.boolean_value,
    integer_value=excluded.integer_value,
    text_value=excluded.text_value,
    metadata=excluded.metadata,
    updated_at=now();

-- Professional entitlements
insert into public.billing_plan_features (
  plan_id, feature_id, is_enabled,
  boolean_value, integer_value, text_value, metadata
)
select p.id, f.id, true,
       case when f.value_type='boolean' then v.bool_value end,
       case when f.value_type='integer' then v.int_value end,
       case when f.value_type='text' then v.text_value end,
       jsonb_build_object('system_entitlement',true)
from (
  values
    ('platform.pos',true,null::bigint,null::text),
    ('platform.crm',true,null::bigint,null::text),
    ('platform.inventory',true,null::bigint,null::text),
    ('platform.accounting',true,null::bigint,null::text),
    ('platform.ai',true,null::bigint,null::text),
    ('limits.locations',null,5::bigint,null::text),
    ('limits.users',null,25::bigint,null::text),
    ('limits.api_requests_monthly',null,100000::bigint,null::text),
    ('support.level',null,null::bigint,'priority')
) as v(feature_code,bool_value,int_value,text_value)
join public.billing_plans p on p.code='professional' and p.deleted_at is null
join public.billing_features f on f.code=v.feature_code and f.deleted_at is null
on conflict (plan_id,feature_id) do update
set is_enabled=excluded.is_enabled,
    boolean_value=excluded.boolean_value,
    integer_value=excluded.integer_value,
    text_value=excluded.text_value,
    metadata=excluded.metadata,
    updated_at=now();

-- Enterprise entitlements
insert into public.billing_plan_features (
  plan_id, feature_id, is_enabled,
  boolean_value, integer_value, text_value, metadata
)
select p.id, f.id, true,
       case when f.value_type='boolean' then v.bool_value end,
       case when f.value_type='integer' then v.int_value end,
       case when f.value_type='text' then v.text_value end,
       jsonb_build_object('system_entitlement',true)
from (
  values
    ('platform.pos',true,null::bigint,null::text),
    ('platform.crm',true,null::bigint,null::text),
    ('platform.inventory',true,null::bigint,null::text),
    ('platform.accounting',true,null::bigint,null::text),
    ('platform.ai',true,null::bigint,null::text),
    ('limits.locations',null,50::bigint,null::text),
    ('limits.users',null,250::bigint,null::text),
    ('limits.api_requests_monthly',null,1000000::bigint,null::text),
    ('support.level',null,null::bigint,'premium')
) as v(feature_code,bool_value,int_value,text_value)
join public.billing_plans p on p.code='enterprise' and p.deleted_at is null
join public.billing_features f on f.code=v.feature_code and f.deleted_at is null
on conflict (plan_id,feature_id) do update
set is_enabled=excluded.is_enabled,
    boolean_value=excluded.boolean_value,
    integer_value=excluded.integer_value,
    text_value=excluded.text_value,
    metadata=excluded.metadata,
    updated_at=now();

comment on table public.billing_plans is 'Global VIVID+ SaaS plan catalog.';
comment on table public.billing_features is 'Feature and limit definitions used by plan and subscription entitlements.';
comment on table public.billing_plan_prices is 'Currency and interval-specific SaaS plan pricing.';
comment on table public.business_billing_profiles is 'Per-business billing identity, address, tax, currency, and provider customer references.';
comment on table public.subscriptions is 'Current and historical SaaS subscriptions for VIVID+ businesses.';
comment on table public.subscription_items is 'Subscription line items, add-ons, seats, packages, and metered components.';
comment on table public.subscription_entitlements is 'Effective feature access and limits materialized for each business subscription.';
comment on function public.has_entitlement(uuid,text) is 'Returns true when a business has an active effective entitlement for a feature code.';

commit;
