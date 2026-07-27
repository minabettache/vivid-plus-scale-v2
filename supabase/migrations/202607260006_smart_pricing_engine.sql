-- =========================================================
-- VIVID+ SMART PRICING ENGINE
-- Migration 006
-- =========================================================

-- Flexible location-aware pricing rules for products and categories.
-- Rules are evaluated in the business/location timezone and support
-- overnight windows such as 10:00 PM through 2:00 AM.

do $$
begin
  create type public.pricing_adjustment_type as enum (
    'fixed_price',
    'amount_adjustment',
    'percentage_adjustment'
  );
exception when duplicate_object then null;
end $$;

do $$
begin
  create type public.pricing_rule_status as enum (
    'draft',
    'active',
    'inactive',
    'archived'
  );
exception when duplicate_object then null;
end $$;

create table if not exists public.pricing_rules (
  id uuid primary key default gen_random_uuid(),

  business_id uuid not null
    references public.businesses(id) on delete restrict,

  location_id uuid
    references public.business_locations(id) on delete cascade,

  product_id uuid
    references public.products(id) on delete cascade,

  category_id uuid
    references public.product_categories(id) on delete cascade,

  name text not null,
  description text,

  status public.pricing_rule_status not null default 'draft',
  adjustment_type public.pricing_adjustment_type not null,

  -- fixed_price and amount_adjustment use cents.
  amount_cents bigint,
  -- 10,000 basis points = 100%. A 20% discount is -2,000.
  percentage_basis_points integer,

  priority integer not null default 100,
  is_stackable boolean not null default false,

  -- Optional eligibility gates.
  membership_required boolean not null default false,
  event_code text,
  promotion_code text,

  -- PostgreSQL EXTRACT(DOW): Sunday=0 through Saturday=6.
  valid_days smallint[] not null
    default array[0,1,2,3,4,5,6]::smallint[],

  valid_start_time time,
  valid_end_time time,

  starts_at timestamptz,
  ends_at timestamptz,

  metadata jsonb not null default '{}'::jsonb,
  version integer not null default 1,

  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,

  constraint pricing_rules_name_not_blank
    check (length(trim(name)) > 0),

  constraint pricing_rules_target_check
    check (
      (product_id is not null and category_id is null)
      or (product_id is null and category_id is not null)
    ),

  constraint pricing_rules_value_check
    check (
      (adjustment_type in ('fixed_price', 'amount_adjustment')
        and amount_cents is not null
        and percentage_basis_points is null)
      or
      (adjustment_type = 'percentage_adjustment'
        and percentage_basis_points is not null
        and amount_cents is null)
    ),

  constraint pricing_rules_fixed_price_nonnegative
    check (
      adjustment_type <> 'fixed_price'
      or amount_cents >= 0
    ),

  constraint pricing_rules_percentage_range
    check (
      percentage_basis_points is null
      or percentage_basis_points between -10000 and 100000
    ),

  constraint pricing_rules_valid_days_check
    check (
      cardinality(valid_days) between 1 and 7
      and valid_days <@ array[0,1,2,3,4,5,6]::smallint[]
    ),

  constraint pricing_rules_date_range_check
    check (starts_at is null or ends_at is null or ends_at >= starts_at),

  constraint pricing_rules_version_check check (version >= 1),
  constraint pricing_rules_metadata_object_check
    check (jsonb_typeof(metadata) = 'object')
);

create index if not exists pricing_rules_business_active_idx
  on public.pricing_rules (business_id, status, priority desc)
  where deleted_at is null;

create index if not exists pricing_rules_product_idx
  on public.pricing_rules (business_id, product_id, status, priority desc)
  where product_id is not null and deleted_at is null;

create index if not exists pricing_rules_category_idx
  on public.pricing_rules (business_id, category_id, status, priority desc)
  where category_id is not null and deleted_at is null;

create index if not exists pricing_rules_location_idx
  on public.pricing_rules (location_id, status, priority desc)
  where location_id is not null and deleted_at is null;

create or replace function public.validate_pricing_rule_relationships()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.location_id is not null and not exists (
    select 1 from public.business_locations bl
    where bl.id = new.location_id
      and bl.business_id = new.business_id
      and bl.deleted_at is null
  ) then
    raise exception 'Pricing rule location must belong to the same business.';
  end if;

  if new.product_id is not null and not exists (
    select 1 from public.products p
    where p.id = new.product_id
      and p.business_id = new.business_id
      and p.deleted_at is null
  ) then
    raise exception 'Pricing rule product must belong to the same business.';
  end if;

  if new.category_id is not null and not exists (
    select 1 from public.product_categories pc
    where pc.id = new.category_id
      and pc.business_id = new.business_id
      and pc.deleted_at is null
  ) then
    raise exception 'Pricing rule category must belong to the same business.';
  end if;

  return new;
