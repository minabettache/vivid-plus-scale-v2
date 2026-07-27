-- =========================================================
-- VIVID+ CORE TENANT FOUNDATION
-- Businesses, locations, customers, employees, memberships
-- =========================================================

create extension if not exists pgcrypto;

-- =========================================================
-- ENUMS
-- =========================================================

do $$
begin
  create type public.business_status as enum (
    'trial',
    'active',
    'past_due',
    'suspended',
    'cancelled',
    'archived'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.business_onboarding_status as enum (
    'not_started',
    'in_progress',
    'completed',
    'blocked'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.location_status as enum (
    'active',
    'temporarily_closed',
    'inactive',
    'archived'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.customer_status as enum (
    'active',
    'restricted',
    'suspended',
    'deletion_requested',
    'deleted'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.employee_role as enum (
    'staff',
    'supervisor',
    'manager',
    'owner'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.employee_status as enum (
    'invited',
    'active',
    'suspended',
    'terminated',
    'archived'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.membership_status as enum (
    'pending',
    'active',
    'paused',
    'banned',
    'closed',
    'archived'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.membership_source as enum (
    'customer_app',
    'employee_registration',
    'owner_import',
    'website',
    'qr_signup',
    'referral',
    'api',
    'pos_integration'
  );
exception
  when duplicate_object then null;
end $$;

-- =========================================================
-- UPDATED-AT FUNCTION
-- =========================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- =========================================================
-- BUSINESSES
-- =========================================================

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),

  legal_name text not null,
  display_name text not null,
  slug text not null,

  business_type text,
  description text,

  phone text,
  email text,
  website_url text,
  logo_url text,

  timezone text not null default 'America/New_York',
  currency_code char(3) not null default 'USD',
  country_code char(2) not null default 'US',

  status public.business_status not null default 'trial',

  onboarding_status public.business_onboarding_status
    not null
    default 'not_started',

  default_location_id uuid,

  created_by uuid references auth.users(id) on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,

  constraint businesses_slug_format_check
    check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),

  constraint businesses_currency_code_check
    check (currency_code = upper(currency_code)),

  constraint businesses_country_code_check
    check (country_code = upper(country_code))
);

create unique index if not exists businesses_slug_unique
  on public.businesses (lower(slug))
  where deleted_at is null;

create index if not exists businesses_status_idx
  on public.businesses (status)
  where deleted_at is null;

-- =========================================================
-- BUSINESS LOCATIONS
-- =========================================================

create table if not exists public.business_locations (
  id uuid primary key default gen_random_uuid(),

  business_id uuid not null
    references public.businesses(id)
    on delete restrict,

  name text not null,
  code text not null,

  phone text,
  email text,

  address_line_1 text,
  address_line_2 text,
  city text,
  state_region text,
  postal_code text,
  country_code char(2) not null default 'US',

  latitude numeric(9,6),
  longitude numeric(9,6),

  timezone text,

  status public.location_status not null default 'active',

  is_primary boolean not null default false,
  allows_customer_check_in boolean not null default true,

  geofence_radius_meters integer not null default 1609,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,

  constraint business_locations_code_not_blank
    check (length(trim(code)) > 0),

  constraint business_locations_country_code_check
    check (country_code = upper(country_code)),

  constraint business_locations_latitude_check
    check (
      latitude is null
      or latitude between -90 and 90
    ),

  constraint business_locations_longitude_check
    check (
      longitude is null
      or longitude between -180 and 180
    ),

  constraint business_locations_geofence_radius_check
    check (
      geofence_radius_meters between 50 and 80467
    )
);

create unique index if not exists business_locations_business_code_unique
  on public.business_locations (business_id, lower(code))
  where deleted_at is null;

create unique index if not exists business_locations_one_primary_unique
  on public.business_locations (business_id)
  where is_primary = true
    and deleted_at is null;

create index if not exists business_locations_business_id_idx
  on public.business_locations (business_id)
  where deleted_at is null;

create index if not exists business_locations_status_idx
  on public.business_locations (business_id, status)
  where deleted_at is null;

alter table public.businesses
  drop constraint if exists businesses_default_location_id_fkey;

alter table public.businesses
  add constraint businesses_default_location_id_fkey
  foreign key (default_location_id)
  references public.business_locations(id)
  on delete set null;

-- =========================================================
-- CUSTOMERS
-- =========================================================

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),

  auth_user_id uuid unique
    references auth.users(id)
    on delete set null,

  first_name text,
  last_name text,
  display_name text,

  email text,
  phone text,

  date_of_birth date,
  avatar_url text,

  preferred_language text not null default 'en',
  timezone text,
  country_code char(2) not null default 'US',

  email_verified_at timestamptz,
  phone_verified_at timestamptz,

  status public.customer_status not null default 'active',

  last_active_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,

  constraint customers_country_code_check
    check (country_code = upper(country_code)),

  constraint customers_date_of_birth_check
    check (
      date_of_birth is null
      or date_of_birth <= current_date
    )
);

create index if not exists customers_auth_user_id_idx
  on public.customers (auth_user_id)
  where deleted_at is null;

create index if not exists customers_email_normalized_idx
  on public.customers (lower(email))
  where email is not null
    and deleted_at is null;

create index if not exists customers_phone_idx
  on public.customers (phone)
  where phone is not null
    and deleted_at is null;

create index if not exists customers_status_idx
  on public.customers (status)
  where deleted_at is null;

-- =========================================================
-- EMPLOYEES
-- =========================================================

create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),

  business_id uuid not null
    references public.businesses(id)
    on delete restrict,

  auth_user_id uuid
    references auth.users(id)
    on delete set null,

  home_location_id uuid
    references public.business_locations(id)
    on delete set null,

  employee_number text not null,

  first_name text,
  last_name text,
  display_name text,

  email text,
  phone text,

  role public.employee_role not null default 'staff',
  status public.employee_status not null default 'invited',

  hired_at timestamptz,
  terminated_at timestamptz,

  can_access_all_locations boolean not null default false,

  created_by uuid
    references auth.users(id)
    on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,

  constraint employees_employee_number_not_blank
    check (length(trim(employee_number)) > 0),

  constraint employees_termination_dates_check
    check (
      terminated_at is null
      or hired_at is null
      or terminated_at >= hired_at
    )
);

