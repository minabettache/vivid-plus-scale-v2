-- =========================================================
-- VIVID+ INVENTORY CORE
-- Migration 007
--
-- Creates:
--   1. product_barcodes
--   2. inventory_balances
--   3. inventory_movements (append-only ledger)
--   4. tenant relationship validation
--   5. atomic stock posting RPC
--   6. inventory_stock_summary reporting view
--
-- Security model:
--   - RLS enabled and forced
--   - no public table policies added yet
--   - posting RPC is restricted to service_role until the
--     authenticated employee authorization layer is installed
-- =========================================================

-- =========================================================
-- PRODUCT BARCODES
-- =========================================================

create table if not exists public.product_barcodes (
  id uuid primary key default gen_random_uuid(),

  business_id uuid not null
    references public.businesses(id)
    on delete restrict,

  product_id uuid not null
    references public.products(id)
    on delete restrict,

  barcode text not null,
  barcode_type text not null default 'upc',
  is_primary boolean not null default false,
  is_active boolean not null default true,

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
  deleted_at timestamptz,

  constraint product_barcodes_barcode_not_blank
    check (length(trim(barcode)) > 0),

  constraint product_barcodes_type_not_blank
    check (length(trim(barcode_type)) > 0),

  constraint product_barcodes_metadata_object_check
    check (jsonb_typeof(metadata) = 'object'),

  constraint product_barcodes_version_check
    check (version >= 1)
);

create unique index if not exists
  product_barcodes_business_barcode_unique
on public.product_barcodes (
  business_id,
  barcode
)
where deleted_at is null;

create unique index if not exists
  product_barcodes_product_primary_unique
on public.product_barcodes (
  business_id,
  product_id
)
where is_primary = true
  and deleted_at is null;

create index if not exists
  product_barcodes_product_id_idx
on public.product_barcodes (product_id)
where deleted_at is null;

create index if not exists
  product_barcodes_business_active_idx
on public.product_barcodes (
  business_id,
  is_active
)
where deleted_at is null;

-- =========================================================
-- INVENTORY BALANCES
-- One row per business + location + product.
-- This is a cached operational balance.
-- inventory_movements is the audit source of truth.
-- =========================================================

create table if not exists public.inventory_balances (
  id uuid primary key default gen_random_uuid(),

  business_id uuid not null
    references public.businesses(id)
    on delete restrict,

  location_id uuid not null
    references public.business_locations(id)
    on delete restrict,

  product_id uuid not null
    references public.products(id)
    on delete restrict,

  quantity_on_hand numeric(18,4) not null default 0,
  quantity_reserved numeric(18,4) not null default 0,
  quantity_incoming numeric(18,4) not null default 0,

  reorder_point numeric(18,4) not null default 0,
  minimum_stock numeric(18,4) not null default 0,
  maximum_stock numeric(18,4),

  average_cost_cents bigint not null default 0,

  last_counted_at timestamptz,
  last_movement_at timestamptz,

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
  deleted_at timestamptz,

  constraint inventory_balances_reserved_nonnegative
    check (quantity_reserved >= 0),

  constraint inventory_balances_incoming_nonnegative
    check (quantity_incoming >= 0),

  constraint inventory_balances_reorder_nonnegative
    check (reorder_point >= 0),

  constraint inventory_balances_minimum_nonnegative
    check (minimum_stock >= 0),

  constraint inventory_balances_maximum_nonnegative
    check (maximum_stock is null or maximum_stock >= 0),

  constraint inventory_balances_min_max_check
    check (
      maximum_stock is null
      or maximum_stock >= minimum_stock
    ),

  constraint inventory_balances_cost_nonnegative
    check (average_cost_cents >= 0),

  constraint inventory_balances_metadata_object_check
    check (jsonb_typeof(metadata) = 'object'),

  constraint inventory_balances_version_check
    check (version >= 1)
);

create unique index if not exists
  inventory_balances_business_location_product_unique
on public.inventory_balances (
  business_id,
  location_id,
  product_id
)
where deleted_at is null;

create index if not exists
  inventory_balances_business_location_idx
on public.inventory_balances (
  business_id,
  location_id
)
where deleted_at is null;

create index if not exists
  inventory_balances_business_product_idx
on public.inventory_balances (
  business_id,
  product_id
)
where deleted_at is null;

create index if not exists
  inventory_balances_low_stock_candidate_idx
