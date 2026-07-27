-- =========================================================
-- VIVID+ RBAC VALIDATION TRIGGER FIX
-- Replaces unsafe shared trigger function with table-specific validators
-- =========================================================

create or replace function public.validate_role_permission_relationships()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.business_roles r
    where r.id = new.role_id
      and r.business_id = new.business_id
      and r.deleted_at is null
  ) then
    raise exception 'Role must belong to the same business.';
  end if;

  if not exists (
    select 1
    from public.permissions p
    where p.id = new.permission_id
  ) then
    raise exception 'Permission does not exist.';
  end if;

  return new;
end;
$$;


create or replace function public.validate_employee_location_relationships()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.employees e
    where e.id = new.employee_id
      and e.business_id = new.business_id
      and e.deleted_at is null
  ) then
    raise exception 'Employee must belong to the same business.';
  end if;

  if not exists (
    select 1
    from public.business_locations l
    where l.id = new.location_id
      and l.business_id = new.business_id
      and l.deleted_at is null
  ) then
    raise exception 'Location must belong to the same business.';
  end if;

  return new;
end;
$$;


create or replace function public.validate_employee_role_assignment_relationships()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.employees e
    where e.id = new.employee_id
      and e.business_id = new.business_id
      and e.deleted_at is null
  ) then
    raise exception 'Employee must belong to the same business.';
  end if;

  if not exists (
    select 1
    from public.business_roles r
    where r.id = new.role_id
      and r.business_id = new.business_id
      and r.deleted_at is null
  ) then
    raise exception 'Role must belong to the same business.';
  end if;

  if new.location_id is not null
     and not exists (
       select 1
       from public.business_locations l
       where l.id = new.location_id
         and l.business_id = new.business_id
         and l.deleted_at is null
     ) then
    raise exception 'Role assignment location must belong to the same business.';
  end if;

  return new;
end;
$$;


create or replace function public.validate_security_audit_event_relationships()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.business_id is not null
     and not exists (
       select 1
       from public.businesses b
       where b.id = new.business_id
         and b.deleted_at is null
     ) then
    raise exception 'Audit business does not exist.';
  end if;

  if new.business_id is not null
     and new.location_id is not null
     and not exists (
       select 1
       from public.business_locations l
       where l.id = new.location_id
         and l.business_id = new.business_id
         and l.deleted_at is null
     ) then
    raise exception 'Audit location must belong to the same business.';
  end if;

  return new;
end;
$$;


drop trigger if exists role_permissions_validate_tenant
on public.role_permissions;

create trigger role_permissions_validate_tenant
before insert or update on public.role_permissions
for each row
execute function public.validate_role_permission_relationships();


drop trigger if exists employee_locations_validate_tenant
on public.employee_locations;

create trigger employee_locations_validate_tenant
before insert or update on public.employee_locations
for each row
execute function public.validate_employee_location_relationships();


drop trigger if exists employee_role_assignments_validate_tenant
on public.employee_role_assignments;

create trigger employee_role_assignments_validate_tenant
before insert or update on public.employee_role_assignments
for each row
execute function public.validate_employee_role_assignment_relationships();


drop trigger if exists security_audit_events_validate_tenant
on public.security_audit_events;

create trigger security_audit_events_validate_tenant
before insert on public.security_audit_events
for each row
execute function public.validate_security_audit_event_relationships();
