-- =========================================================
-- VIVID+ PRODUCT CATALOG FOUNDATION
-- Migration 003
--
-- Creates:
--   1. product_categories
--   2. products
--
-- Supports:
--   - Retail products
--   - Hookah products and flavors
--   - Food and beverages
--   - Services
--   - Event tickets
--   - Membership products
--   - Gift cards
-- =========================================================

-- =========================================================
-- ENUMS
-- =========================================================

do $$
begin
  create type public.product_status as enum (
    'draft',
    'active',
    'inactive',
    'discontinued',
    'archived'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.product_type as enum (
    'physical',
    'food',
    'beverage',
    'hookah',
    'service',
    'event_ticket',
    'membership',
    'gift_card',
    'digital',
    'other'
  );
exception
  when duplicate_object then null;
end $$;

-- =========================================================
-- PRODUCT CATEGORIES
-- =========================================================

create table if not exists public.product_categories (
  id uuid primary key default gen_random_uuid(),

  business_id uuid not null
    references public.businesses(id)
    on delete restrict,

  parent_category_id uuid
    references public.product_categories(id)
    on delete restrict,

  name text not null,
  slug text not null,
  description text,

  image_url text,

  display_order integer not null default 0,

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

  constraint product_categories_name_not_blank
    check (length(trim(name)) > 0),

  constraint product_categories_slug_not_blank
    check (length(trim(slug)) > 0),

  constraint product_categories_slug_format_check
    check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),

  constraint product_categories_display_order_check
    check (display_order >= 0),

  constraint product_categories_version_check
    check (version >= 1),

  constraint product_categories_metadata_object_check
    check (jsonb_typeof(metadata) = 'object'),

  constraint product_categories_not_own_parent_check
    check (
      parent_category_id is null
      or parent_category_id <> id
    )
);

create unique index if not exists
  product_categories_business_slug_unique
on public.product_categories (
  business_id,
  lower(slug)
)
where deleted_at is null;

create unique index if not exists
  product_categories_business_parent_name_unique
on public.product_categories (
  business_id,
  coalesce(parent_category_id, '00000000-0000-0000-0000-000000000000'::uuid),
  lower(name)
)
where deleted_at is null;

create index if not exists
  product_categories_business_id_idx
on public.product_categories (business_id)
where deleted_at is null;

create index if not exists
  product_categories_parent_category_id_idx
on public.product_categories (parent_category_id)
where parent_category_id is not null
  and deleted_at is null;

create index if not exists
  product_categories_business_active_order_idx
on public.product_categories (
  business_id,
  is_active,
  display_order,
  name
)
where deleted_at is null;

-- =========================================================
-- PRODUCTS
-- =========================================================

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),

  business_id uuid not null
    references public.businesses(id)
    on delete restrict,

  category_id uuid
    references public.product_categories(id)
    on delete set null,

  name text not null,
  slug text not null,

  description text,
  short_description text,

  product_type public.product_type not null default 'physical',
  status public.product_status not null default 'draft',

  sku text,
  barcode text,

  price_cents bigint not null default 0,
  cost_cents bigint,

  currency_code char(3) not null default 'USD',

  tax_rate_basis_points integer not null default 0,

  track_inventory boolean not null default false,
  allow_negative_inventory boolean not null default false,

  is_reward_eligible boolean not null default true,
  is_points_earning_eligible boolean not null default true,

  image_url text,

  display_order integer not null default 0,

  available_from timestamptz,
  available_until timestamptz,

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

  constraint products_name_not_blank
    check (length(trim(name)) > 0),

  constraint products_slug_not_blank
    check (length(trim(slug)) > 0),

  constraint products_slug_format_check
    check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),

  constraint products_price_nonnegative
    check (price_cents >= 0),

  constraint products_cost_nonnegative
    check (
      cost_cents is null
      or cost_cents >= 0
    ),

  constraint products_currency_code_check
    check (currency_code = upper(currency_code)),

  constraint products_tax_rate_check
    check (
      tax_rate_basis_points between 0 and 10000
    ),

  constraint products_display_order_check
    check (display_order >= 0),

  constraint products_version_check
    check (version >= 1),

  constraint products_metadata_object_check
    check (jsonb_typeof(metadata) = 'object'),

  constraint products_availability_dates_check
    check (
      available_from is null
      or available_until is null
      or available_until >= available_from
    )
);

create unique index if not exists
  products_business_slug_unique
on public.products (
  business_id,
  lower(slug)
)
where deleted_at is null;

create unique index if not exists
  products_business_sku_unique
on public.products (
  business_id,
  lower(sku)
)
where sku is not null
  and deleted_at is null;

create unique index if not exists
  products_business_barcode_unique
on public.products (
  business_id,
  barcode
)
where barcode is not null
  and deleted_at is null;

create index if not exists
  products_business_id_idx
on public.products (business_id)
where deleted_at is null;

create index if not exists
  products_category_id_idx
on public.products (category_id)
where category_id is not null
  and deleted_at is null;

create index if not exists
  products_business_status_idx
on public.products (
  business_id,
  status
)
where deleted_at is null;

create index if not exists
  products_business_type_idx
