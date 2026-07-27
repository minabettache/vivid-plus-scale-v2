-- =========================================================
-- VIVID+ MIGRATION 015
-- ENTERPRISE BILLING FINANCIAL ENGINE
-- Invoices, invoice lines, payment methods, payments,
-- credits, refunds, tax profiles, provider webhooks,
-- immutable posting rules, RLS, grants, and reporting views.
-- =========================================================

begin;

-- =========================================================
-- ENUMS
-- =========================================================

do $$ begin
  create type public.billing_invoice_status as enum (
    'draft','open','partially_paid','paid','past_due','void','uncollectible'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.billing_invoice_line_type as enum (
    'subscription','seat','usage','addon','discount','tax','credit','adjustment'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.billing_payment_method_type as enum (
    'card','ach_debit','bank_account','wire','cash','check','wallet','manual','other'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.billing_payment_status as enum (
    'pending','authorized','processing','succeeded','failed','cancelled','partially_refunded','refunded'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.billing_payment_transaction_type as enum (
    'authorization','capture','sale','void','refund','chargeback','adjustment'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.billing_credit_type as enum (
    'promotional','service','manual','refund','overpayment','adjustment'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.billing_credit_status as enum (
    'available','partially_applied','applied','expired','void'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.billing_refund_status as enum (
    'pending','processing','succeeded','failed','cancelled'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.billing_webhook_status as enum (
    'received','processing','processed','failed','ignored'
  );
exception when duplicate_object then null; end $$;

-- =========================================================
-- PERMISSIONS
-- =========================================================

insert into public.permissions (code, module, description, is_sensitive)
values
  ('billing_invoices.read',    'billing', 'View invoices and invoice lines.', true),
  ('billing_invoices.manage',  'billing', 'Create, update, post, void, and collect invoices.', true),
  ('billing_payments.read',    'billing', 'View payment methods, payment transactions, and refunds.', true),
  ('billing_payments.manage',  'billing', 'Manage payment methods, payments, captures, voids, and refunds.', true),
  ('billing_credits.read',     'billing', 'View billing credits and applications.', true),
  ('billing_credits.manage',   'billing', 'Issue, apply, expire, and void billing credits.', true),
  ('billing_tax.manage',       'billing', 'Manage business tax profiles and exemption details.', true),
  ('billing_webhooks.read',    'billing', 'View payment-provider webhook processing records.', true),
  ('billing_webhooks.manage',  'billing', 'Retry or resolve payment-provider webhook events.', true)
on conflict ((lower(code))) do update
set module = excluded.module,
    description = excluded.description,
    is_sensitive = excluded.is_sensitive;

-- =========================================================
-- PROVIDERS
-- =========================================================

create table if not exists public.billing_payment_providers (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  name text not null,
  is_active boolean not null default true,
  supports_cards boolean not null default false,
  supports_bank_debit boolean not null default false,
  supports_refunds boolean not null default true,
  supports_webhooks boolean not null default true,
  configuration_schema jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint billing_payment_providers_code_format check (code ~ '^[a-z][a-z0-9_]*$'),
  constraint billing_payment_providers_name_not_blank check (length(trim(name)) > 0),
  constraint billing_payment_providers_config_object check (jsonb_typeof(configuration_schema) = 'object'),
  constraint billing_payment_providers_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists billing_payment_providers_code_uq
  on public.billing_payment_providers (lower(code));

-- =========================================================
-- TAX PROFILES
-- =========================================================

create table if not exists public.billing_tax_profiles (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  legal_name text,
  tax_id_type text,
  tax_id_value text,
  tax_country char(2) not null default 'US',
  tax_region text,
  tax_exempt boolean not null default false,
  exemption_type text,
  exemption_certificate_reference text,
  exemption_expires_on date,
  registration_numbers jsonb not null default '{}'::jsonb,
  tax_settings jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  record_version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint billing_tax_profiles_country_format check (tax_country ~ '^[A-Z]{2}$'),
  constraint billing_tax_profiles_registration_object check (jsonb_typeof(registration_numbers) = 'object'),
  constraint billing_tax_profiles_settings_object check (jsonb_typeof(tax_settings) = 'object'),
  constraint billing_tax_profiles_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint billing_tax_profiles_version_positive check (record_version >= 1)
);

create unique index if not exists billing_tax_profiles_business_uq
  on public.billing_tax_profiles (business_id)
  where deleted_at is null;

-- =========================================================
-- PAYMENT METHODS
-- =========================================================

create table if not exists public.billing_payment_methods (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  billing_profile_id uuid references public.business_billing_profiles(id) on delete set null,
  provider_id uuid references public.billing_payment_providers(id) on delete restrict,
  method_type public.billing_payment_method_type not null,
  display_name text,
  provider_customer_id text,
  provider_payment_method_id text,
  fingerprint text,
  brand text,
  last4 char(4),
  exp_month smallint,
  exp_year smallint,
  bank_name text,
  bank_account_type text,
  billing_address jsonb not null default '{}'::jsonb,
  is_default boolean not null default false,
  is_verified boolean not null default false,
  is_active boolean not null default true,
  verified_at timestamptz,
  expires_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  record_version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint billing_payment_methods_last4_digits check (last4 is null or last4 ~ '^[0-9]{4}$'),
  constraint billing_payment_methods_exp_month check (exp_month is null or exp_month between 1 and 12),
  constraint billing_payment_methods_exp_year check (exp_year is null or exp_year >= 2000),
  constraint billing_payment_methods_address_object check (jsonb_typeof(billing_address) = 'object'),
  constraint billing_payment_methods_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint billing_payment_methods_version_positive check (record_version >= 1)
);

create unique index if not exists billing_payment_methods_provider_ref_uq
  on public.billing_payment_methods (provider_id, provider_payment_method_id)
  where provider_payment_method_id is not null and deleted_at is null;

create unique index if not exists billing_payment_methods_default_uq
  on public.billing_payment_methods (business_id)
  where is_default = true and is_active = true and deleted_at is null;

create index if not exists billing_payment_methods_business_idx
  on public.billing_payment_methods (business_id, is_active, method_type)
  where deleted_at is null;

-- =========================================================
-- INVOICES
-- =========================================================

create table if not exists public.billing_invoices (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  billing_profile_id uuid references public.business_billing_profiles(id) on delete set null,
  subscription_id uuid references public.subscriptions(id) on delete set null,
  tax_profile_id uuid references public.billing_tax_profiles(id) on delete set null,
  invoice_number text not null,
  status public.billing_invoice_status not null default 'draft',
  currency char(3) not null default 'USD',
  issue_date date,
  due_date date,
  service_period_start timestamptz,
  service_period_end timestamptz,
  subtotal_cents bigint not null default 0,
  discount_cents bigint not null default 0,
  tax_cents bigint not null default 0,
  credit_applied_cents bigint not null default 0,
  total_cents bigint not null default 0,
  paid_cents bigint not null default 0,
  refunded_cents bigint not null default 0,
  balance_due_cents bigint not null default 0,
  amount_uncollectible_cents bigint not null default 0,
  posted_at timestamptz,
  posted_by uuid references auth.users(id) on delete set null,
  paid_at timestamptz,
  voided_at timestamptz,
  voided_by uuid references auth.users(id) on delete set null,
  void_reason text,
  external_provider text,
  external_invoice_id text,
  idempotency_key text,
  billing_snapshot jsonb not null default '{}'::jsonb,
  tax_snapshot jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  record_version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint billing_invoices_number_not_blank check (length(trim(invoice_number)) > 0),
  constraint billing_invoices_currency_format check (currency ~ '^[A-Z]{3}$'),
  constraint billing_invoices_dates_check check (due_date is null or issue_date is null or due_date >= issue_date),
  constraint billing_invoices_period_check check (service_period_end is null or service_period_start is null or service_period_end > service_period_start),
  constraint billing_invoices_money_nonnegative check (
    subtotal_cents >= 0 and discount_cents >= 0 and tax_cents >= 0
    and credit_applied_cents >= 0 and total_cents >= 0 and paid_cents >= 0
    and refunded_cents >= 0 and balance_due_cents >= 0 and amount_uncollectible_cents >= 0
  ),
  constraint billing_invoices_paid_refund_check check (refunded_cents <= paid_cents),
  constraint billing_invoices_snapshot_objects check (
    jsonb_typeof(billing_snapshot) = 'object'
    and jsonb_typeof(tax_snapshot) = 'object'
    and jsonb_typeof(metadata) = 'object'
  ),
  constraint billing_invoices_version_positive check (record_version >= 1)
);

create unique index if not exists billing_invoices_number_uq
  on public.billing_invoices (business_id, lower(invoice_number))
  where deleted_at is null;

create unique index if not exists billing_invoices_external_uq
  on public.billing_invoices (lower(external_provider), external_invoice_id)
  where external_provider is not null and external_invoice_id is not null and deleted_at is null;

create unique index if not exists billing_invoices_idempotency_uq
  on public.billing_invoices (business_id, idempotency_key)
  where idempotency_key is not null;

create index if not exists billing_invoices_open_idx
  on public.billing_invoices (business_id, status, due_date)
  where status in ('open','partially_paid','past_due') and deleted_at is null;

create table if not exists public.billing_invoice_items (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  invoice_id uuid not null references public.billing_invoices(id) on delete cascade,
  subscription_item_id uuid references public.subscription_items(id) on delete set null,
  feature_id uuid references public.billing_features(id) on delete set null,
  line_number integer not null,
  line_type public.billing_invoice_line_type not null,
  description text not null,
  quantity numeric(24,8) not null default 1,
  unit_amount_cents bigint not null default 0,
  subtotal_cents bigint not null default 0,
  discount_cents bigint not null default 0,
  tax_cents bigint not null default 0,
  total_cents bigint not null default 0,
  service_period_start timestamptz,
  service_period_end timestamptz,
  tax_code text,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint billing_invoice_items_line_positive check (line_number >= 1),
  constraint billing_invoice_items_description_not_blank check (length(trim(description)) > 0),
  constraint billing_invoice_items_quantity_nonzero check (quantity <> 0),
  constraint billing_invoice_items_money_nonnegative check (
    unit_amount_cents >= 0 and subtotal_cents >= 0 and discount_cents >= 0
    and tax_cents >= 0 and total_cents >= 0
  ),
  constraint billing_invoice_items_period_check check (service_period_end is null or service_period_start is null or service_period_end > service_period_start),
  constraint billing_invoice_items_metadata_object check (jsonb_typeof(metadata) = 'object'),
  unique (invoice_id, line_number)
);

create index if not exists billing_invoice_items_business_invoice_idx
  on public.billing_invoice_items (business_id, invoice_id, line_number);

-- =========================================================
-- CREDITS
-- =========================================================

create table if not exists public.billing_credits (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  subscription_id uuid references public.subscriptions(id) on delete set null,
  credit_type public.billing_credit_type not null,
  status public.billing_credit_status not null default 'available',
  currency char(3) not null default 'USD',
  original_amount_cents bigint not null,
  remaining_amount_cents bigint not null,
  description text not null,
  effective_at timestamptz not null default now(),
  expires_at timestamptz,
  external_reference text,
  idempotency_key text,
  metadata jsonb not null default '{}'::jsonb,
  record_version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint billing_credits_currency_format check (currency ~ '^[A-Z]{3}$'),
  constraint billing_credits_amount_positive check (original_amount_cents > 0),
  constraint billing_credits_remaining_check check (remaining_amount_cents >= 0 and remaining_amount_cents <= original_amount_cents),
  constraint billing_credits_description_not_blank check (length(trim(description)) > 0),
  constraint billing_credits_expiry_check check (expires_at is null or expires_at > effective_at),
  constraint billing_credits_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint billing_credits_version_positive check (record_version >= 1)
);

create unique index if not exists billing_credits_idempotency_uq
  on public.billing_credits (business_id, idempotency_key)
  where idempotency_key is not null;

create index if not exists billing_credits_available_idx
  on public.billing_credits (business_id, currency, expires_at)
  where status in ('available','partially_applied') and deleted_at is null;

create table if not exists public.billing_credit_applications (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  credit_id uuid not null references public.billing_credits(id) on delete restrict,
  invoice_id uuid not null references public.billing_invoices(id) on delete restrict,
  amount_cents bigint not null,
  applied_at timestamptz not null default now(),
  applied_by uuid references auth.users(id) on delete set null,
  idempotency_key text,
  metadata jsonb not null default '{}'::jsonb,
  constraint billing_credit_applications_amount_positive check (amount_cents > 0),
  constraint billing_credit_applications_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists billing_credit_applications_idempotency_uq
  on public.billing_credit_applications (business_id, idempotency_key)
  where idempotency_key is not null;

create index if not exists billing_credit_applications_invoice_idx
  on public.billing_credit_applications (invoice_id, applied_at);

-- =========================================================
-- PAYMENTS AND REFUNDS
-- =========================================================

create table if not exists public.billing_payment_transactions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  invoice_id uuid references public.billing_invoices(id) on delete set null,
  subscription_id uuid references public.subscriptions(id) on delete set null,
  payment_method_id uuid references public.billing_payment_methods(id) on delete set null,
  provider_id uuid references public.billing_payment_providers(id) on delete restrict,
  transaction_type public.billing_payment_transaction_type not null default 'sale',
  status public.billing_payment_status not null default 'pending',
  currency char(3) not null default 'USD',
  amount_cents bigint not null,
  fee_cents bigint not null default 0,
  net_amount_cents bigint not null,
  refunded_amount_cents bigint not null default 0,
  provider_transaction_id text,
  provider_parent_transaction_id text,
  idempotency_key text not null,
  failure_code text,
  failure_message text,
  authorized_at timestamptz,
  captured_at timestamptz,
  succeeded_at timestamptz,
  failed_at timestamptz,
  accounting_journal_entry_id uuid,
  provider_response jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  record_version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint billing_payment_transactions_currency_format check (currency ~ '^[A-Z]{3}$'),
  constraint billing_payment_transactions_amount_positive check (amount_cents > 0),
  constraint billing_payment_transactions_fee_nonnegative check (fee_cents >= 0),
  constraint billing_payment_transactions_net_check check (net_amount_cents = amount_cents - fee_cents),
  constraint billing_payment_transactions_refund_check check (refunded_amount_cents >= 0 and refunded_amount_cents <= amount_cents),
  constraint billing_payment_transactions_response_object check (jsonb_typeof(provider_response) = 'object'),
  constraint billing_payment_transactions_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint billing_payment_transactions_version_positive check (record_version >= 1)
);

create unique index if not exists billing_payment_transactions_idempotency_uq
  on public.billing_payment_transactions (business_id, idempotency_key);

create unique index if not exists billing_payment_transactions_provider_uq
  on public.billing_payment_transactions (provider_id, provider_transaction_id)
  where provider_transaction_id is not null;

create index if not exists billing_payment_transactions_invoice_idx
  on public.billing_payment_transactions (invoice_id, status, created_at desc)
  where invoice_id is not null;

create index if not exists billing_payment_transactions_business_idx
  on public.billing_payment_transactions (business_id, status, created_at desc);

create table if not exists public.billing_refunds (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  payment_transaction_id uuid not null references public.billing_payment_transactions(id) on delete restrict,
  invoice_id uuid references public.billing_invoices(id) on delete set null,
  status public.billing_refund_status not null default 'pending',
  currency char(3) not null default 'USD',
  amount_cents bigint not null,
  reason text,
  provider_refund_id text,
  idempotency_key text not null,
  failure_code text,
  failure_message text,
  requested_at timestamptz not null default now(),
  processed_at timestamptz,
  accounting_journal_entry_id uuid,
  provider_response jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  record_version integer not null default 1,
  requested_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint billing_refunds_currency_format check (currency ~ '^[A-Z]{3}$'),
  constraint billing_refunds_amount_positive check (amount_cents > 0),
  constraint billing_refunds_response_object check (jsonb_typeof(provider_response) = 'object'),
  constraint billing_refunds_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint billing_refunds_version_positive check (record_version >= 1)
);

create unique index if not exists billing_refunds_idempotency_uq
  on public.billing_refunds (business_id, idempotency_key);

create unique index if not exists billing_refunds_provider_uq
  on public.billing_refunds (provider_refund_id)
  where provider_refund_id is not null;

create index if not exists billing_refunds_payment_idx
  on public.billing_refunds (payment_transaction_id, status, requested_at desc);

-- =========================================================
-- PROVIDER WEBHOOK EVENTS
-- =========================================================

create table if not exists public.billing_provider_webhook_events (
  id uuid primary key default gen_random_uuid(),
  business_id uuid references public.businesses(id) on delete cascade,
  provider_id uuid not null references public.billing_payment_providers(id) on delete restrict,
  provider_event_id text not null,
  event_type text not null,
  status public.billing_webhook_status not null default 'received',
  signature_verified boolean not null default false,
  payload jsonb not null,
  headers jsonb not null default '{}'::jsonb,
  attempt_count integer not null default 0,
  received_at timestamptz not null default now(),
  processing_started_at timestamptz,
  processed_at timestamptz,
  next_retry_at timestamptz,
  last_error text,
  related_object_type text,
  related_object_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  constraint billing_provider_webhook_events_type_not_blank check (length(trim(event_type)) > 0),
  constraint billing_provider_webhook_events_payload_valid check (jsonb_typeof(payload) in ('object','array')),
  constraint billing_provider_webhook_events_headers_object check (jsonb_typeof(headers) = 'object'),
  constraint billing_provider_webhook_events_attempt_nonnegative check (attempt_count >= 0),
  constraint billing_provider_webhook_events_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists billing_provider_webhook_events_provider_uq
  on public.billing_provider_webhook_events (provider_id, provider_event_id);

create index if not exists billing_provider_webhook_events_queue_idx
  on public.billing_provider_webhook_events (status, next_retry_at, received_at)
  where status in ('received','failed');

create index if not exists billing_provider_webhook_events_business_idx
  on public.billing_provider_webhook_events (business_id, received_at desc)
  where business_id is not null;

-- =========================================================
-- VALIDATION AND FINANCIAL FUNCTIONS
-- =========================================================

create or replace function public.validate_billing_financial_scope()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_business_id uuid;
begin
  if tg_table_name = 'billing_invoice_items' then
    select business_id into v_business_id from public.billing_invoices where id = new.invoice_id;
  elsif tg_table_name = 'billing_credit_applications' then
    select business_id into v_business_id from public.billing_credits where id = new.credit_id;
    if v_business_id is distinct from new.business_id then
      raise exception 'Credit application business mismatch.';
    end if;
    select business_id into v_business_id from public.billing_invoices where id = new.invoice_id;
  elsif tg_table_name = 'billing_refunds' then
    select business_id into v_business_id from public.billing_payment_transactions where id = new.payment_transaction_id;
  else
    return new;
  end if;

  if v_business_id is null or v_business_id is distinct from new.business_id then
    raise exception 'Billing financial child row must belong to the same business.';
  end if;

  return new;
end;
$$;

create or replace function public.recalculate_billing_invoice_totals(p_invoice_id uuid)
returns public.billing_invoices
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_invoice public.billing_invoices%rowtype;
  v_subtotal bigint;
  v_discount bigint;
  v_tax bigint;
  v_total bigint;
  v_credits bigint;
  v_paid bigint;
  v_refunded bigint;
begin
  select * into v_invoice
  from public.billing_invoices
  where id = p_invoice_id and deleted_at is null
  for update;

  if not found then raise exception 'Invoice not found.'; end if;

  if auth.uid() is not null
     and not (
       public.has_permission(v_invoice.business_id, 'billing_invoices.manage', null)
       or public.is_business_owner(v_invoice.business_id)
     ) then
    raise exception 'Permission denied to calculate invoice totals.';
  end if;

  select
    coalesce(sum(subtotal_cents),0),
    coalesce(sum(discount_cents),0),
    coalesce(sum(tax_cents),0),
    coalesce(sum(total_cents),0)
  into v_subtotal, v_discount, v_tax, v_total
  from public.billing_invoice_items
  where invoice_id = p_invoice_id;

  select coalesce(sum(amount_cents),0) into v_credits
  from public.billing_credit_applications
  where invoice_id = p_invoice_id;

  select coalesce(sum(amount_cents),0) into v_paid
  from public.billing_payment_transactions
  where invoice_id = p_invoice_id and status in ('succeeded','partially_refunded','refunded');

  select coalesce(sum(amount_cents),0) into v_refunded
  from public.billing_refunds
  where invoice_id = p_invoice_id and status = 'succeeded';

  update public.billing_invoices
  set subtotal_cents = v_subtotal,
      discount_cents = v_discount,
      tax_cents = v_tax,
      credit_applied_cents = v_credits,
      total_cents = greatest(v_total - v_credits,0),
      paid_cents = v_paid,
      refunded_cents = v_refunded,
      balance_due_cents = greatest((v_total - v_credits) - (v_paid - v_refunded),0),
      status = case
        when status in ('void','uncollectible') then status
        when greatest((v_total - v_credits) - (v_paid - v_refunded),0) = 0
             and (v_total - v_credits) > 0 then 'paid'::public.billing_invoice_status
        when (v_paid - v_refunded) > 0 then 'partially_paid'::public.billing_invoice_status
        when status = 'draft' then status
        when due_date is not null and due_date < current_date then 'past_due'::public.billing_invoice_status
        else 'open'::public.billing_invoice_status
      end,
      paid_at = case
        when greatest((v_total - v_credits) - (v_paid - v_refunded),0) = 0
             and (v_total - v_credits) > 0 then coalesce(paid_at,now())
        else paid_at
      end,
      updated_at = now(),
      updated_by = auth.uid()
  where id = p_invoice_id
  returning * into v_invoice;

  return v_invoice;
end;
$$;

create or replace function public.post_billing_invoice(p_invoice_id uuid)
returns public.billing_invoices
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_invoice public.billing_invoices%rowtype;
begin
  select * into v_invoice
  from public.billing_invoices
  where id = p_invoice_id and deleted_at is null
  for update;

  if not found then raise exception 'Invoice not found.'; end if;
  if v_invoice.status <> 'draft' then raise exception 'Only draft invoices may be posted.'; end if;

  if auth.uid() is not null
     and not (
       public.has_permission(v_invoice.business_id, 'billing_invoices.manage', null)
       or public.is_business_owner(v_invoice.business_id)
     ) then
    raise exception 'Permission denied to post invoice.';
  end if;

  perform public.recalculate_billing_invoice_totals(p_invoice_id);

  if not exists (select 1 from public.billing_invoice_items where invoice_id = p_invoice_id) then
    raise exception 'Invoice must contain at least one line.';
  end if;

  update public.billing_invoices
  set status = case when total_cents = 0 then 'paid'::public.billing_invoice_status else 'open'::public.billing_invoice_status end,
      issue_date = coalesce(issue_date,current_date),
      due_date = coalesce(due_date,current_date),
      posted_at = now(),
      posted_by = auth.uid(),
      paid_at = case when total_cents = 0 then now() else paid_at end,
      updated_at = now(),
      updated_by = auth.uid()
  where id = p_invoice_id
  returning * into v_invoice;

  return v_invoice;
end;
$$;

create or replace function public.issue_billing_credit(
  p_business_id uuid,
  p_amount_cents bigint,
  p_currency char(3),
  p_description text,
  p_credit_type public.billing_credit_type,
  p_idempotency_key text,
  p_subscription_id uuid default null,
  p_expires_at timestamptz default null,
  p_metadata jsonb default '{}'::jsonb
)
returns public.billing_credits
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_credit public.billing_credits%rowtype;
begin
  if p_amount_cents <= 0 then raise exception 'Credit amount must be positive.'; end if;
  if auth.uid() is not null
     and not (
       public.has_permission(p_business_id, 'billing_credits.manage', null)
       or public.is_business_owner(p_business_id)
     ) then
    raise exception 'Permission denied to issue credit.';
  end if;

  insert into public.billing_credits (
    business_id, subscription_id, credit_type, status, currency,
    original_amount_cents, remaining_amount_cents, description,
    expires_at, idempotency_key, metadata, created_by, updated_by
  ) values (
    p_business_id, p_subscription_id, p_credit_type, 'available', upper(p_currency),
    p_amount_cents, p_amount_cents, p_description,
    p_expires_at, p_idempotency_key, coalesce(p_metadata,'{}'::jsonb), auth.uid(), auth.uid()
  )
  on conflict (business_id,idempotency_key) where idempotency_key is not null
  do update set idempotency_key = excluded.idempotency_key
  returning * into v_credit;

  return v_credit;
end;
$$;

create or replace function public.apply_billing_credit(
  p_credit_id uuid,
  p_invoice_id uuid,
  p_amount_cents bigint,
  p_idempotency_key text
)
returns public.billing_credit_applications
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_credit public.billing_credits%rowtype;
  v_invoice public.billing_invoices%rowtype;
  v_application public.billing_credit_applications%rowtype;
begin
  select * into v_credit from public.billing_credits where id=p_credit_id and deleted_at is null for update;
  select * into v_invoice from public.billing_invoices where id=p_invoice_id and deleted_at is null for update;

  if v_credit.id is null or v_invoice.id is null then raise exception 'Credit or invoice not found.'; end if;
  if v_credit.business_id <> v_invoice.business_id then raise exception 'Credit and invoice business mismatch.'; end if;
  if v_credit.currency <> v_invoice.currency then raise exception 'Credit and invoice currency mismatch.'; end if;
  if v_credit.status not in ('available','partially_applied') then raise exception 'Credit is not available.'; end if;
  if v_credit.expires_at is not null and v_credit.expires_at <= now() then raise exception 'Credit has expired.'; end if;
  if p_amount_cents <= 0 or p_amount_cents > v_credit.remaining_amount_cents then raise exception 'Invalid credit application amount.'; end if;

  if auth.uid() is not null
     and not (
       public.has_permission(v_credit.business_id, 'billing_credits.manage', null)
       or public.is_business_owner(v_credit.business_id)
     ) then
    raise exception 'Permission denied to apply credit.';
  end if;

  insert into public.billing_credit_applications (
    business_id, credit_id, invoice_id, amount_cents,
    applied_by, idempotency_key
  ) values (
    v_credit.business_id, p_credit_id, p_invoice_id, p_amount_cents,
    auth.uid(), p_idempotency_key
  )
  on conflict (business_id,idempotency_key) where idempotency_key is not null
  do update set idempotency_key = excluded.idempotency_key
  returning * into v_application;

  update public.billing_credits
  set remaining_amount_cents = remaining_amount_cents - p_amount_cents,
      status = case
        when remaining_amount_cents - p_amount_cents = 0 then 'applied'::public.billing_credit_status
        else 'partially_applied'::public.billing_credit_status
      end,
      updated_at = now(), updated_by = auth.uid()
  where id = p_credit_id;

  perform public.recalculate_billing_invoice_totals(p_invoice_id);
  return v_application;
end;
$$;

create or replace function public.record_billing_payment(
  p_business_id uuid,
  p_invoice_id uuid,
  p_payment_method_id uuid,
  p_provider_id uuid,
  p_amount_cents bigint,
  p_fee_cents bigint,
  p_currency char(3),
  p_status public.billing_payment_status,
  p_idempotency_key text,
  p_provider_transaction_id text default null,
  p_provider_response jsonb default '{}'::jsonb,
  p_metadata jsonb default '{}'::jsonb
)
returns public.billing_payment_transactions
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_payment public.billing_payment_transactions%rowtype;
  v_invoice public.billing_invoices%rowtype;
begin
  if p_amount_cents <= 0 or p_fee_cents < 0 or p_fee_cents > p_amount_cents then
    raise exception 'Invalid payment amount or fee.';
  end if;

  select * into v_invoice from public.billing_invoices where id=p_invoice_id and deleted_at is null;
  if v_invoice.id is null or v_invoice.business_id <> p_business_id then raise exception 'Invoice business mismatch.'; end if;
  if v_invoice.currency <> upper(p_currency) then raise exception 'Payment currency mismatch.'; end if;

  if auth.uid() is not null
     and not (
       public.has_permission(p_business_id, 'billing_payments.manage', null)
       or public.is_business_owner(p_business_id)
     ) then
    raise exception 'Permission denied to record payment.';
  end if;

  insert into public.billing_payment_transactions (
    business_id, invoice_id, subscription_id, payment_method_id,
    provider_id, transaction_type, status, currency,
    amount_cents, fee_cents, net_amount_cents, provider_transaction_id,
    idempotency_key, succeeded_at, failed_at,
    provider_response, metadata, created_by, updated_by
  ) values (
    p_business_id, p_invoice_id, v_invoice.subscription_id, p_payment_method_id,
    p_provider_id, 'sale', p_status, upper(p_currency),
    p_amount_cents, p_fee_cents, p_amount_cents-p_fee_cents, p_provider_transaction_id,
    p_idempotency_key,
    case when p_status='succeeded' then now() end,
    case when p_status='failed' then now() end,
    coalesce(p_provider_response,'{}'::jsonb), coalesce(p_metadata,'{}'::jsonb), auth.uid(), auth.uid()
  )
  on conflict (business_id,idempotency_key)
  do update set idempotency_key=excluded.idempotency_key
  returning * into v_payment;

  perform public.recalculate_billing_invoice_totals(p_invoice_id);
  return v_payment;
end;
$$;

create or replace function public.issue_billing_refund(
  p_payment_transaction_id uuid,
  p_amount_cents bigint,
  p_reason text,
  p_idempotency_key text,
  p_provider_refund_id text default null,
  p_status public.billing_refund_status default 'pending',
  p_provider_response jsonb default '{}'::jsonb,
  p_metadata jsonb default '{}'::jsonb
)
returns public.billing_refunds
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_payment public.billing_payment_transactions%rowtype;
  v_refunded bigint;
  v_refund public.billing_refunds%rowtype;
begin
  select * into v_payment
  from public.billing_payment_transactions
  where id=p_payment_transaction_id
  for update;

  if v_payment.id is null then raise exception 'Payment transaction not found.'; end if;
  if v_payment.status not in ('succeeded','partially_refunded') then raise exception 'Payment is not refundable.'; end if;

  select coalesce(sum(amount_cents),0) into v_refunded
  from public.billing_refunds
  where payment_transaction_id=p_payment_transaction_id and status in ('pending','processing','succeeded');

  if p_amount_cents <= 0 or v_refunded + p_amount_cents > v_payment.amount_cents then
    raise exception 'Refund exceeds refundable amount.';
  end if;

  if auth.uid() is not null
     and not (
       public.has_permission(v_payment.business_id, 'billing_payments.manage', null)
       or public.is_business_owner(v_payment.business_id)
     ) then
    raise exception 'Permission denied to issue refund.';
  end if;

  insert into public.billing_refunds (
    business_id, payment_transaction_id, invoice_id, status,
    currency, amount_cents, reason, provider_refund_id,
    idempotency_key, processed_at, provider_response, metadata,
    requested_by, updated_by
  ) values (
    v_payment.business_id, v_payment.id, v_payment.invoice_id, p_status,
    v_payment.currency, p_amount_cents, p_reason, p_provider_refund_id,
    p_idempotency_key, case when p_status='succeeded' then now() end,
    coalesce(p_provider_response,'{}'::jsonb), coalesce(p_metadata,'{}'::jsonb),
    auth.uid(), auth.uid()
  )
  on conflict (business_id,idempotency_key)
  do update set idempotency_key=excluded.idempotency_key
  returning * into v_refund;

  if p_status='succeeded' then
    update public.billing_payment_transactions
    set refunded_amount_cents = refunded_amount_cents + p_amount_cents,
        status = case
          when refunded_amount_cents + p_amount_cents = amount_cents then 'refunded'::public.billing_payment_status
          else 'partially_refunded'::public.billing_payment_status
        end,
        updated_at=now(), updated_by=auth.uid()
    where id=v_payment.id;
  end if;

  if v_payment.invoice_id is not null then
    perform public.recalculate_billing_invoice_totals(v_payment.invoice_id);
  end if;

  return v_refund;
end;
$$;

create or replace function public.prevent_posted_invoice_mutation()
returns trigger
language plpgsql
as $$
begin
  if old.posted_at is not null then
    if new.business_id is distinct from old.business_id
       or new.invoice_number is distinct from old.invoice_number
       or new.currency is distinct from old.currency
       or new.subscription_id is distinct from old.subscription_id
       or new.billing_profile_id is distinct from old.billing_profile_id
       or new.tax_profile_id is distinct from old.tax_profile_id
       or new.issue_date is distinct from old.issue_date
       or new.due_date is distinct from old.due_date
       or new.service_period_start is distinct from old.service_period_start
       or new.service_period_end is distinct from old.service_period_end
       or new.billing_snapshot is distinct from old.billing_snapshot
       or new.tax_snapshot is distinct from old.tax_snapshot then
      raise exception 'Posted invoice identity and snapshot fields are immutable.';
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.prevent_posted_invoice_line_mutation()
returns trigger
language plpgsql
as $$
declare
  v_posted_at timestamptz;
begin
  select posted_at into v_posted_at
  from public.billing_invoices
  where id=coalesce(new.invoice_id,old.invoice_id);

  if v_posted_at is not null then
    raise exception 'Posted invoice lines are immutable.';
  end if;
  return coalesce(new,old);
end;
$$;

create or replace function public.prevent_succeeded_payment_delete()
returns trigger
language plpgsql
as $$
begin
  if old.status in ('succeeded','partially_refunded','refunded') then
    raise exception 'Successful payment transactions cannot be deleted.';
  end if;
  return old;
end;
$$;

-- =========================================================
-- TRIGGERS
-- =========================================================

drop trigger if exists billing_invoice_items_validate_scope on public.billing_invoice_items;
create trigger billing_invoice_items_validate_scope
before insert or update on public.billing_invoice_items
for each row execute function public.validate_billing_financial_scope();

drop trigger if exists billing_credit_applications_validate_scope on public.billing_credit_applications;
create trigger billing_credit_applications_validate_scope
before insert or update on public.billing_credit_applications
for each row execute function public.validate_billing_financial_scope();

drop trigger if exists billing_refunds_validate_scope on public.billing_refunds;
create trigger billing_refunds_validate_scope
before insert or update on public.billing_refunds
for each row execute function public.validate_billing_financial_scope();

drop trigger if exists billing_invoices_prevent_posted_mutation on public.billing_invoices;
create trigger billing_invoices_prevent_posted_mutation
before update on public.billing_invoices
for each row execute function public.prevent_posted_invoice_mutation();

drop trigger if exists billing_invoice_items_prevent_posted_insert on public.billing_invoice_items;
create trigger billing_invoice_items_prevent_posted_insert
before insert on public.billing_invoice_items
for each row execute function public.prevent_posted_invoice_line_mutation();

drop trigger if exists billing_invoice_items_prevent_posted_update on public.billing_invoice_items;
create trigger billing_invoice_items_prevent_posted_update
before update on public.billing_invoice_items
for each row execute function public.prevent_posted_invoice_line_mutation();

drop trigger if exists billing_invoice_items_prevent_posted_delete on public.billing_invoice_items;
create trigger billing_invoice_items_prevent_posted_delete
before delete on public.billing_invoice_items
for each row execute function public.prevent_posted_invoice_line_mutation();

drop trigger if exists billing_payment_transactions_prevent_success_delete on public.billing_payment_transactions;
create trigger billing_payment_transactions_prevent_success_delete
before delete on public.billing_payment_transactions
for each row execute function public.prevent_succeeded_payment_delete();

do $$
declare t text;
begin
  foreach t in array array[
    'billing_payment_providers','billing_tax_profiles','billing_payment_methods',
    'billing_invoices','billing_invoice_items','billing_credits',
    'billing_payment_transactions','billing_refunds'
  ] loop
    execute format('drop trigger if exists %I on public.%I',t||'_set_updated_at',t);
    execute format('create trigger %I before update on public.%I for each row execute function public.set_updated_at()',t||'_set_updated_at',t);
  end loop;
end $$;

do $$
declare t text;
begin
  foreach t in array array[
    'billing_tax_profiles','billing_payment_methods','billing_invoices',
    'billing_credits','billing_payment_transactions','billing_refunds'
  ] loop
    execute format('drop trigger if exists %I on public.%I',t||'_increment_version',t);
    execute format('create trigger %I before update on public.%I for each row execute function public.increment_billing_record_version()',t||'_increment_version',t);
  end loop;
end $$;

-- =========================================================
-- ROW LEVEL SECURITY
-- =========================================================

alter table public.billing_payment_providers enable row level security;
alter table public.billing_tax_profiles enable row level security;
alter table public.billing_payment_methods enable row level security;
alter table public.billing_invoices enable row level security;
alter table public.billing_invoice_items enable row level security;
alter table public.billing_credits enable row level security;
alter table public.billing_credit_applications enable row level security;
alter table public.billing_payment_transactions enable row level security;
alter table public.billing_refunds enable row level security;
alter table public.billing_provider_webhook_events enable row level security;

create policy billing_payment_providers_read on public.billing_payment_providers
for select to authenticated using (is_active=true);

create policy billing_tax_profiles_read on public.billing_tax_profiles
for select to authenticated using (
  public.has_permission(business_id,'billing.read',null) or public.is_business_owner(business_id)
);
create policy billing_tax_profiles_manage on public.billing_tax_profiles
to authenticated using (
  public.has_permission(business_id,'billing_tax.manage',null) or public.is_business_owner(business_id)
) with check (
  public.has_permission(business_id,'billing_tax.manage',null) or public.is_business_owner(business_id)
);

create policy billing_payment_methods_read on public.billing_payment_methods
for select to authenticated using (
  public.has_permission(business_id,'billing_payments.read',null) or public.is_business_owner(business_id)
);
create policy billing_payment_methods_manage on public.billing_payment_methods
to authenticated using (
  public.has_permission(business_id,'billing_payments.manage',null) or public.is_business_owner(business_id)
) with check (
  public.has_permission(business_id,'billing_payments.manage',null) or public.is_business_owner(business_id)
);

create policy billing_invoices_read on public.billing_invoices
for select to authenticated using (
  public.has_permission(business_id,'billing_invoices.read',null)
  or public.has_permission(business_id,'billing.read',null)
  or public.is_business_owner(business_id)
);
create policy billing_invoices_manage on public.billing_invoices
to authenticated using (
  public.has_permission(business_id,'billing_invoices.manage',null) or public.is_business_owner(business_id)
) with check (
  public.has_permission(business_id,'billing_invoices.manage',null) or public.is_business_owner(business_id)
);

create policy billing_invoice_items_read on public.billing_invoice_items
for select to authenticated using (
  public.has_permission(business_id,'billing_invoices.read',null)
  or public.has_permission(business_id,'billing.read',null)
  or public.is_business_owner(business_id)
);
create policy billing_invoice_items_manage on public.billing_invoice_items
to authenticated using (
  public.has_permission(business_id,'billing_invoices.manage',null) or public.is_business_owner(business_id)
) with check (
  public.has_permission(business_id,'billing_invoices.manage',null) or public.is_business_owner(business_id)
);

create policy billing_credits_read on public.billing_credits
for select to authenticated using (
  public.has_permission(business_id,'billing_credits.read',null) or public.is_business_owner(business_id)
);
create policy billing_credits_manage on public.billing_credits
to authenticated using (
  public.has_permission(business_id,'billing_credits.manage',null) or public.is_business_owner(business_id)
) with check (
  public.has_permission(business_id,'billing_credits.manage',null) or public.is_business_owner(business_id)
);

create policy billing_credit_applications_read on public.billing_credit_applications
for select to authenticated using (
  public.has_permission(business_id,'billing_credits.read',null) or public.is_business_owner(business_id)
);
create policy billing_credit_applications_insert on public.billing_credit_applications
for insert to authenticated with check (
  public.has_permission(business_id,'billing_credits.manage',null) or public.is_business_owner(business_id)
);

create policy billing_payment_transactions_read on public.billing_payment_transactions
for select to authenticated using (
  public.has_permission(business_id,'billing_payments.read',null) or public.is_business_owner(business_id)
);
create policy billing_payment_transactions_manage on public.billing_payment_transactions
to authenticated using (
  public.has_permission(business_id,'billing_payments.manage',null) or public.is_business_owner(business_id)
) with check (
  public.has_permission(business_id,'billing_payments.manage',null) or public.is_business_owner(business_id)
);

create policy billing_refunds_read on public.billing_refunds
for select to authenticated using (
  public.has_permission(business_id,'billing_payments.read',null) or public.is_business_owner(business_id)
);
create policy billing_refunds_manage on public.billing_refunds
to authenticated using (
  public.has_permission(business_id,'billing_payments.manage',null) or public.is_business_owner(business_id)
) with check (
  public.has_permission(business_id,'billing_payments.manage',null) or public.is_business_owner(business_id)
);

create policy billing_provider_webhook_events_read on public.billing_provider_webhook_events
for select to authenticated using (
  business_id is not null
  and (public.has_permission(business_id,'billing_webhooks.read',null) or public.is_business_owner(business_id))
);
create policy billing_provider_webhook_events_manage on public.billing_provider_webhook_events
to authenticated using (
  business_id is not null
  and (public.has_permission(business_id,'billing_webhooks.manage',null) or public.is_business_owner(business_id))
) with check (
  business_id is not null
  and (public.has_permission(business_id,'billing_webhooks.manage',null) or public.is_business_owner(business_id))
);

-- =========================================================
-- REPORTING VIEWS
-- =========================================================

create or replace view public.billing_open_invoices_v
with (security_invoker=true)
as
select
  i.id, i.business_id, i.subscription_id, i.invoice_number,
  i.status, i.currency, i.issue_date, i.due_date,
  i.total_cents, i.paid_cents, i.refunded_cents,
  i.credit_applied_cents, i.balance_due_cents,
  greatest(current_date-coalesce(i.due_date,current_date),0) as days_past_due
from public.billing_invoices i
where i.deleted_at is null
  and i.status in ('open','partially_paid','past_due');

create or replace view public.billing_payment_summary_v
with (security_invoker=true)
as
select
  p.business_id,
  p.currency,
  date_trunc('month',coalesce(p.succeeded_at,p.created_at)) as month_start,
  count(*) filter (where p.status in ('succeeded','partially_refunded','refunded')) as successful_payment_count,
  coalesce(sum(p.amount_cents) filter (where p.status in ('succeeded','partially_refunded','refunded')),0) as gross_collected_cents,
  coalesce(sum(p.refunded_amount_cents),0) as refunded_cents,
  coalesce(sum(p.fee_cents) filter (where p.status in ('succeeded','partially_refunded','refunded')),0) as fee_cents,
  coalesce(sum(p.net_amount_cents-p.refunded_amount_cents) filter (where p.status in ('succeeded','partially_refunded','refunded')),0) as net_collected_cents
from public.billing_payment_transactions p
group by p.business_id,p.currency,date_trunc('month',coalesce(p.succeeded_at,p.created_at));

create or replace view public.billing_subscription_revenue_v
with (security_invoker=true)
as
select
  i.business_id,
  i.subscription_id,
  i.currency,
  date_trunc('month',coalesce(i.posted_at,i.created_at)) as month_start,
  count(*) filter (where i.status <> 'void') as invoice_count,
  coalesce(sum(i.total_cents) filter (where i.status <> 'void'),0) as invoiced_cents,
  coalesce(sum(i.paid_cents-i.refunded_cents) filter (where i.status <> 'void'),0) as net_paid_cents,
  coalesce(sum(i.balance_due_cents) filter (where i.status in ('open','partially_paid','past_due')),0) as outstanding_cents
from public.billing_invoices i
where i.deleted_at is null
group by i.business_id,i.subscription_id,i.currency,date_trunc('month',coalesce(i.posted_at,i.created_at));

grant select on public.billing_open_invoices_v to authenticated;
grant select on public.billing_payment_summary_v to authenticated;
grant select on public.billing_subscription_revenue_v to authenticated;

-- =========================================================
-- GRANTS
-- =========================================================

grant select on public.billing_payment_providers to authenticated;
grant select,insert,update,delete on public.billing_tax_profiles to authenticated;
grant select,insert,update,delete on public.billing_payment_methods to authenticated;
grant select,insert,update,delete on public.billing_invoices to authenticated;
grant select,insert,update,delete on public.billing_invoice_items to authenticated;
grant select,insert,update,delete on public.billing_credits to authenticated;
grant select,insert on public.billing_credit_applications to authenticated;
grant select,insert,update,delete on public.billing_payment_transactions to authenticated;
grant select,insert,update,delete on public.billing_refunds to authenticated;
grant select,insert,update on public.billing_provider_webhook_events to authenticated;

grant all on public.billing_payment_providers to service_role;
grant all on public.billing_tax_profiles to service_role;
grant all on public.billing_payment_methods to service_role;
grant all on public.billing_invoices to service_role;
grant all on public.billing_invoice_items to service_role;
grant all on public.billing_credits to service_role;
grant all on public.billing_credit_applications to service_role;
grant all on public.billing_payment_transactions to service_role;
grant all on public.billing_refunds to service_role;
grant all on public.billing_provider_webhook_events to service_role;

revoke all on function public.recalculate_billing_invoice_totals(uuid) from public;
grant execute on function public.recalculate_billing_invoice_totals(uuid) to authenticated,service_role;
revoke all on function public.post_billing_invoice(uuid) from public;
grant execute on function public.post_billing_invoice(uuid) to authenticated,service_role;
revoke all on function public.issue_billing_credit(uuid,bigint,char,text,public.billing_credit_type,text,uuid,timestamptz,jsonb) from public;
grant execute on function public.issue_billing_credit(uuid,bigint,char,text,public.billing_credit_type,text,uuid,timestamptz,jsonb) to authenticated,service_role;
revoke all on function public.apply_billing_credit(uuid,uuid,bigint,text) from public;
grant execute on function public.apply_billing_credit(uuid,uuid,bigint,text) to authenticated,service_role;
revoke all on function public.record_billing_payment(uuid,uuid,uuid,uuid,bigint,bigint,char,public.billing_payment_status,text,text,jsonb,jsonb) from public;
grant execute on function public.record_billing_payment(uuid,uuid,uuid,uuid,bigint,bigint,char,public.billing_payment_status,text,text,jsonb,jsonb) to authenticated,service_role;
revoke all on function public.issue_billing_refund(uuid,bigint,text,text,text,public.billing_refund_status,jsonb,jsonb) from public;
grant execute on function public.issue_billing_refund(uuid,bigint,text,text,text,public.billing_refund_status,jsonb,jsonb) to authenticated,service_role;

-- =========================================================
-- DEFAULT PROVIDERS
-- =========================================================

insert into public.billing_payment_providers (
  code,name,is_active,supports_cards,supports_bank_debit,
  supports_refunds,supports_webhooks,configuration_schema,metadata
)
values
  ('stripe','Stripe',true,true,true,true,true,'{"required":["secret_key_reference","webhook_secret_reference"]}','{"system_provider":true}'),
  ('square','Square',true,true,true,true,true,'{"required":["access_token_reference","location_id"]}','{"system_provider":true}'),
  ('adyen','Adyen',true,true,true,true,true,'{"required":["api_key_reference","merchant_account"]}','{"system_provider":true}'),
  ('manual','Manual',true,false,false,true,false,'{}','{"system_provider":true}')
on conflict ((lower(code))) do update
set name=excluded.name,
    is_active=excluded.is_active,
    supports_cards=excluded.supports_cards,
    supports_bank_debit=excluded.supports_bank_debit,
    supports_refunds=excluded.supports_refunds,
    supports_webhooks=excluded.supports_webhooks,
    configuration_schema=excluded.configuration_schema,
    metadata=excluded.metadata,
    updated_at=now();

comment on table public.billing_invoices is 'Immutable-after-posting SaaS billing invoice headers.';
comment on table public.billing_invoice_items is 'Invoice lines for subscriptions, seats, usage, discounts, taxes, credits, and adjustments.';
comment on table public.billing_payment_transactions is 'Provider-independent billing payment transaction ledger.';
comment on table public.billing_refunds is 'Refund requests and provider processing results tied to payment transactions.';
comment on table public.billing_credits is 'Business credit balances available for future invoice application.';
comment on table public.billing_provider_webhook_events is 'Idempotent payment-provider webhook inbox and processing audit trail.';

commit;