on public.inventory_balances (
  business_id,
  location_id,
  reorder_point,
  quantity_on_hand
)
where deleted_at is null;

-- =========================================================
-- INVENTORY MOVEMENT LEDGER
-- Append-only. Never update or delete movement rows.
-- =========================================================

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),

  business_id uuid not null
    references public.businesses(id)
    on delete restrict,

  location_id uuid not null
    references public.business_locations(id)
    on delete restrict,

  product_id uuid not null
    references public.products(id)
    on delete restrict,

  balance_component text not null default 'on_hand',
  movement_type text not null,

  quantity_delta numeric(18,4) not null,

  quantity_before numeric(18,4) not null,
  quantity_after numeric(18,4) not null,

  unit_cost_cents bigint,
  inventory_value_delta_cents bigint,

  reference_type text,
  reference_id uuid,

  idempotency_key text,
  reason text,
  notes text,

  metadata jsonb not null default '{}'::jsonb,

  performed_by uuid
    references auth.users(id)
    on delete set null,

  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),

  constraint inventory_movements_component_check
    check (
      balance_component in ('on_hand', 'reserved', 'incoming')
    ),

  constraint inventory_movements_type_not_blank
    check (length(trim(movement_type)) > 0),

  constraint inventory_movements_quantity_nonzero
    check (quantity_delta <> 0),

  constraint inventory_movements_math_check
    check (quantity_after = quantity_before + quantity_delta),

  constraint inventory_movements_unit_cost_nonnegative
    check (unit_cost_cents is null or unit_cost_cents >= 0),

  constraint inventory_movements_idempotency_not_blank
    check (
      idempotency_key is null
      or length(trim(idempotency_key)) > 0
    ),

  constraint inventory_movements_metadata_object_check
    check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists
  inventory_movements_business_idempotency_unique
on public.inventory_movements (
  business_id,
  idempotency_key
)
where idempotency_key is not null;

create index if not exists
  inventory_movements_business_location_occurred_idx
on public.inventory_movements (
  business_id,
  location_id,
  occurred_at desc
);

create index if not exists
  inventory_movements_product_occurred_idx
on public.inventory_movements (
  product_id,
  occurred_at desc
);

create index if not exists
  inventory_movements_reference_idx
on public.inventory_movements (
  reference_type,
  reference_id
)
where reference_id is not null;

-- =========================================================
-- TENANT RELATIONSHIP VALIDATION
-- =========================================================

create or replace function public.validate_product_barcode_relationships()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.products p
    where p.id = new.product_id
      and p.business_id = new.business_id
      and p.deleted_at is null
  ) then
    raise exception
      'Barcode product must belong to the same business and must not be deleted.';
  end if;

  return new;
end;
$$;

drop trigger if exists
  product_barcodes_validate_relationships
on public.product_barcodes;

create trigger product_barcodes_validate_relationships
before insert or update of business_id, product_id
on public.product_barcodes
for each row
execute function public.validate_product_barcode_relationships();

create or replace function public.validate_inventory_relationships()
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
      'Inventory location must belong to the same business and must not be deleted.';
  end if;

  if not exists (
    select 1
    from public.products p
    where p.id = new.product_id
      and p.business_id = new.business_id
      and p.deleted_at is null
  ) then
    raise exception
      'Inventory product must belong to the same business and must not be deleted.';
  end if;

  return new;
end;
$$;

drop trigger if exists
  inventory_balances_validate_relationships
on public.inventory_balances;

create trigger inventory_balances_validate_relationships
before insert or update of business_id, location_id, product_id
on public.inventory_balances
for each row
execute function public.validate_inventory_relationships();

drop trigger if exists
  inventory_movements_validate_relationships
on public.inventory_movements;

create trigger inventory_movements_validate_relationships
before insert or update of business_id, location_id, product_id
on public.inventory_movements
for each row
execute function public.validate_inventory_relationships();

-- =========================================================
-- PREVENT TENANT TRANSFERS
-- =========================================================

drop trigger if exists
  product_barcodes_prevent_business_change
on public.product_barcodes;

create trigger product_barcodes_prevent_business_change
before update of business_id
on public.product_barcodes
for each row
execute function public.prevent_business_id_change();

drop trigger if exists
  inventory_balances_prevent_business_change
on public.inventory_balances;

create trigger inventory_balances_prevent_business_change
before update of business_id
on public.inventory_balances
for each row
execute function public.prevent_business_id_change();

