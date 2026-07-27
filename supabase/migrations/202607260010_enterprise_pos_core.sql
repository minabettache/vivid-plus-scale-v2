-- =========================================================
-- VIVID+ MIGRATION 010
-- ENTERPRISE POS CORE
-- Registers, shifts, cash control, split tender, refunds,
-- receipts, manager overrides, device/offline operations
-- =========================================================

begin;

-- =========================================================
-- ENUMS
-- =========================================================

do $$ begin
  create type public.pos_register_status as enum ('active','inactive','maintenance','retired');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.register_session_status as enum ('open','closing','closed','cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.cash_event_type as enum (
    'opening_float','cash_sale','cash_refund','cash_drop',
    'paid_in','paid_out','safe_deposit','closing_count','adjustment'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.pos_payment_method_kind as enum (
    'cash','credit_card','debit_card','gift_card','store_credit',
    'mobile_wallet','bank_transfer','other'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.pos_payment_status as enum (
    'pending','authorized','captured','failed','voided','partially_refunded','refunded'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.refund_status as enum (
    'draft','pending_approval','approved','processing','completed','failed','cancelled'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.receipt_delivery_method as enum ('print','email','sms','qr','none');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.manager_override_status as enum ('requested','approved','denied','expired','cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.offline_operation_status as enum ('queued','processing','completed','failed','conflict','cancelled');
exception when duplicate_object then null; end $$;

-- =========================================================
-- PERMISSIONS
-- =========================================================
insert into public.permissions (
    code,
    module,
    description,
    is_sensitive
)
select *
from (
    values
      ('pos.read','pos','View POS registers, sessions, payments, receipts, and activity.',false),
      ('pos.operate','pos','Operate an assigned register and create POS activity.',false),
      ('pos.manage','pos','Manage registers, payment methods, devices, and POS settings.',true),
      ('pos.open_shift','pos','Open a register session with an opening float.',false),
      ('pos.close_shift','pos','Close and reconcile a register session.',true),
      ('pos.cash_manage','pos','Post cash drops, paid-in, paid-out, deposits, and adjustments.',true),
      ('pos.refund','pos','Create and process refunds.',true),
      ('pos.override','pos','Approve manager overrides for sensitive POS actions.',true),
      ('pos.receipt_reprint','pos','Reprint or redeliver receipts.',false),
      ('pos.offline_manage','pos','Review and resolve offline POS operation conflicts.',true)
) AS v(code,module,description,is_sensitive)
where not exists (
    select 1
    from public.permissions p
    where p.code = v.code
);

-- =========================================================
-- TABLES
-- =========================================================

create table if not exists public.pos_registers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  location_id uuid not null references public.business_locations(id) on delete restrict,
  code text not null,
  name text not null,
  status public.pos_register_status not null default 'active',
  device_identifier text,
  receipt_prefix text,
  next_receipt_sequence bigint not null default 1,
  settings jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint pos_registers_code_not_blank check (length(trim(code)) > 0),
  constraint pos_registers_name_not_blank check (length(trim(name)) > 0),
  constraint pos_registers_sequence_positive check (next_receipt_sequence >= 1),
  constraint pos_registers_settings_object check (jsonb_typeof(settings) = 'object'),
  constraint pos_registers_version_positive check (version >= 1)
);

create unique index if not exists pos_registers_business_code_uq
  on public.pos_registers (business_id, lower(code))
  where deleted_at is null;

create index if not exists pos_registers_location_idx
  on public.pos_registers (business_id, location_id, status)
  where deleted_at is null;

create table if not exists public.register_sessions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  location_id uuid not null references public.business_locations(id) on delete restrict,
  register_id uuid not null references public.pos_registers(id) on delete restrict,
  employee_id uuid not null references public.employees(id) on delete restrict,
  session_number text not null,
  status public.register_session_status not null default 'open',
  opened_at timestamptz not null default now(),
  closing_started_at timestamptz,
  closed_at timestamptz,
  opening_float_cents bigint not null default 0,
  expected_cash_cents bigint not null default 0,
  declared_cash_cents bigint,
  over_short_cents bigint,
  blind_count boolean not null default true,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  opened_by uuid references auth.users(id) on delete set null,
  closed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint register_sessions_number_not_blank check (length(trim(session_number)) > 0),
  constraint register_sessions_opening_nonnegative check (opening_float_cents >= 0),
  constraint register_sessions_expected_nonnegative check (expected_cash_cents >= 0),
  constraint register_sessions_declared_nonnegative check (declared_cash_cents is null or declared_cash_cents >= 0),
  constraint register_sessions_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint register_sessions_version_positive check (version >= 1),
  constraint register_sessions_close_math check (
    declared_cash_cents is null
    or over_short_cents = declared_cash_cents - expected_cash_cents
  ),
  constraint register_sessions_closed_state check (
    (status = 'closed' and closed_at is not null and declared_cash_cents is not null and over_short_cents is not null)
    or status <> 'closed'
  )
);

create unique index if not exists register_sessions_business_number_uq
  on public.register_sessions (business_id, lower(session_number));

create unique index if not exists register_sessions_one_open_per_register_uq
  on public.register_sessions (register_id)
  where status in ('open','closing');

create index if not exists register_sessions_employee_idx
  on public.register_sessions (business_id, employee_id, opened_at desc);

create table if not exists public.cash_drawer_events (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  location_id uuid not null references public.business_locations(id) on delete restrict,
  register_id uuid not null references public.pos_registers(id) on delete restrict,
  register_session_id uuid not null references public.register_sessions(id) on delete restrict,
  employee_id uuid references public.employees(id) on delete set null,
  event_type public.cash_event_type not null,
  amount_cents bigint not null,
  expected_cash_before_cents bigint not null,
  expected_cash_after_cents bigint not null,
  transaction_id uuid references public.transactions(id) on delete set null,
  refund_id uuid,
  reason text,
  notes text,
  idempotency_key text,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint cash_drawer_events_amount_nonzero check (amount_cents <> 0),
  constraint cash_drawer_events_math check (expected_cash_after_cents = expected_cash_before_cents + amount_cents),
  constraint cash_drawer_events_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint cash_drawer_events_idempotency_not_blank check (idempotency_key is null or length(trim(idempotency_key)) > 0)
);

create unique index if not exists cash_drawer_events_idempotency_uq
  on public.cash_drawer_events (business_id, idempotency_key)
  where idempotency_key is not null;

create index if not exists cash_drawer_events_session_idx
  on public.cash_drawer_events (register_session_id, occurred_at, id);

create table if not exists public.pos_payment_methods (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  location_id uuid references public.business_locations(id) on delete restrict,
  code text not null,
  name text not null,
  kind public.pos_payment_method_kind not null,
  is_active boolean not null default true,
  requires_reference boolean not null default false,
  allows_tips boolean not null default false,
  allows_change boolean not null default false,
  processing_config jsonb not null default '{}'::jsonb,
  display_order integer not null default 100,
  version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint pos_payment_methods_code_not_blank check (length(trim(code)) > 0),
  constraint pos_payment_methods_name_not_blank check (length(trim(name)) > 0),
  constraint pos_payment_methods_config_object check (jsonb_typeof(processing_config) = 'object'),
  constraint pos_payment_methods_display_order_nonnegative check (display_order >= 0),
  constraint pos_payment_methods_version_positive check (version >= 1)
);

create unique index if not exists pos_payment_methods_business_code_uq
  on public.pos_payment_methods (business_id, lower(code))
  where deleted_at is null and location_id is null;

create unique index if not exists pos_payment_methods_location_code_uq
  on public.pos_payment_methods (business_id, location_id, lower(code))
  where deleted_at is null and location_id is not null;

create table if not exists public.transaction_payments (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  location_id uuid not null references public.business_locations(id) on delete restrict,
  transaction_id uuid not null references public.transactions(id) on delete restrict,
  register_session_id uuid references public.register_sessions(id) on delete restrict,
  payment_method_id uuid not null references public.pos_payment_methods(id) on delete restrict,
  status public.pos_payment_status not null default 'pending',
  amount_cents bigint not null,
  tip_cents bigint not null default 0,
  change_given_cents bigint not null default 0,
  processor_reference text,
  authorization_code text,
  card_brand text,
  card_last_four character(4),
  idempotency_key text,
  metadata jsonb not null default '{}'::jsonb,
  authorized_at timestamptz,
  captured_at timestamptz,
  failed_at timestamptz,
  voided_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint transaction_payments_amount_positive check (amount_cents > 0),
  constraint transaction_payments_tip_nonnegative check (tip_cents >= 0),
  constraint transaction_payments_change_nonnegative check (change_given_cents >= 0),
  constraint transaction_payments_change_limit check (change_given_cents <= amount_cents),
  constraint transaction_payments_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint transaction_payments_last_four_format check (card_last_four is null or card_last_four ~ '^[0-9]{4}$'),
  constraint transaction_payments_idempotency_not_blank check (idempotency_key is null or length(trim(idempotency_key)) > 0)
);

create unique index if not exists transaction_payments_idempotency_uq
  on public.transaction_payments (business_id, idempotency_key)
  where idempotency_key is not null;

create index if not exists transaction_payments_transaction_idx
  on public.transaction_payments (transaction_id, created_at, id);

create table if not exists public.pos_refunds (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  location_id uuid not null references public.business_locations(id) on delete restrict,
  original_transaction_id uuid not null references public.transactions(id) on delete restrict,
  register_session_id uuid references public.register_sessions(id) on delete restrict,
  refund_number text not null,
  status public.refund_status not null default 'draft',
  reason_code text not null,
  reason_notes text,
  subtotal_cents bigint not null default 0,
  tax_cents bigint not null default 0,
  tip_cents bigint not null default 0,
  total_cents bigint not null default 0,
  requested_by_employee_id uuid references public.employees(id) on delete set null,
  approved_by_employee_id uuid references public.employees(id) on delete set null,
  completed_by_employee_id uuid references public.employees(id) on delete set null,
  requested_at timestamptz not null default now(),
  approved_at timestamptz,
  completed_at timestamptz,
  idempotency_key text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint pos_refunds_number_not_blank check (length(trim(refund_number)) > 0),
  constraint pos_refunds_reason_not_blank check (length(trim(reason_code)) > 0),
  constraint pos_refunds_amounts_nonnegative check (
    subtotal_cents >= 0 and tax_cents >= 0 and tip_cents >= 0 and total_cents >= 0
  ),
  constraint pos_refunds_total_math check (total_cents = subtotal_cents + tax_cents + tip_cents),
  constraint pos_refunds_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint pos_refunds_idempotency_not_blank check (idempotency_key is null or length(trim(idempotency_key)) > 0),
  constraint pos_refunds_completed_state check (status <> 'completed' or completed_at is not null)
);

create unique index if not exists pos_refunds_business_number_uq
  on public.pos_refunds (business_id, lower(refund_number));

create unique index if not exists pos_refunds_idempotency_uq
  on public.pos_refunds (business_id, idempotency_key)
  where idempotency_key is not null;

alter table public.cash_drawer_events
  drop constraint if exists cash_drawer_events_refund_id_fkey;

alter table public.cash_drawer_events
  add constraint cash_drawer_events_refund_id_fkey
  foreign key (refund_id) references public.pos_refunds(id) on delete set null;

create table if not exists public.pos_refund_items (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  refund_id uuid not null references public.pos_refunds(id) on delete restrict,
  original_transaction_item_id uuid not null references public.transaction_items(id) on delete restrict,
  product_id uuid references public.products(id) on delete set null,
  quantity numeric(12,3) not null,
  subtotal_cents bigint not null,
  tax_cents bigint not null default 0,
  total_cents bigint not null,
  restock_inventory boolean not null default true,
  restock_location_id uuid references public.business_locations(id) on delete restrict,
  reason text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint pos_refund_items_quantity_positive check (quantity > 0),
  constraint pos_refund_items_amounts_nonnegative check (subtotal_cents >= 0 and tax_cents >= 0 and total_cents >= 0),
  constraint pos_refund_items_total_math check (total_cents = subtotal_cents + tax_cents),
  constraint pos_refund_items_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists pos_refund_items_line_uq
  on public.pos_refund_items (refund_id, original_transaction_item_id);

create table if not exists public.manager_overrides (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  location_id uuid not null references public.business_locations(id) on delete restrict,
  register_id uuid references public.pos_registers(id) on delete restrict,
  register_session_id uuid references public.register_sessions(id) on delete restrict,
  requested_by_employee_id uuid not null references public.employees(id) on delete restrict,
  decided_by_employee_id uuid references public.employees(id) on delete set null,
  action_code text not null,
  target_type text,
  target_id uuid,
  status public.manager_override_status not null default 'requested',
  request_reason text not null,
  decision_notes text,
  requested_at timestamptz not null default now(),
  decided_at timestamptz,
  expires_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  constraint manager_overrides_action_not_blank check (length(trim(action_code)) > 0),
  constraint manager_overrides_reason_not_blank check (length(trim(request_reason)) > 0),
  constraint manager_overrides_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint manager_overrides_decision_state check (
    (status in ('approved','denied') and decided_by_employee_id is not null and decided_at is not null)
    or status not in ('approved','denied')
  )
);

create index if not exists manager_overrides_pending_idx
  on public.manager_overrides (business_id, location_id, status, requested_at)
  where status = 'requested';

create table if not exists public.pos_receipts (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  location_id uuid not null references public.business_locations(id) on delete restrict,
  register_id uuid references public.pos_registers(id) on delete set null,
  register_session_id uuid references public.register_sessions(id) on delete set null,
  transaction_id uuid references public.transactions(id) on delete restrict,
  refund_id uuid references public.pos_refunds(id) on delete restrict,
  receipt_number text not null,
  delivery_method public.receipt_delivery_method not null default 'print',
  recipient text,
  rendered_payload jsonb not null default '{}'::jsonb,
  delivery_status text not null default 'pending',
  delivery_attempts integer not null default 0,
  last_delivered_at timestamptz,
  reprint_count integer not null default 0,
  original_receipt_id uuid references public.pos_receipts(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint pos_receipts_number_not_blank check (length(trim(receipt_number)) > 0),
  constraint pos_receipts_payload_object check (jsonb_typeof(rendered_payload) = 'object'),
  constraint pos_receipts_attempts_nonnegative check (delivery_attempts >= 0),
  constraint pos_receipts_reprints_nonnegative check (reprint_count >= 0),
  constraint pos_receipts_subject_check check (
    (transaction_id is not null and refund_id is null)
    or (transaction_id is null and refund_id is not null)
  )
);

create unique index if not exists pos_receipts_business_number_uq
  on public.pos_receipts (business_id, lower(receipt_number));

create index if not exists pos_receipts_transaction_idx
  on public.pos_receipts (transaction_id, created_at desc)
  where transaction_id is not null;

create table if not exists public.pos_offline_operations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  location_id uuid not null references public.business_locations(id) on delete restrict,
  register_id uuid not null references public.pos_registers(id) on delete restrict,
  register_session_id uuid references public.register_sessions(id) on delete set null,
  client_operation_id text not null,
  operation_type text not null,
  status public.offline_operation_status not null default 'queued',
  payload jsonb not null,
  result_payload jsonb,
  conflict_reason text,
  attempt_count integer not null default 0,
  client_created_at timestamptz not null,
  first_received_at timestamptz not null default now(),
  last_attempted_at timestamptz,
  completed_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  constraint pos_offline_operations_client_id_not_blank check (length(trim(client_operation_id)) > 0),
  constraint pos_offline_operations_type_not_blank check (length(trim(operation_type)) > 0),
  constraint pos_offline_operations_payload_object check (jsonb_typeof(payload) = 'object'),
  constraint pos_offline_operations_result_object check (result_payload is null or jsonb_typeof(result_payload) = 'object'),
  constraint pos_offline_operations_attempt_nonnegative check (attempt_count >= 0)
);

create unique index if not exists pos_offline_operations_client_uq
  on public.pos_offline_operations (business_id, register_id, client_operation_id);

-- =========================================================
-- VALIDATION FUNCTIONS
-- =========================================================

create or replace function public.validate_pos_register_relationships()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.business_locations l
    where l.id = new.location_id
      and l.business_id = new.business_id
      and l.deleted_at is null
  ) then
    raise exception 'POS register location must belong to the same business.';
  end if;
  return new;
end;
$$;

create or replace function public.validate_register_session_relationships()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.pos_registers r
    where r.id = new.register_id
      and r.business_id = new.business_id
      and r.location_id = new.location_id
      and r.deleted_at is null
      and r.status = 'active'
  ) then
    raise exception 'Active register must belong to the same business and location.';
  end if;

  if not exists (
    select 1 from public.employees e
    where e.id = new.employee_id
      and e.business_id = new.business_id
      and e.deleted_at is null
      and e.status = 'active'
  ) then
    raise exception 'Register session employee must be active in the same business.';
  end if;

  return new;
end;
$$;

create or replace function public.validate_pos_payment_relationships()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.transactions t
    where t.id = new.transaction_id
      and t.business_id = new.business_id
      and t.location_id = new.location_id
  ) then
    raise exception 'Payment transaction must belong to the same business and location.';
  end if;

  if not exists (
    select 1 from public.pos_payment_methods pm
    where pm.id = new.payment_method_id
      and pm.business_id = new.business_id
      and pm.deleted_at is null
      and pm.is_active = true
      and (pm.location_id is null or pm.location_id = new.location_id)
  ) then
    raise exception 'Payment method is not active for this business and location.';
  end if;

  if new.register_session_id is not null and not exists (
    select 1 from public.register_sessions rs
    where rs.id = new.register_session_id
      and rs.business_id = new.business_id
      and rs.location_id = new.location_id
      and rs.status in ('open','closing')
  ) then
    raise exception 'Payment register session must be open and belong to the same tenant.';
  end if;

  return new;
end;
$$;

create or replace function public.validate_pos_refund_relationships()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.transactions t
    where t.id = new.original_transaction_id
      and t.business_id = new.business_id
      and t.location_id = new.location_id
      and t.status in ('completed','partially_refunded')
  ) then
    raise exception 'Refund requires a completed transaction in the same business and location.';
  end if;
  return new;
