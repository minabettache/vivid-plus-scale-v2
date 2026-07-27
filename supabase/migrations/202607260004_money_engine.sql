-- =========================================================
-- VIVID+ MONEY ENGINE
-- Migration 004
--
-- Creates:
--   1. visits
--   2. transactions
--   3. transaction_items
--
-- Purpose:
--   - Record customer visits
--   - Preserve verified revenue history
--   - Preserve product-level purchase history
--   - Power CLV, average ticket, profit, retention,
--     loyalty, campaign attribution, and AI insights
-- =========================================================

-- =========================================================
-- ENUMS
-- =========================================================

do $$
begin
  create type public.visit_status as enum (
    'open',
    'completed',
    'cancelled'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.visit_source as enum (
    'employee_app',
    'customer_app',
    'qr_check_in',
    'pos_import',
    'website',
    'event',
    'manual',
    'api',
    'other'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.transaction_status as enum (
    'draft',
    'pending',
    'completed',
    'voided',
    'partially_refunded',
    'refunded'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.transaction_source as enum (
    'employee_app',
    'customer_app',
    'pos_import',
    'online',
    'manual',
    'api',
    'other'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.payment_status as enum (
    'unpaid',
    'partially_paid',
    'paid',
    'partially_refunded',
    'refunded',
    'failed'
  );
exception
  when duplicate_object then null;
end $$;

-- =========================================================
-- VISITS
-- =========================================================

create table if not exists public.visits (
  id uuid primary key default gen_random_uuid(),

  business_id uuid not null
    references public.businesses(id)
    on delete restrict,

  location_id uuid not null
    references public.business_locations(id)
    on delete restrict,

  membership_id uuid
    references public.memberships(id)
    on delete set null,

  checked_in_by_employee_id uuid
    references public.employees(id)
    on delete set null,

  visit_number text not null,

  status public.visit_status not null default 'open',
  source public.visit_source not null default 'manual',

  checked_in_at timestamptz not null default now(),
  checked_out_at timestamptz,

  guest_count integer not null default 1,

  notes text,

  metadata jsonb not null default '{}'::jsonb,

  version integer not null default 1,

  created_by uuid
    references auth.users(id)
    on delete set null,

  updated_by uuid
    references auth.users(id)
    on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint visits_number_not_blank
    check (length(trim(visit_number)) > 0),

  constraint visits_guest_count_check
    check (guest_count between 1 and 1000),

  constraint visits_checkout_time_check
    check (
      checked_out_at is null
      or checked_out_at >= checked_in_at
    ),

  constraint visits_completed_checkout_check
    check (
      status <> 'completed'
      or checked_out_at is not null
    ),

  constraint visits_version_check
    check (version >= 1),

  constraint visits_metadata_object_check
    check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists
  visits_business_number_unique
on public.visits (
  business_id,
  lower(visit_number)
);

create index if not exists
  visits_business_id_idx
on public.visits (business_id);

create index if not exists
  visits_location_id_idx
on public.visits (location_id);

create index if not exists
  visits_membership_id_idx
on public.visits (membership_id)
where membership_id is not null;

create index if not exists
  visits_employee_id_idx
on public.visits (checked_in_by_employee_id)
where checked_in_by_employee_id is not null;

create index if not exists
  visits_business_status_idx
on public.visits (
  business_id,
  status
);

create index if not exists
  visits_business_checkin_idx
on public.visits (
  business_id,
  checked_in_at desc
);

create index if not exists
  visits_location_checkin_idx
on public.visits (
  location_id,
  checked_in_at desc
);

create index if not exists
  visits_membership_checkin_idx
on public.visits (
  membership_id,
  checked_in_at desc
)
where membership_id is not null;

-- =========================================================
-- TRANSACTIONS
-- =========================================================

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),

  business_id uuid not null
    references public.businesses(id)
    on delete restrict,

  location_id uuid not null
    references public.business_locations(id)
    on delete restrict,

  membership_id uuid
    references public.memberships(id)
    on delete set null,

  visit_id uuid
    references public.visits(id)
    on delete set null,

  employee_id uuid
    references public.employees(id)
    on delete set null,

  transaction_number text not null,

  external_transaction_id text,
  external_source text,

  status public.transaction_status not null default 'draft',
  payment_status public.payment_status not null default 'unpaid',
  source public.transaction_source not null default 'manual',

  currency_code char(3) not null default 'USD',

  subtotal_cents bigint not null default 0,
  discount_cents bigint not null default 0,
  tax_cents bigint not null default 0,
  tip_cents bigint not null default 0,

  total_cents bigint not null default 0,

  estimated_cost_cents bigint not null default 0,

  refunded_cents bigint not null default 0,

  occurred_at timestamptz not null default now(),
  completed_at timestamptz,
  voided_at timestamptz,

  notes text,

  metadata jsonb not null default '{}'::jsonb,

  version integer not null default 1,

  created_by uuid
    references auth.users(id)
    on delete set null,

  updated_by uuid
    references auth.users(id)
    on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint transactions_number_not_blank
    check (length(trim(transaction_number)) > 0),

  constraint transactions_currency_code_check
    check (currency_code = upper(currency_code)),

  constraint transactions_subtotal_nonnegative
    check (subtotal_cents >= 0),

  constraint transactions_discount_nonnegative
    check (discount_cents >= 0),

  constraint transactions_tax_nonnegative
    check (tax_cents >= 0),

  constraint transactions_tip_nonnegative
    check (tip_cents >= 0),

  constraint transactions_total_nonnegative
    check (total_cents >= 0),

  constraint transactions_cost_nonnegative
    check (estimated_cost_cents >= 0),

  constraint transactions_refunded_nonnegative
    check (refunded_cents >= 0),

  constraint transactions_discount_limit_check
    check (discount_cents <= subtotal_cents),

  constraint transactions_total_math_check
    check (
      total_cents =
        subtotal_cents
        - discount_cents
        + tax_cents
        + tip_cents
    ),

  constraint transactions_refund_limit_check
    check (refunded_cents <= total_cents),

  constraint transactions_completed_time_check
    check (
      status not in (
        'completed',
        'partially_refunded',
        'refunded'
      )
      or completed_at is not null
    ),

  constraint transactions_voided_time_check
    check (
      status <> 'voided'
      or voided_at is not null
    ),

  constraint transactions_status_refund_check
    check (
      (
        status = 'refunded'
        and refunded_cents = total_cents
      )
      or (
        status = 'partially_refunded'
        and refunded_cents > 0
        and refunded_cents < total_cents
      )
      or status not in (
        'refunded',
        'partially_refunded'
      )
    ),

  constraint transactions_version_check
    check (version >= 1),

  constraint transactions_metadata_object_check
    check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists
  transactions_business_number_unique
on public.transactions (
  business_id,
  lower(transaction_number)
);

create unique index if not exists
  transactions_business_external_unique
on public.transactions (
  business_id,
  lower(external_source),
  external_transaction_id
)
where external_source is not null
  and external_transaction_id is not null;

create index if not exists
  transactions_business_id_idx
on public.transactions (business_id);

create index if not exists
  transactions_location_id_idx
on public.transactions (location_id);

create index if not exists
  transactions_membership_id_idx
on public.transactions (membership_id)
where membership_id is not null;

create index if not exists
  transactions_visit_id_idx
on public.transactions (visit_id)
where visit_id is not null;

create index if not exists
  transactions_employee_id_idx
on public.transactions (employee_id)
where employee_id is not null;

create index if not exists
  transactions_business_status_idx
on public.transactions (
  business_id,
  status
);

create index if not exists
  transactions_business_occurred_idx
on public.transactions (
  business_id,
  occurred_at desc
);

create index if not exists
  transactions_location_occurred_idx
on public.transactions (
  location_id,
  occurred_at desc
);

create index if not exists
  transactions_membership_occurred_idx
on public.transactions (
  membership_id,
  occurred_at desc
)
where membership_id is not null;

create index if not exists
  transactions_completed_revenue_idx
on public.transactions (
  business_id,
  completed_at desc
)
where status in (
  'completed',
  'partially_refunded',
  'refunded'
);

-- =========================================================
-- TRANSACTION ITEMS
-- =========================================================

create table if not exists public.transaction_items (
  id uuid primary key default gen_random_uuid(),

  business_id uuid not null
    references public.businesses(id)
    on delete restrict,

  transaction_id uuid not null
    references public.transactions(id)
    on delete restrict,

  product_id uuid
    references public.products(id)
    on delete set null,

  line_number integer not null,

  product_name_snapshot text not null,
  product_sku_snapshot text,
  product_type_snapshot public.product_type,

  quantity numeric(12,3) not null default 1,

  unit_price_cents bigint not null default 0,
  unit_cost_cents bigint,

  subtotal_cents bigint not null default 0,
  discount_cents bigint not null default 0,
  tax_cents bigint not null default 0,

  total_cents bigint not null default 0,

  estimated_cost_cents bigint not null default 0,

  notes text,

  metadata jsonb not null default '{}'::jsonb,

  created_by uuid
    references auth.users(id)
    on delete set null,

  created_at timestamptz not null default now(),

  constraint transaction_items_line_number_check
    check (line_number >= 1),

  constraint transaction_items_name_not_blank
    check (length(trim(product_name_snapshot)) > 0),

  constraint transaction_items_quantity_check
    check (quantity > 0),

  constraint transaction_items_unit_price_nonnegative
    check (unit_price_cents >= 0),

  constraint transaction_items_unit_cost_nonnegative
    check (
      unit_cost_cents is null
      or unit_cost_cents >= 0
    ),

  constraint transaction_items_subtotal_nonnegative
    check (subtotal_cents >= 0),

  constraint transaction_items_discount_nonnegative
    check (discount_cents >= 0),

  constraint transaction_items_tax_nonnegative
    check (tax_cents >= 0),

  constraint transaction_items_total_nonnegative
    check (total_cents >= 0),

  constraint transaction_items_cost_nonnegative
    check (estimated_cost_cents >= 0),

  constraint transaction_items_discount_limit_check
    check (discount_cents <= subtotal_cents),

  constraint transaction_items_total_math_check
    check (
      total_cents =
        subtotal_cents
        - discount_cents
        + tax_cents
    ),

  constraint transaction_items_metadata_object_check
    check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists
  transaction_items_transaction_line_unique
on public.transaction_items (
  transaction_id,
  line_number
);

create index if not exists
  transaction_items_business_id_idx
on public.transaction_items (business_id);

create index if not exists
  transaction_items_transaction_id_idx
on public.transaction_items (transaction_id);

create index if not exists
  transaction_items_product_id_idx
on public.transaction_items (product_id)
where product_id is not null;

create index if not exists
  transaction_items_business_product_idx
on public.transaction_items (
  business_id,
  product_id
)
where product_id is not null;

-- =========================================================
-- VISIT TENANT VALIDATION
-- =========================================================

create or replace function
  public.validate_visit_business_relationships()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.business_locations bl
    where bl.id = new.location_id
      and bl.business_id = new.business_id
      and bl.deleted_at is null
  ) then
    raise exception
      'Visit location must belong to the same business and must not be deleted.';
  end if;

  if new.membership_id is not null then
    if not exists (
      select 1
      from public.memberships m
      where m.id = new.membership_id
        and m.business_id = new.business_id
        and m.deleted_at is null
    ) then
      raise exception
        'Visit membership must belong to the same business.';
    end if;
  end if;

  if new.checked_in_by_employee_id is not null then
    if not exists (
      select 1
      from public.employees e
      where e.id = new.checked_in_by_employee_id
        and e.business_id = new.business_id
        and e.deleted_at is null
    ) then
      raise exception
        'Visit employee must belong to the same business.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists
  visits_validate_business_relationships
on public.visits;

create trigger visits_validate_business_relationships
before insert or update of
  business_id,
  location_id,
  membership_id,
  checked_in_by_employee_id
on public.visits
for each row
execute function
  public.validate_visit_business_relationships();

-- =========================================================
-- TRANSACTION TENANT VALIDATION
-- =========================================================

create or replace function
  public.validate_transaction_business_relationships()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.business_locations bl
    where bl.id = new.location_id
      and bl.business_id = new.business_id
      and bl.deleted_at is null
  ) then
    raise exception
      'Transaction location must belong to the same business and must not be deleted.';
  end if;

  if new.membership_id is not null then
    if not exists (
      select 1
      from public.memberships m
      where m.id = new.membership_id
        and m.business_id = new.business_id
        and m.deleted_at is null
    ) then
      raise exception
        'Transaction membership must belong to the same business.';
    end if;
  end if;

  if new.visit_id is not null then
    if not exists (
      select 1
      from public.visits v
      where v.id = new.visit_id
        and v.business_id = new.business_id
        and v.location_id = new.location_id
    ) then
      raise exception
        'Transaction visit must belong to the same business and location.';
    end if;
  end if;

  if new.employee_id is not null then
    if not exists (
      select 1
      from public.employees e
      where e.id = new.employee_id
        and e.business_id = new.business_id
        and e.deleted_at is null
    ) then
      raise exception
        'Transaction employee must belong to the same business.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists
  transactions_validate_business_relationships
on public.transactions;

create trigger transactions_validate_business_relationships
before insert or update of
  business_id,
  location_id,
  membership_id,
  visit_id,
  employee_id
on public.transactions
for each row
execute function
  public.validate_transaction_business_relationships();

-- =========================================================
-- TRANSACTION ITEM TENANT VALIDATION
-- =========================================================

create or replace function
  public.validate_transaction_item_relationships()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.transactions t
    where t.id = new.transaction_id
      and t.business_id = new.business_id
  ) then
    raise exception
      'Transaction item must belong to the same business as its transaction.';
  end if;

  if new.product_id is not null then
    if not exists (
      select 1
      from public.products p
      where p.id = new.product_id
        and p.business_id = new.business_id
        and p.deleted_at is null
    ) then
      raise exception
        'Transaction item product must belong to the same business.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists
  transaction_items_validate_relationships
on public.transaction_items;

create trigger transaction_items_validate_relationships
before insert or update of
  business_id,
  transaction_id,
  product_id
on public.transaction_items
for each row
execute function
  public.validate_transaction_item_relationships();

-- =========================================================
-- FINANCIAL IMMUTABILITY
-- =========================================================

create or replace function
  public.prevent_terminal_transaction_mutation()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if old.status in (
    'completed',
    'voided',
    'partially_refunded',
    'refunded'
  ) then
    raise exception
      'Terminal transactions are immutable. Create an adjustment or refund record instead.';
  end if;

  return new;
end;
$$;

drop trigger if exists
  transactions_prevent_terminal_mutation
on public.transactions;

create trigger transactions_prevent_terminal_mutation
before update on public.transactions
for each row
execute function
  public.prevent_terminal_transaction_mutation();

create or replace function
  public.prevent_transaction_delete()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  raise exception
    'Transactions cannot be deleted. Use a void or adjustment record.';
end;
$$;

drop trigger if exists
  transactions_prevent_delete
on public.transactions;

create trigger transactions_prevent_delete
before delete on public.transactions
for each row
execute function
  public.prevent_transaction_delete();

create or replace function
  public.protect_transaction_item_mutation()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  parent_status public.transaction_status;
begin
  select t.status
  into parent_status
  from public.transactions t
  where t.id = old.transaction_id;

  if parent_status is null then
    raise exception
      'Parent transaction could not be found.';
  end if;

  if parent_status not in ('draft', 'pending') then
    raise exception
      'Items belonging to terminal transactions are immutable.';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

drop trigger if exists
  transaction_items_protect_update
on public.transaction_items;

create trigger transaction_items_protect_update
before update on public.transaction_items
for each row
execute function
  public.protect_transaction_item_mutation();

drop trigger if exists
  transaction_items_protect_delete
on public.transaction_items;

create trigger transaction_items_protect_delete
before delete on public.transaction_items
for each row
execute function
  public.protect_transaction_item_mutation();

create or replace function
  public.prevent_completed_visit_mutation()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if old.status in ('completed', 'cancelled') then
    raise exception
      'Completed or cancelled visits are immutable.';
  end if;

  return new;
end;
$$;

drop trigger if exists
  visits_prevent_terminal_mutation
on public.visits;

create trigger visits_prevent_terminal_mutation
before update on public.visits
for each row
execute function
  public.prevent_completed_visit_mutation();

-- =========================================================
-- PREVENT TENANT TRANSFERS
-- =========================================================

drop trigger if exists
  visits_prevent_business_change
on public.visits;

create trigger visits_prevent_business_change
before update of business_id
on public.visits
for each row
execute function public.prevent_business_id_change();

drop trigger if exists
  transactions_prevent_business_change
on public.transactions;

create trigger transactions_prevent_business_change
before update of business_id
on public.transactions
for each row
execute function public.prevent_business_id_change();

drop trigger if exists
  transaction_items_prevent_business_change
on public.transaction_items;

create trigger transaction_items_prevent_business_change
before update of business_id
on public.transaction_items
for each row
execute function public.prevent_business_id_change();

-- =========================================================
-- VERSION AND UPDATED-AT MANAGEMENT
-- =========================================================

drop trigger if exists
  visits_increment_version
on public.visits;

create trigger visits_increment_version
before update on public.visits
for each row
execute function public.increment_record_version();

drop trigger if exists
  transactions_increment_version
on public.transactions;

create trigger transactions_increment_version
before update on public.transactions
for each row
execute function public.increment_record_version();

drop trigger if exists
  visits_set_updated_at
on public.visits;

create trigger visits_set_updated_at
before update on public.visits
for each row
execute function public.set_updated_at();

drop trigger if exists
  transactions_set_updated_at
on public.transactions;

create trigger transactions_set_updated_at
before update on public.transactions
for each row
execute function public.set_updated_at();

-- =========================================================
-- ROW LEVEL SECURITY
-- No public policies are added yet.
-- Access remains denied by default.
-- =========================================================

alter table public.visits
  enable row level security;

alter table public.visits
  force row level security;

alter table public.transactions
  enable row level security;

alter table public.transactions
  force row level security;

alter table public.transaction_items
  enable row level security;

alter table public.transaction_items
  force row level security;

-- =========================================================
-- COMMENTS
-- =========================================================

comment on table public.visits is
  'Verified customer presence at a business location, including visits without purchases.';

comment on table public.transactions is
  'Financial source-of-truth record for customer purchases and verified business revenue.';

comment on table public.transaction_items is
  'Immutable product-level snapshots belonging to transactions.';

comment on column public.transactions.total_cents is
  'Gross charged amount before refunds, stored in the smallest currency unit.';

comment on column public.transactions.refunded_cents is
  'Amount refunded from the original transaction. Refund adjustments will be stored separately in a future migration.';

comment on column public.transactions.estimated_cost_cents is
  'Historical estimated cost used to calculate gross profit without depending on current product cost.';

comment on column public.transaction_items.product_name_snapshot is
  'Historical product name preserved even when the catalog product changes or is removed.';

comment on column public.transaction_items.unit_price_cents is
  'Actual selling price per unit at the time of the transaction.';

comment on function
  public.prevent_terminal_transaction_mutation() is
  'Protects completed, voided, and refunded financial records from modification.';

comment on function
  public.protect_transaction_item_mutation() is
  'Prevents item changes after the parent transaction reaches a terminal state.';

comment on function
  public.validate_transaction_business_relationships() is
  'Prevents cross-tenant transaction relationships.';

comment on function
  public.validate_transaction_item_relationships() is
  'Prevents transaction items from connecting to another business transaction or product.';