-- =========================================================
-- APPEND-ONLY LEDGER PROTECTION
-- =========================================================

create or replace function public.prevent_inventory_movement_mutation()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  raise exception
    'Inventory movements are immutable. Post a reversing movement instead.';
end;
$$;

drop trigger if exists
  inventory_movements_prevent_update
on public.inventory_movements;

create trigger inventory_movements_prevent_update
before update on public.inventory_movements
for each row
execute function public.prevent_inventory_movement_mutation();

drop trigger if exists
  inventory_movements_prevent_delete
on public.inventory_movements;

create trigger inventory_movements_prevent_delete
before delete on public.inventory_movements
for each row
execute function public.prevent_inventory_movement_mutation();

-- =========================================================
-- PRIMARY BARCODE SYNCHRONIZATION
-- Keep public.products.barcode aligned with the selected primary barcode.
-- =========================================================

create or replace function public.sync_product_primary_barcode()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.is_primary = true
     and new.deleted_at is null then

    update public.product_barcodes
    set
      is_primary = false,
      updated_at = now()
    where business_id = new.business_id
      and product_id = new.product_id
      and id <> new.id
      and is_primary = true
      and deleted_at is null;

    update public.products
    set
      barcode = new.barcode,
      updated_at = now()
    where id = new.product_id
      and business_id = new.business_id
      and deleted_at is null;
  end if;

  return new;
end;
$$;

drop trigger if exists
  product_barcodes_sync_primary
on public.product_barcodes;

create trigger product_barcodes_sync_primary
after insert or update of is_primary, barcode, deleted_at
on public.product_barcodes
for each row
execute function public.sync_product_primary_barcode();

-- =========================================================
-- VERSION + UPDATED-AT TRIGGERS
-- =========================================================

drop trigger if exists
  product_barcodes_increment_version
on public.product_barcodes;

create trigger product_barcodes_increment_version
before update on public.product_barcodes
for each row
execute function public.increment_record_version();

drop trigger if exists
  inventory_balances_increment_version
on public.inventory_balances;

create trigger inventory_balances_increment_version
before update on public.inventory_balances
for each row
execute function public.increment_record_version();

drop trigger if exists
  product_barcodes_set_updated_at
on public.product_barcodes;

create trigger product_barcodes_set_updated_at
before update on public.product_barcodes
for each row
execute function public.set_updated_at();

drop trigger if exists
  inventory_balances_set_updated_at
on public.inventory_balances;

create trigger inventory_balances_set_updated_at
before update on public.inventory_balances
for each row
execute function public.set_updated_at();

-- =========================================================
-- ATOMIC STOCK POSTING FUNCTION
-- =========================================================

create or replace function public.post_inventory_movement(
  p_business_id uuid,
  p_location_id uuid,
  p_product_id uuid,
  p_quantity_delta numeric,
  p_movement_type text,
  p_balance_component text default 'on_hand',
  p_unit_cost_cents bigint default null,
  p_reference_type text default null,
  p_reference_id uuid default null,
  p_idempotency_key text default null,
  p_reason text default null,
  p_notes text default null,
  p_metadata jsonb default '{}'::jsonb,
  p_performed_by uuid default auth.uid(),
  p_occurred_at timestamptz default now()
)
returns public.inventory_movements
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product public.products%rowtype;
  v_balance public.inventory_balances%rowtype;
  v_existing public.inventory_movements%rowtype;

  v_before numeric(18,4);
  v_after numeric(18,4);

  v_effective_unit_cost bigint;
  v_new_average_cost bigint;
  v_value_delta bigint;
  v_result public.inventory_movements;