end;
$$;

create or replace function public.prevent_pos_ledger_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  raise exception 'POS ledger records are immutable. Post a compensating record instead.';
end;
$$;

-- =========================================================
-- CASH DRAWER RPC
-- =========================================================

create or replace function public.post_cash_drawer_event(
  p_business_id uuid,
  p_register_session_id uuid,
  p_event_type public.cash_event_type,
  p_amount_cents bigint,
  p_employee_id uuid default null,
  p_transaction_id uuid default null,
  p_refund_id uuid default null,
  p_reason text default null,
  p_notes text default null,
  p_idempotency_key text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns public.cash_drawer_events
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_session public.register_sessions%rowtype;
  v_existing public.cash_drawer_events%rowtype;
  v_event public.cash_drawer_events%rowtype;
  v_before bigint;
  v_after bigint;
begin
  if p_amount_cents is null or p_amount_cents = 0 then
    raise exception 'Cash drawer event amount must be non-zero.';
  end if;

  if p_metadata is null or jsonb_typeof(p_metadata) <> 'object' then
    raise exception 'Metadata must be a JSON object.';
  end if;

  if p_idempotency_key is not null then
    select * into v_existing
    from public.cash_drawer_events
    where business_id = p_business_id
      and idempotency_key = p_idempotency_key;

    if found then
      return v_existing;
    end if;
  end if;

  select * into v_session
  from public.register_sessions
  where id = p_register_session_id
    and business_id = p_business_id
    and status in ('open','closing')
  for update;

  if not found then
    raise exception 'Open register session not found.';
  end if;

  if auth.uid() is not null
     and not public.has_permission(
       p_business_id,
       case when p_event_type in ('cash_sale','cash_refund') then 'pos.operate' else 'pos.cash_manage' end,
       v_session.location_id
     ) then
    raise exception 'Permission denied for cash drawer event.';
  end if;

  v_before := v_session.expected_cash_cents;
  v_after := v_before + p_amount_cents;

  if v_after < 0 then
    raise exception 'Expected drawer cash cannot become negative.';
  end if;

  update public.register_sessions
  set expected_cash_cents = v_after,
      updated_at = now()
  where id = v_session.id;

  insert into public.cash_drawer_events (
    business_id, location_id, register_id, register_session_id,
    employee_id, event_type, amount_cents,
    expected_cash_before_cents, expected_cash_after_cents,
    transaction_id, refund_id, reason, notes,
    idempotency_key, metadata, created_by
  )
  values (
    p_business_id, v_session.location_id, v_session.register_id, v_session.id,
    coalesce(p_employee_id, v_session.employee_id), p_event_type, p_amount_cents,
    v_before, v_after,
    p_transaction_id, p_refund_id, p_reason, p_notes,
    p_idempotency_key, p_metadata, auth.uid()
  )
  returning * into v_event;

  return v_event;
exception
  when unique_violation then
    if p_idempotency_key is not null then
      select * into v_existing
      from public.cash_drawer_events
      where business_id = p_business_id
        and idempotency_key = p_idempotency_key;
      if found then return v_existing; end if;
    end if;
    raise;
end;
$$;

-- =========================================================
-- SHIFT RPCs
-- =========================================================

create or replace function public.open_register_session(
  p_business_id uuid,
  p_register_id uuid,
  p_employee_id uuid,
  p_session_number text,
  p_opening_float_cents bigint default 0,
  p_blind_count boolean default true,
  p_notes text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns public.register_sessions
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_register public.pos_registers%rowtype;
  v_session public.register_sessions%rowtype;
begin
  if p_session_number is null or length(trim(p_session_number)) = 0 then
    raise exception 'Session number is required.';
  end if;

  if p_opening_float_cents < 0 then
    raise exception 'Opening float cannot be negative.';
  end if;

  select * into v_register
  from public.pos_registers
  where id = p_register_id
    and business_id = p_business_id
    and status = 'active'
    and deleted_at is null;

  if not found then
    raise exception 'Active register not found.';
  end if;

  if auth.uid() is not null
     and not public.has_permission(p_business_id, 'pos.open_shift', v_register.location_id) then
    raise exception 'Permission denied to open register shift.';
  end if;

  insert into public.register_sessions (
    business_id, location_id, register_id, employee_id,
    session_number, opening_float_cents, expected_cash_cents,
    blind_count, notes, metadata, opened_by
  )
  values (
    p_business_id, v_register.location_id, v_register.id, p_employee_id,
    trim(p_session_number), p_opening_float_cents, p_opening_float_cents,
    p_blind_count, p_notes, p_metadata, auth.uid()
  )
  returning * into v_session;

  if p_opening_float_cents > 0 then
    insert into public.cash_drawer_events (
      business_id, location_id, register_id, register_session_id,
      employee_id, event_type, amount_cents,
      expected_cash_before_cents, expected_cash_after_cents,
      reason, metadata, created_by
    )
    values (
      p_business_id, v_register.location_id, v_register.id, v_session.id,
      p_employee_id, 'opening_float', p_opening_float_cents,
      0, p_opening_float_cents,
      'Opening float', '{}'::jsonb, auth.uid()
    );
  end if;

  return v_session;
end;
$$;

create or replace function public.close_register_session(
  p_business_id uuid,
  p_register_session_id uuid,
  p_declared_cash_cents bigint,
  p_notes text default null
)
returns public.register_sessions
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_session public.register_sessions%rowtype;
begin
  if p_declared_cash_cents is null or p_declared_cash_cents < 0 then
    raise exception 'Declared cash must be zero or greater.';
  end if;

  select * into v_session
  from public.register_sessions
  where id = p_register_session_id
    and business_id = p_business_id
    and status in ('open','closing')
  for update;

  if not found then
    raise exception 'Open register session not found.';
  end if;

  if auth.uid() is not null
     and not public.has_permission(p_business_id, 'pos.close_shift', v_session.location_id) then
    raise exception 'Permission denied to close register shift.';
  end if;

  update public.register_sessions
  set status = 'closed',
      closing_started_at = coalesce(closing_started_at, now()),
      closed_at = now(),
      declared_cash_cents = p_declared_cash_cents,
      over_short_cents = p_declared_cash_cents - expected_cash_cents,
      notes = coalesce(p_notes, notes),
      closed_by = auth.uid(),
      updated_at = now()
  where id = v_session.id
  returning * into v_session;

  return v_session;
end;
$$;

-- =========================================================
-- PAYMENT STATUS SYNCHRONIZATION
-- =========================================================

create or replace function public.refresh_transaction_payment_status()
returns trigger
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
declare
  v_transaction public.transactions%rowtype;
  v_captured bigint;
begin
  select * into v_transaction
  from public.transactions
  where id = new.transaction_id
  for update;

  if not found then return new; end if;

  select coalesce(sum(amount_cents - change_given_cents), 0)
  into v_captured
  from public.transaction_payments
  where transaction_id = new.transaction_id
    and status = 'captured';

  if v_transaction.status in ('draft','pending') then
    update public.transactions
    set payment_status =
      case
        when v_captured = 0 then 'unpaid'::public.payment_status
        when v_captured < total_cents then 'partially_paid'::public.payment_status
        else 'paid'::public.payment_status
      end,
      updated_at = now()
    where id = v_transaction.id;
  end if;

  return new;
end;
$$;

-- =========================================================
-- TRIGGERS
-- =========================================================

drop trigger if exists pos_registers_validate_relationships on public.pos_registers;
create trigger pos_registers_validate_relationships
before insert or update on public.pos_registers
for each row execute function public.validate_pos_register_relationships();

drop trigger if exists register_sessions_validate_relationships on public.register_sessions;
create trigger register_sessions_validate_relationships
before insert or update on public.register_sessions
for each row execute function public.validate_register_session_relationships();

drop trigger if exists transaction_payments_validate_relationships on public.transaction_payments;
create trigger transaction_payments_validate_relationships
before insert on public.transaction_payments
for each row execute function public.validate_pos_payment_relationships();

drop trigger if exists pos_refunds_validate_relationships on public.pos_refunds;
create trigger pos_refunds_validate_relationships
before insert or update on public.pos_refunds
for each row execute function public.validate_pos_refund_relationships();

drop trigger if exists transaction_payments_refresh_status on public.transaction_payments;
create trigger transaction_payments_refresh_status
after insert or update of status on public.transaction_payments
for each row execute function public.refresh_transaction_payment_status();

drop trigger if exists cash_drawer_events_block_update on public.cash_drawer_events;
create trigger cash_drawer_events_block_update
before update on public.cash_drawer_events
for each row execute function public.prevent_pos_ledger_mutation();

drop trigger if exists cash_drawer_events_block_delete on public.cash_drawer_events;
create trigger cash_drawer_events_block_delete
before delete on public.cash_drawer_events
for each row execute function public.prevent_pos_ledger_mutation();

drop trigger if exists transaction_payments_block_delete on public.transaction_payments;
create trigger transaction_payments_block_delete
before delete on public.transaction_payments
for each row execute function public.prevent_pos_ledger_mutation();

drop trigger if exists pos_registers_prevent_business_change on public.pos_registers;
create trigger pos_registers_prevent_business_change
before update on public.pos_registers
for each row execute function public.prevent_business_id_change();

drop trigger if exists register_sessions_prevent_business_change on public.register_sessions;
create trigger register_sessions_prevent_business_change
before update on public.register_sessions
for each row execute function public.prevent_business_id_change();

drop trigger if exists pos_payment_methods_prevent_business_change on public.pos_payment_methods;
create trigger pos_payment_methods_prevent_business_change
before update on public.pos_payment_methods
for each row execute function public.prevent_business_id_change();

drop trigger if exists pos_registers_set_updated_at on public.pos_registers;
create trigger pos_registers_set_updated_at
before update on public.pos_registers
for each row execute function public.set_updated_at();

drop trigger if exists register_sessions_set_updated_at on public.register_sessions;
create trigger register_sessions_set_updated_at
before update on public.register_sessions
for each row execute function public.set_updated_at();

drop trigger if exists pos_payment_methods_set_updated_at on public.pos_payment_methods;
create trigger pos_payment_methods_set_updated_at
before update on public.pos_payment_methods
for each row execute function public.set_updated_at();

drop trigger if exists pos_registers_increment_version on public.pos_registers;
create trigger pos_registers_increment_version
before update on public.pos_registers
for each row execute function public.increment_record_version();

drop trigger if exists register_sessions_increment_version on public.register_sessions;
create trigger register_sessions_increment_version
before update on public.register_sessions
for each row execute function public.increment_record_version();

drop trigger if exists pos_payment_methods_increment_version on public.pos_payment_methods;
create trigger pos_payment_methods_increment_version
before update on public.pos_payment_methods
for each row execute function public.increment_record_version();

-- =========================================================
-- DEFAULT PAYMENT METHODS
-- =========================================================

insert into public.pos_payment_methods (
  business_id, location_id, code, name, kind,
  is_active, requires_reference, allows_tips, allows_change, display_order
)
select b.id, null, v.code, v.name, v.kind, true, v.requires_reference, v.allows_tips, v.allows_change, v.display_order
from public.businesses b
cross join (
  values
    ('cash',        'Cash',          'cash'::public.pos_payment_method_kind, false, true,  true,  10),
    ('credit_card', 'Credit Card',   'credit_card'::public.pos_payment_method_kind, true, true, false, 20),
    ('debit_card',  'Debit Card',    'debit_card'::public.pos_payment_method_kind, true, true, false, 30),
    ('gift_card',   'Gift Card',     'gift_card'::public.pos_payment_method_kind, true, false, false, 40),
    ('store_credit','Store Credit',  'store_credit'::public.pos_payment_method_kind, true, false, false, 50)
) as v(code, name, kind, requires_reference, allows_tips, allows_change, display_order)
where b.deleted_at is null
on conflict do nothing;

-- =========================================================
-- ROLE PERMISSION PROVISIONING
-- =========================================================

create or replace function public.provision_pos_role_permissions(p_business_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
begin
  -- Owner and administrator receive every POS permission.
  insert into public.role_permissions (business_id, role_id, permission_id)
  select p_business_id, r.id, p.id
  from public.business_roles r
  cross join public.permissions p
  where r.business_id = p_business_id
    and r.deleted_at is null
    and r.code in ('owner','administrator')
    and p.module = 'pos'
  on conflict (role_id, permission_id) do nothing;

  -- Manager receives operational, reconciliation, refund, and override authority.
  insert into public.role_permissions (business_id, role_id, permission_id)
  select p_business_id, r.id, p.id
  from public.business_roles r
  cross join public.permissions p
  where r.business_id = p_business_id
    and r.deleted_at is null
    and r.code = 'manager'
    and p.code in (
      'pos.read','pos.operate','pos.open_shift','pos.close_shift',
      'pos.cash_manage','pos.refund','pos.override','pos.receipt_reprint'
    )
  on conflict (role_id, permission_id) do nothing;

  -- Cashier receives daily register operation permissions.
  insert into public.role_permissions (business_id, role_id, permission_id)
  select p_business_id, r.id, p.id
  from public.business_roles r
  cross join public.permissions p
  where r.business_id = p_business_id
    and r.deleted_at is null
    and r.code = 'cashier'
    and p.code in (
      'pos.read','pos.operate','pos.open_shift','pos.receipt_reprint'
    )
  on conflict (role_id, permission_id) do nothing;

  -- Auditor is read-only.
  insert into public.role_permissions (business_id, role_id, permission_id)
  select p_business_id, r.id, p.id
  from public.business_roles r
  cross join public.permissions p
  where r.business_id = p_business_id
    and r.deleted_at is null
    and r.code = 'auditor'
    and p.code = 'pos.read'
  on conflict (role_id, permission_id) do nothing;
end;
$$;

create or replace function public.provision_pos_for_new_business()
returns trigger
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
begin
  perform public.provision_pos_role_permissions(new.id);

  insert into public.pos_payment_methods (
    business_id, code, name, kind,
    is_active, requires_reference, allows_tips, allows_change, display_order
  )
  values
    (new.id, 'cash', 'Cash', 'cash', true, false, true, true, 10),
    (new.id, 'credit_card', 'Credit Card', 'credit_card', true, true, true, false, 20),
    (new.id, 'debit_card', 'Debit Card', 'debit_card', true, true, true, false, 30),
    (new.id, 'gift_card', 'Gift Card', 'gift_card', true, true, false, false, 40),
    (new.id, 'store_credit', 'Store Credit', 'store_credit', true, true, false, false, 50)
  on conflict do nothing;

  return new;
end;
$$;

select public.provision_pos_role_permissions(b.id)
from public.businesses b
where b.deleted_at is null;

drop trigger if exists businesses_provision_pos on public.businesses;
create trigger businesses_provision_pos
after insert on public.businesses
for each row execute function public.provision_pos_for_new_business();

-- =========================================================
-- ROW LEVEL SECURITY
-- =========================================================

alter table public.pos_registers enable row level security;
alter table public.pos_registers force row level security;
alter table public.register_sessions enable row level security;
alter table public.register_sessions force row level security;
alter table public.cash_drawer_events enable row level security;
alter table public.cash_drawer_events force row level security;
alter table public.pos_payment_methods enable row level security;
alter table public.pos_payment_methods force row level security;
alter table public.transaction_payments enable row level security;
alter table public.transaction_payments force row level security;
alter table public.pos_refunds enable row level security;
alter table public.pos_refunds force row level security;
alter table public.pos_refund_items enable row level security;
alter table public.pos_refund_items force row level security;
alter table public.manager_overrides enable row level security;
alter table public.manager_overrides force row level security;
alter table public.pos_receipts enable row level security;
alter table public.pos_receipts force row level security;
alter table public.pos_offline_operations enable row level security;
alter table public.pos_offline_operations force row level security;

drop policy if exists pos_registers_read on public.pos_registers;
create policy pos_registers_read on public.pos_registers
for select to authenticated
using (public.has_permission(business_id, 'pos.read', location_id));

drop policy if exists pos_registers_manage on public.pos_registers;
create policy pos_registers_manage on public.pos_registers
to authenticated
using (public.has_permission(business_id, 'pos.manage', location_id))
with check (public.has_permission(business_id, 'pos.manage', location_id));

drop policy if exists register_sessions_read on public.register_sessions;
create policy register_sessions_read on public.register_sessions
for select to authenticated
using (
  employee_id = public.current_employee_id(business_id)
  or public.has_permission(business_id, 'pos.read', location_id)
);

drop policy if exists register_sessions_insert on public.register_sessions;
create policy register_sessions_insert on public.register_sessions
for insert to authenticated
with check (public.has_permission(business_id, 'pos.open_shift', location_id));

drop policy if exists register_sessions_update on public.register_sessions;
create policy register_sessions_update on public.register_sessions
for update to authenticated
using (
  employee_id = public.current_employee_id(business_id)
  or public.has_permission(business_id, 'pos.close_shift', location_id)
)
with check (
  employee_id = public.current_employee_id(business_id)
  or public.has_permission(business_id, 'pos.close_shift', location_id)
);

drop policy if exists cash_drawer_events_read on public.cash_drawer_events;
create policy cash_drawer_events_read on public.cash_drawer_events
for select to authenticated
using (public.has_permission(business_id, 'pos.read', location_id));

drop policy if exists pos_payment_methods_read on public.pos_payment_methods;
create policy pos_payment_methods_read on public.pos_payment_methods
for select to authenticated
using (
  public.has_permission(business_id, 'pos.read', location_id)
  or (location_id is null and public.has_permission(business_id, 'pos.read'))
);

drop policy if exists pos_payment_methods_manage on public.pos_payment_methods;
create policy pos_payment_methods_manage on public.pos_payment_methods
to authenticated
using (public.has_permission(business_id, 'pos.manage', location_id))
with check (public.has_permission(business_id, 'pos.manage', location_id));

drop policy if exists transaction_payments_read on public.transaction_payments;
create policy transaction_payments_read on public.transaction_payments
for select to authenticated
using (public.has_permission(business_id, 'pos.read', location_id));

drop policy if exists transaction_payments_insert on public.transaction_payments;
create policy transaction_payments_insert on public.transaction_payments
for insert to authenticated
with check (public.has_permission(business_id, 'pos.operate', location_id));

drop policy if exists transaction_payments_update on public.transaction_payments;
create policy transaction_payments_update on public.transaction_payments
for update to authenticated
using (public.has_permission(business_id, 'pos.operate', location_id))
with check (public.has_permission(business_id, 'pos.operate', location_id));

drop policy if exists pos_refunds_read on public.pos_refunds;
create policy pos_refunds_read on public.pos_refunds
for select to authenticated
using (public.has_permission(business_id, 'pos.read', location_id));

drop policy if exists pos_refunds_manage on public.pos_refunds;
create policy pos_refunds_manage on public.pos_refunds
to authenticated
using (public.has_permission(business_id, 'pos.refund', location_id))
with check (public.has_permission(business_id, 'pos.refund', location_id));

drop policy if exists pos_refund_items_read on public.pos_refund_items;
create policy pos_refund_items_read on public.pos_refund_items
for select to authenticated
using (public.has_permission(business_id, 'pos.read'));

drop policy if exists pos_refund_items_manage on public.pos_refund_items;
create policy pos_refund_items_manage on public.pos_refund_items
to authenticated
using (public.has_permission(business_id, 'pos.refund'))
with check (public.has_permission(business_id, 'pos.refund'));

drop policy if exists manager_overrides_read on public.manager_overrides;
create policy manager_overrides_read on public.manager_overrides
for select to authenticated
using (
  requested_by_employee_id = public.current_employee_id(business_id)
  or public.has_permission(business_id, 'pos.override', location_id)
);

drop policy if exists manager_overrides_request on public.manager_overrides;
create policy manager_overrides_request on public.manager_overrides
for insert to authenticated
with check (public.has_permission(business_id, 'pos.operate', location_id));

drop policy if exists manager_overrides_decide on public.manager_overrides;
create policy manager_overrides_decide on public.manager_overrides
for update to authenticated
using (public.has_permission(business_id, 'pos.override', location_id))
with check (public.has_permission(business_id, 'pos.override', location_id));

drop policy if exists pos_receipts_read on public.pos_receipts;
create policy pos_receipts_read on public.pos_receipts
for select to authenticated
using (public.has_permission(business_id, 'pos.read', location_id));

drop policy if exists pos_receipts_insert on public.pos_receipts;
create policy pos_receipts_insert on public.pos_receipts
for insert to authenticated
with check (public.has_permission(business_id, 'pos.operate', location_id));

drop policy if exists pos_receipts_update on public.pos_receipts;
create policy pos_receipts_update on public.pos_receipts
for update to authenticated
using (public.has_permission(business_id, 'pos.receipt_reprint', location_id))
with check (public.has_permission(business_id, 'pos.receipt_reprint', location_id));

drop policy if exists pos_offline_operations_read on public.pos_offline_operations;
create policy pos_offline_operations_read on public.pos_offline_operations
for select to authenticated
using (
  public.has_permission(business_id, 'pos.read', location_id)
  or public.has_permission(business_id, 'pos.offline_manage', location_id)
);

drop policy if exists pos_offline_operations_insert on public.pos_offline_operations;
create policy pos_offline_operations_insert on public.pos_offline_operations
for insert to authenticated
with check (public.has_permission(business_id, 'pos.operate', location_id));

drop policy if exists pos_offline_operations_manage on public.pos_offline_operations;
create policy pos_offline_operations_manage on public.pos_offline_operations
for update to authenticated
using (public.has_permission(business_id, 'pos.offline_manage', location_id))
with check (public.has_permission(business_id, 'pos.offline_manage', location_id));

-- =========================================================
-- GRANTS
-- =========================================================

grant select, insert, update on public.pos_registers to authenticated;
grant select, insert, update on public.register_sessions to authenticated;
grant select on public.cash_drawer_events to authenticated;
grant select, insert, update on public.pos_payment_methods to authenticated;
grant select, insert, update on public.transaction_payments to authenticated;
grant select, insert, update on public.pos_refunds to authenticated;
grant select, insert, update on public.pos_refund_items to authenticated;
grant select, insert, update on public.manager_overrides to authenticated;
grant select, insert, update on public.pos_receipts to authenticated;
grant select, insert, update on public.pos_offline_operations to authenticated;

grant execute on function public.open_register_session(uuid,uuid,uuid,text,bigint,boolean,text,jsonb) to authenticated;
grant execute on function public.close_register_session(uuid,uuid,bigint,text) to authenticated;
grant execute on function public.post_cash_drawer_event(uuid,uuid,public.cash_event_type,bigint,uuid,uuid,uuid,text,text,text,jsonb) to authenticated;

comment on table public.pos_registers is 'Physical or virtual POS terminals assigned to tenant locations.';
comment on table public.register_sessions is 'Cashier shifts and cash reconciliation lifecycle for each POS register.';
comment on table public.cash_drawer_events is 'Append-only cash ledger for every movement affecting expected drawer cash.';
comment on table public.transaction_payments is 'Split-tender payment ledger associated with financial transactions.';
comment on table public.pos_refunds is 'Refund workflow header tied to an original completed transaction.';
comment on table public.pos_refund_items is 'Line-level quantities and amounts included in a POS refund.';
comment on table public.manager_overrides is 'Approval workflow for sensitive POS actions.';
comment on table public.pos_receipts is 'Immutable receipt snapshots and delivery history.';
comment on table public.pos_offline_operations is 'Idempotent queue for POS actions created while a device is offline.';

commit;