end;
$$;

drop trigger if exists pricing_rules_validate_relationships
  on public.pricing_rules;
create trigger pricing_rules_validate_relationships
before insert or update of business_id, location_id, product_id, category_id
on public.pricing_rules
for each row execute function public.validate_pricing_rule_relationships();

drop trigger if exists pricing_rules_prevent_business_change
  on public.pricing_rules;
create trigger pricing_rules_prevent_business_change
before update of business_id on public.pricing_rules
for each row execute function public.prevent_business_id_change();

drop trigger if exists pricing_rules_increment_version
  on public.pricing_rules;
create trigger pricing_rules_increment_version
before update on public.pricing_rules
for each row execute function public.increment_record_version();

drop trigger if exists pricing_rules_set_updated_at
  on public.pricing_rules;
create trigger pricing_rules_set_updated_at
before update on public.pricing_rules
for each row execute function public.set_updated_at();

-- Returns the effective product price and the winning/stacked rule IDs.
create or replace function public.resolve_product_price(
  p_product_id uuid,
  p_location_id uuid,
  p_membership_id uuid default null,
  p_at timestamptz default now(),
  p_event_code text default null,
  p_promotion_code text default null
)
returns table (
  base_price_cents bigint,
  effective_price_cents bigint,
  applied_rule_ids uuid[]
)
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_product public.products%rowtype;
  v_business public.businesses%rowtype;
  v_location public.business_locations%rowtype;
  v_timezone text;
  v_local_timestamp timestamp;
  v_local_time time;
  v_dow smallint;
  v_price bigint;
  v_rule public.pricing_rules%rowtype;
  v_applied uuid[] := array[]::uuid[];
  v_has_nonstackable boolean := false;
begin
  select * into v_product
  from public.products
  where id = p_product_id and deleted_at is null;

  if not found then
    raise exception 'Product not found.';
  end if;

  select * into v_business
  from public.businesses
  where id = v_product.business_id and deleted_at is null;

  select * into v_location
  from public.business_locations
  where id = p_location_id
    and business_id = v_product.business_id
    and deleted_at is null;

  if not found then
    raise exception 'Location must belong to the product business.';
  end if;

  if p_membership_id is not null and not exists (
    select 1 from public.memberships m
    where m.id = p_membership_id
      and m.business_id = v_product.business_id
      and m.deleted_at is null
      and m.status = 'active'
  ) then
    raise exception 'Active membership must belong to the product business.';
  end if;

  v_timezone := coalesce(v_location.timezone, v_business.timezone, 'UTC');
  v_local_timestamp := p_at at time zone v_timezone;
  v_local_time := v_local_timestamp::time;
  v_dow := extract(dow from v_local_timestamp)::smallint;
  v_price := v_product.price_cents;

  for v_rule in
    select pr.*
    from public.pricing_rules pr
    where pr.business_id = v_product.business_id
      and pr.status = 'active'
      and pr.deleted_at is null
      and (pr.location_id is null or pr.location_id = p_location_id)
      and (
        pr.product_id = v_product.id
        or pr.category_id = v_product.category_id
      )
      and (not pr.membership_required or p_membership_id is not null)
      and (pr.event_code is null or pr.event_code = p_event_code)
      and (pr.promotion_code is null or pr.promotion_code = p_promotion_code)
      and v_dow = any(pr.valid_days)
      and (pr.starts_at is null or p_at >= pr.starts_at)
      and (pr.ends_at is null or p_at <= pr.ends_at)
      and (
        pr.valid_start_time is null
        or pr.valid_end_time is null
        or (
          pr.valid_start_time <= pr.valid_end_time
          and v_local_time >= pr.valid_start_time
          and v_local_time < pr.valid_end_time
        )
        or (
          pr.valid_start_time > pr.valid_end_time
          and (v_local_time >= pr.valid_start_time or v_local_time < pr.valid_end_time)
        )
      )
    order by pr.priority desc, pr.created_at asc
  loop
    if v_has_nonstackable then
      exit;
    end if;

    if v_rule.adjustment_type = 'fixed_price' then
      v_price := v_rule.amount_cents;
    elsif v_rule.adjustment_type = 'amount_adjustment' then
      v_price := greatest(0, v_price + v_rule.amount_cents);
    else
      v_price := greatest(
        0,
        round(v_price * (10000 + v_rule.percentage_basis_points) / 10000.0)::bigint
      );
    end if;

    v_applied := array_append(v_applied, v_rule.id);
    v_has_nonstackable := not v_rule.is_stackable;
  end loop;

  return query select v_product.price_cents, v_price, v_applied;
end;
$$;

comment on function public.resolve_product_price is
  'Resolves product price using location timezone, overnight windows, membership, event, and promotion eligibility.';