begin
  if p_quantity_delta is null or p_quantity_delta = 0 then
    raise exception 'Quantity delta must be non-zero.';
  end if;

  if p_balance_component not in ('on_hand', 'reserved', 'incoming') then
    raise exception 'Unsupported inventory balance component: %', p_balance_component;
  end if;

  if p_movement_type is null
     or length(trim(p_movement_type)) = 0 then
    raise exception 'Movement type is required.';
  end if;

  if p_unit_cost_cents is not null
     and p_unit_cost_cents < 0 then
    raise exception 'Unit cost cannot be negative.';
  end if;

  if p_metadata is null
     or jsonb_typeof(p_metadata) <> 'object' then
    raise exception 'Metadata must be a JSON object.';
  end if;

  if p_idempotency_key is not null then
    select im.*
    into v_existing
    from public.inventory_movements im
    where im.business_id = p_business_id
      and im.idempotency_key = p_idempotency_key;

    if found then
      return v_existing;
    end if;
  end if;

  if not exists (
    select 1
    from public.business_locations bl
    where bl.id = p_location_id
      and bl.business_id = p_business_id
      and bl.deleted_at is null
  ) then
    raise exception
      'Inventory location does not belong to this business.';
  end if;

  select p.*
  into v_product
  from public.products p
  where p.id = p_product_id
    and p.business_id = p_business_id
    and p.deleted_at is null;

  if not found then
    raise exception
      'Inventory product does not belong to this business.';
  end if;

  if v_product.track_inventory = false then
    raise exception
      'Product % is not configured to track inventory.',
      p_product_id;
  end if;

  insert into public.inventory_balances (
    business_id,
    location_id,
    product_id,
    average_cost_cents,
    created_by,
    updated_by
  )
  values (
    p_business_id,
    p_location_id,
    p_product_id,
    coalesce(v_product.cost_cents, 0),
    p_performed_by,
    p_performed_by
  )
  on conflict (
    business_id,
    location_id,
    product_id
  )
  where deleted_at is null
  do nothing;

  select ib.*
  into v_balance
  from public.inventory_balances ib
  where ib.business_id = p_business_id
    and ib.location_id = p_location_id
    and ib.product_id = p_product_id
    and ib.deleted_at is null
  for update;

  if p_balance_component = 'on_hand' then
    v_before := v_balance.quantity_on_hand;
  elsif p_balance_component = 'reserved' then
    v_before := v_balance.quantity_reserved;
  else
    v_before := v_balance.quantity_incoming;
  end if;

  v_after := v_before + p_quantity_delta;

  if p_balance_component in ('reserved', 'incoming')
     and v_after < 0 then
    raise exception
      '% inventory cannot become negative.',
      p_balance_component;
  end if;

  if p_balance_component = 'on_hand'
     and v_after < 0
     and v_product.allow_negative_inventory = false then
    raise exception
      'Insufficient inventory. Available on hand: %, requested delta: %.',
      v_before,
      p_quantity_delta;
  end if;

  v_effective_unit_cost := coalesce(
    p_unit_cost_cents,
    nullif(v_balance.average_cost_cents, 0),
    v_product.cost_cents,
    0
  );

  v_new_average_cost := v_balance.average_cost_cents;

  if p_balance_component = 'on_hand'
     and p_quantity_delta > 0
     and v_after > 0 then
    v_new_average_cost := round(
      (
        (greatest(v_before, 0) * v_balance.average_cost_cents)
        + (p_quantity_delta * v_effective_unit_cost)
      ) / v_after
    )::bigint;
  end if;

  if p_balance_component = 'on_hand' then
    v_value_delta := round(
      p_quantity_delta * v_effective_unit_cost
    )::bigint;
  else
    v_value_delta := null;
  end if;

  update public.inventory_balances
  set
    quantity_on_hand = case
      when p_balance_component = 'on_hand' then v_after
      else quantity_on_hand
    end,
    quantity_reserved = case
      when p_balance_component = 'reserved' then v_after
      else quantity_reserved
    end,
    quantity_incoming = case
      when p_balance_component = 'incoming' then v_after
      else quantity_incoming
    end,
    average_cost_cents = case
      when p_balance_component = 'on_hand' then v_new_average_cost
      else average_cost_cents
    end,
    last_movement_at = p_occurred_at,
    updated_by = p_performed_by,
    updated_at = now()
  where id = v_balance.id;

  insert into public.inventory_movements (
    business_id,
    location_id,
    product_id,
    balance_component,
    movement_type,
    quantity_delta,
    quantity_before,
    quantity_after,
    unit_cost_cents,
    inventory_value_delta_cents,
    reference_type,
    reference_id,
    idempotency_key,
    reason,
    notes,
    metadata,
    performed_by,
    occurred_at
  )
  values (
    p_business_id,
    p_location_id,
    p_product_id,
    p_balance_component,
    trim(p_movement_type),
    p_quantity_delta,
    v_before,
    v_after,
    case
      when p_balance_component = 'on_hand'
      then v_effective_unit_cost
      else null
    end,
    v_value_delta,
    p_reference_type,
    p_reference_id,
    p_idempotency_key,
    p_reason,
    p_notes,
    p_metadata,
    p_performed_by,
    p_occurred_at
  )
  returning *
  into v_result;

  return v_result;