create unique index if not exists employees_business_number_unique
  on public.employees (business_id, lower(employee_number))
  where deleted_at is null;

create unique index if not exists employees_business_auth_user_unique
  on public.employees (business_id, auth_user_id)
  where auth_user_id is not null
    and deleted_at is null;

create index if not exists employees_business_id_idx
  on public.employees (business_id)
  where deleted_at is null;

create index if not exists employees_auth_user_id_idx
  on public.employees (auth_user_id)
  where auth_user_id is not null
    and deleted_at is null;

create index if not exists employees_location_idx
  on public.employees (home_location_id)
  where deleted_at is null;

create index if not exists employees_business_status_idx
  on public.employees (business_id, status)
  where deleted_at is null;

-- =========================================================
-- MEMBERSHIPS
-- =========================================================

create table if not exists public.memberships (
  id uuid primary key default gen_random_uuid(),

  business_id uuid not null
    references public.businesses(id)
    on delete restrict,

  customer_id uuid not null
    references public.customers(id)
    on delete restrict,

  joined_location_id uuid
    references public.business_locations(id)
    on delete set null,

  referred_by_membership_id uuid
    references public.memberships(id)
    on delete set null,

  membership_number text not null,

  qr_token_hash text,

  status public.membership_status not null default 'pending',

  tier_id uuid,

  current_points_balance bigint not null default 0,
  lifetime_points_earned bigint not null default 0,
  lifetime_points_redeemed bigint not null default 0,

  lifetime_spend_cents bigint not null default 0,
  lifetime_visits integer not null default 0,

  first_visit_at timestamptz,
  last_visit_at timestamptz,

  joined_at timestamptz not null default now(),
  last_activity_at timestamptz,

  source public.membership_source not null default 'customer_app',

  created_by_employee_id uuid
    references public.employees(id)
    on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,

  constraint memberships_number_not_blank
    check (length(trim(membership_number)) > 0),

  constraint memberships_points_balance_nonnegative
    check (current_points_balance >= 0),

  constraint memberships_lifetime_points_earned_nonnegative
    check (lifetime_points_earned >= 0),

  constraint memberships_lifetime_points_redeemed_nonnegative
    check (lifetime_points_redeemed >= 0),

  constraint memberships_lifetime_spend_nonnegative
    check (lifetime_spend_cents >= 0),

  constraint memberships_lifetime_visits_nonnegative
    check (lifetime_visits >= 0),

  constraint memberships_points_consistency_check
    check (
      lifetime_points_redeemed <= lifetime_points_earned
    ),

  constraint memberships_visit_dates_check
    check (
      first_visit_at is null
      or last_visit_at is null
      or last_visit_at >= first_visit_at
    )
);

