-- =========================================================
-- VIVID+ TENANT INTEGRITY HARDENING
-- Prevents cross-business relationships
-- =========================================================

-- =========================================================
-- BUSINESS DEFAULT LOCATION VALIDATION
-- =========================================================

create or replace function public.validate_business_default_location()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.default_location_id is null then
    return new;
  end if;

  if not exists (
    select 1
    from public.business_locations bl
    where bl.id = new.default_location_id
      and bl.business_id = new.id
      and bl.deleted_at is null
  ) then
    raise exception
      'Default location must belong to the same business and must not be deleted.';
  end if;

  return new;
end;
$$;

drop trigger if exists businesses_validate_default_location
  on public.businesses;

create trigger businesses_validate_default_location
before insert or update of default_location_id
on public.businesses
for each row
execute function public.validate_business_default_location();

-- =========================================================
-- EMPLOYEE LOCATION VALIDATION
-- =========================================================

create or replace function public.validate_employee_business_relationships()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.home_location_id is not null then
    if not exists (
      select 1
      from public.business_locations bl
      where bl.id = new.home_location_id
        and bl.business_id = new.business_id
        and bl.deleted_at is null
    ) then
      raise exception
        'Employee home location must belong to the same business.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists employees_validate_business_relationships
  on public.employees;

create trigger employees_validate_business_relationships
before insert or update of business_id, home_location_id
on public.employees
for each row
execute function public.validate_employee_business_relationships();

-- =========================================================
-- MEMBERSHIP BUSINESS RELATIONSHIP VALIDATION
-- =========================================================

create or replace function public.validate_membership_business_relationships()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.joined_location_id is not null then
    if not exists (
      select 1
      from public.business_locations bl
      where bl.id = new.joined_location_id
        and bl.business_id = new.business_id
        and bl.deleted_at is null
    ) then
      raise exception
        'Membership joined location must belong to the same business.';
    end if;
  end if;

  if new.created_by_employee_id is not null then
    if not exists (
      select 1
      from public.employees e
      where e.id = new.created_by_employee_id
        and e.business_id = new.business_id
        and e.deleted_at is null
    ) then
      raise exception
        'Membership creator must be an employee of the same business.';
    end if;
  end if;

  if new.referred_by_membership_id is not null then
    if new.referred_by_membership_id = new.id then
      raise exception
        'A membership cannot refer itself.';
    end if;

    if not exists (
      select 1
      from public.memberships m
      where m.id = new.referred_by_membership_id
        and m.business_id = new.business_id
        and m.deleted_at is null
    ) then
      raise exception
        'Referring membership must belong to the same business.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists memberships_validate_business_relationships
  on public.memberships;

create trigger memberships_validate_business_relationships
before insert or update of
  business_id,
  joined_location_id,
  created_by_employee_id,
  referred_by_membership_id
on public.memberships
for each row
execute function public.validate_membership_business_relationships();

-- =========================================================
-- PRIMARY LOCATION SYNCHRONIZATION
-- =========================================================

create or replace function public.sync_business_primary_location()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.is_primary = true
     and new.deleted_at is null then

    update public.business_locations
    set
      is_primary = false,
      updated_at = now()
    where business_id = new.business_id
      and id <> new.id
      and is_primary = true
      and deleted_at is null;

    update public.businesses
    set
      default_location_id = new.id,
      updated_at = now()
    where id = new.business_id
      and deleted_at is null;
  end if;

  return new;
end;
$$;

drop trigger if exists business_locations_sync_primary
  on public.business_locations;

create trigger business_locations_sync_primary
after insert or update of is_primary, deleted_at
on public.business_locations
for each row
execute function public.sync_business_primary_location();

-- =========================================================
-- PREVENT BUSINESS CHANGES AFTER CREATION
-- Tenant-owned records should not silently move between businesses.
-- =========================================================

create or replace function public.prevent_business_id_change()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if old.business_id is distinct from new.business_id then
    raise exception
      'Changing business_id is not permitted. Create a new record instead.';
  end if;

  return new;
end;
$$;

drop trigger if exists business_locations_prevent_business_change
  on public.business_locations;

create trigger business_locations_prevent_business_change
before update of business_id
on public.business_locations
for each row
execute function public.prevent_business_id_change();

drop trigger if exists employees_prevent_business_change
  on public.employees;

create trigger employees_prevent_business_change
before update of business_id
on public.employees
for each row
execute function public.prevent_business_id_change();

drop trigger if exists memberships_prevent_business_change
  on public.memberships;

create trigger memberships_prevent_business_change
before update of business_id
on public.memberships
for each row
execute function public.prevent_business_id_change();

-- =========================================================
-- SECURITY COMMENTS
-- =========================================================

comment on function public.validate_business_default_location() is
  'Prevents a business from selecting a default location owned by another tenant.';

comment on function public.validate_employee_business_relationships() is
  'Prevents employees from being assigned to locations outside their business.';

comment on function public.validate_membership_business_relationships() is
  'Prevents cross-tenant membership, employee, location, and referral relationships.';

comment on function public.prevent_business_id_change() is
  'Prevents tenant-owned records from being silently transferred between businesses.';