exception
  when unique_violation then
    if p_idempotency_key is not null then
      select im.*
      into v_existing
      from public.inventory_movements im
      where im.business_id = p_business_id
        and im.idempotency_key = p_idempotency_key;

      if found then
        return v_existing;
      end if;
    end if;

    raise;
end;
$$;

revoke all
on function public.post_inventory_movement(
  uuid,
  uuid,
  uuid,
  numeric,
  text,
  text,
  bigint,
  text,
  uuid,
  text,
  text,
  text,
  jsonb,
  uuid,
  timestamptz
)
from public, anon, authenticated;

grant execute
on function public.post_inventory_movement(
  uuid,
  uuid,
  uuid,
  numeric,
  text,
  text,
  bigint,
  text,
  uuid,
  text,
  text,
  text,
  jsonb,
  uuid,
  timestamptz
)
to service_role;

-- =========================================================
-- REPORTING VIEW
-- =========================================================

create or replace view public.inventory_stock_summary
with (security_invoker = true)
as
select
  ib.id as inventory_balance_id,
  ib.business_id,
  ib.location_id,
  bl.name as location_name,
  ib.product_id,
  p.name as product_name,
  p.sku,
  p.barcode,
  p.product_type,
  p.status as product_status,

  ib.quantity_on_hand,
  ib.quantity_reserved,
  (ib.quantity_on_hand - ib.quantity_reserved) as quantity_available,
  ib.quantity_incoming,

  ib.reorder_point,
  ib.minimum_stock,
  ib.maximum_stock,

  ib.average_cost_cents,

  round(
    ib.quantity_on_hand * ib.average_cost_cents
  )::bigint as inventory_value_cents,

  (
    ib.quantity_on_hand - ib.quantity_reserved
  ) <= ib.reorder_point as is_low_stock,

  (
    ib.quantity_on_hand - ib.quantity_reserved
  ) <= 0 as is_out_of_stock,

  ib.last_counted_at,
  ib.last_movement_at,
  ib.updated_at
from public.inventory_balances ib
join public.products p
  on p.id = ib.product_id
 and p.business_id = ib.business_id
 and p.deleted_at is null
join public.business_locations bl
  on bl.id = ib.location_id
 and bl.business_id = ib.business_id
 and bl.deleted_at is null
where ib.deleted_at is null;

-- =========================================================
-- ROW LEVEL SECURITY
-- Policies will be installed after authenticated employee
-- membership and permission helpers are completed.
-- =========================================================

alter table public.product_barcodes
  enable row level security;

alter table public.product_barcodes
  force row level security;

alter table public.inventory_balances
  enable row level security;

alter table public.inventory_balances
  force row level security;

alter table public.inventory_movements
  enable row level security;

alter table public.inventory_movements
  force row level security;

-- =========================================================
-- COMMENTS
-- =========================================================

comment on table public.product_barcodes is
  'Business-owned alternate barcodes for products, including UPC, case, supplier, and internal barcodes.';

comment on table public.inventory_balances is
  'Location-specific cached inventory balances. The immutable inventory movement ledger is the audit source of truth.';

comment on table public.inventory_movements is
  'Append-only inventory ledger recording every on-hand, reserved, and incoming quantity change.';

comment on column public.inventory_balances.quantity_on_hand is
  'Physical quantity currently recorded at the location.';

comment on column public.inventory_balances.quantity_reserved is
  'Quantity committed to open orders or operational workflows but not yet deducted from on-hand stock.';

comment on column public.inventory_balances.quantity_incoming is
  'Quantity expected from approved purchasing or transfer workflows.';

comment on column public.inventory_balances.average_cost_cents is
  'Current weighted-average unit cost in the smallest currency unit.';

comment on function public.post_inventory_movement(
  uuid,
  uuid,
  uuid,
  numeric,
  text,
  text,
  bigint,
  text,
  uuid,
  text,
  text,
  text,
  jsonb,
  uuid,
  timestamptz
) is
  'Atomically locks a location-product balance, validates tenant ownership, posts a quantity change, recalculates weighted-average cost, and writes an immutable ledger entry.';

comment on view public.inventory_stock_summary is
  'Location-level inventory reporting view with available stock, valuation, low-stock, and out-of-stock indicators.';