create unique index if not exists memberships_business_customer_unique
  on public.memberships (business_id, customer_id)
  where deleted_at is null;

create unique index if not exists memberships_business_number_unique
  on public.memberships (business_id, lower(membership_number))
  where deleted_at is null;

create unique index if not exists memberships_qr_token_hash_unique
  on public.memberships (qr_token_hash)
  where qr_token_hash is not null
    and deleted_at is null;

create index if not exists memberships_business_id_idx
  on public.memberships (business_id)
  where deleted_at is null;

create index if not exists memberships_customer_id_idx
  on public.memberships (customer_id)
  where deleted_at is null;

create index if not exists memberships_business_status_idx
  on public.memberships (business_id, status)
  where deleted_at is null;

create index if not exists memberships_business_last_visit_idx
  on public.memberships (business_id, last_visit_at desc)
  where deleted_at is null;

create index if not exists memberships_created_by_employee_idx
  on public.memberships (created_by_employee_id)
  where created_by_employee_id is not null;

-- =========================================================
-- UPDATED-AT TRIGGERS
-- =========================================================

drop trigger if exists businesses_set_updated_at
  on public.businesses;

create trigger businesses_set_updated_at
before update on public.businesses
for each row
execute function public.set_updated_at();

drop trigger if exists business_locations_set_updated_at
  on public.business_locations;

create trigger business_locations_set_updated_at
before update on public.business_locations
for each row
execute function public.set_updated_at();

drop trigger if exists customers_set_updated_at
  on public.customers;

create trigger customers_set_updated_at
before update on public.customers
for each row
execute function public.set_updated_at();

drop trigger if exists employees_set_updated_at
  on public.employees;

create trigger employees_set_updated_at
before update on public.employees
for each row
execute function public.set_updated_at();

drop trigger if exists memberships_set_updated_at
  on public.memberships;

create trigger memberships_set_updated_at
before update on public.memberships
for each row
execute function public.set_updated_at();

-- =========================================================
-- ROW LEVEL SECURITY FOUNDATION
-- No public policies are added yet.
-- Enabling RLS with no policies means access is denied by default.
-- =========================================================

alter table public.businesses enable row level security;
alter table public.business_locations enable row level security;
alter table public.customers enable row level security;
alter table public.employees enable row level security;
alter table public.memberships enable row level security;

alter table public.businesses force row level security;
alter table public.business_locations force row level security;
alter table public.customers force row level security;
alter table public.employees force row level security;
alter table public.memberships force row level security;

comment on table public.businesses is
  'Primary tenant record for each business using VIVID+.';

comment on table public.business_locations is
  'Physical or operational locations belonging to a VIVID+ business.';

comment on table public.customers is
  'Platform-wide customer identity. Business relationships are stored in memberships.';

comment on table public.employees is
  'Business-specific employee relationship and access identity.';

comment on table public.memberships is
  'Relationship between a customer and a business, including cached loyalty and value metrics.';

comment on column public.memberships.current_points_balance is
  'Cached balance only. The future loyalty ledger will remain the source of truth.';

comment on column public.memberships.lifetime_spend_cents is
  'Cached value calculated from verified transaction history.';