on public.products (
  business_id,
  product_type
)
where deleted_at is null;

create index if not exists
  products_business_catalog_idx
on public.products (
  business_id,
  status,
  display_order,
  name
)
where deleted_at is null;

-- =========================================================
-- CATEGORY TENANT VALIDATION
-- =========================================================

create or replace function
  public.validate_product_category_relationships()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  current_parent_id uuid;
  hierarchy_depth integer := 0;
begin
  if new.parent_category_id is null then
    return new;
  end if;

  if new.parent_category_id = new.id then
    raise exception
      'A product category cannot be its own parent.';
  end if;

  if not exists (
    select 1
    from public.product_categories pc
    where pc.id = new.parent_category_id
      and pc.business_id = new.business_id
      and pc.deleted_at is null
  ) then
    raise exception
      'Parent category must belong to the same business and must not be deleted.';
  end if;

  current_parent_id := new.parent_category_id;

  while current_parent_id is not null loop
    hierarchy_depth := hierarchy_depth + 1;

    if hierarchy_depth > 20 then
      raise exception
        'Product category hierarchy cannot exceed 20 levels.';
    end if;

    if current_parent_id = new.id then
      raise exception
        'Circular product category hierarchy detected.';
    end if;

    select pc.parent_category_id
    into current_parent_id
    from public.product_categories pc
    where pc.id = current_parent_id
      and pc.deleted_at is null;

    if not found then
      current_parent_id := null;
    end if;
  end loop;

  return new;
end;
$$;

drop trigger if exists
  product_categories_validate_relationships
on public.product_categories;

create trigger product_categories_validate_relationships
before insert or update of
  business_id,
  parent_category_id
on public.product_categories
for each row
execute function
  public.validate_product_category_relationships();

-- =========================================================
-- PRODUCT TENANT VALIDATION
-- =========================================================

create or replace function
  public.validate_product_business_relationships()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.category_id is not null then
    if not exists (
      select 1
      from public.product_categories pc
      where pc.id = new.category_id
        and pc.business_id = new.business_id
        and pc.deleted_at is null
    ) then
      raise exception
        'Product category must belong to the same business and must not be deleted.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists
  products_validate_business_relationships
on public.products;

create trigger products_validate_business_relationships
before insert or update of
  business_id,
  category_id
on public.products
for each row
execute function
  public.validate_product_business_relationships();

-- =========================================================
-- PREVENT TENANT TRANSFERS
-- =========================================================

drop trigger if exists
  product_categories_prevent_business_change
on public.product_categories;

create trigger product_categories_prevent_business_change
before update of business_id
on public.product_categories
for each row
execute function public.prevent_business_id_change();

drop trigger if exists
  products_prevent_business_change
on public.products;

create trigger products_prevent_business_change
before update of business_id
on public.products
for each row
execute function public.prevent_business_id_change();

-- =========================================================
-- VERSION MANAGEMENT
-- =========================================================

create or replace function public.increment_record_version()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.version = old.version + 1;
  return new;
end;
$$;

drop trigger if exists
  product_categories_increment_version
on public.product_categories;

create trigger product_categories_increment_version
before update on public.product_categories
for each row
execute function public.increment_record_version();

drop trigger if exists
  products_increment_version
on public.products;

create trigger products_increment_version
before update on public.products
for each row
execute function public.increment_record_version();

-- =========================================================
-- UPDATED-AT TRIGGERS
-- =========================================================

drop trigger if exists
  product_categories_set_updated_at
on public.product_categories;

create trigger product_categories_set_updated_at
before update on public.product_categories
for each row
execute function public.set_updated_at();

drop trigger if exists
  products_set_updated_at
on public.products;

create trigger products_set_updated_at
before update on public.products
for each row
execute function public.set_updated_at();

-- =========================================================
-- ROW LEVEL SECURITY
-- No public policies are added yet.
-- Access remains denied by default.
-- =========================================================

alter table public.product_categories
  enable row level security;

alter table public.product_categories
  force row level security;

alter table public.products
  enable row level security;

alter table public.products
  force row level security;

-- =========================================================
-- COMMENTS
-- =========================================================

comment on table public.product_categories is
  'Business-owned hierarchical categories used to organize the VIVID+ product catalog.';

comment on table public.products is
  'Business-owned products and services used in transactions, rewards, reporting, and AI analysis.';

comment on column public.products.price_cents is
  'Default selling price stored in the smallest currency unit. Historical transaction items preserve the actual sale price.';

comment on column public.products.cost_cents is
  'Estimated unit cost used for gross-profit calculations. Historical transaction items preserve the actual recorded cost.';

comment on column public.products.tax_rate_basis_points is
  'Tax rate expressed in basis points. Example: 650 represents 6.50 percent.';

comment on column public.products.metadata is
  'Optional structured product attributes. Core reporting fields should use dedicated columns.';

comment on function
  public.validate_product_category_relationships() is
  'Prevents cross-tenant, self-referencing, excessively deep, and circular category hierarchies.';

comment on function
  public.validate_product_business_relationships() is
  'Prevents products from being assigned to categories belonging to another business.';

comment on function public.increment_record_version() is
  'Automatically increments record versions for optimistic concurrency and auditing.';
