-- =========================================================
-- VIVID+ MIGRATION 008
-- ENTERPRISE SECURITY, RBAC, LOCATION ACCESS, AND AUDIT CORE
-- =========================================================
-- Security model:
--   auth.users -> employees -> role assignments -> permissions
--   employee location access is deny-by-default unless the employee
--   has business-wide access or an explicit active location assignment.
-- =========================================================

-- =========================================================
-- ENUMS
-- =========================================================

do $$
begin
  create type public.access_assignment_status as enum (
    'active',
    'suspended',
    'revoked'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.audit_event_severity as enum (
    'info',
    'warning',
    'critical'
  );
exception
  when duplicate_object then null;
end $$;

-- =========================================================
-- PERMISSIONS
-- Global, immutable permission catalog.
-- =========================================================

create table if not exists public.permissions (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  module text not null,
  description text not null,
  is_sensitive boolean not null default false,
  created_at timestamptz not null default now(),

  constraint permissions_code_format_check
    check (code ~ '^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$'),

  constraint permissions_module_format_check
    check (module ~ '^[a-z][a-z0-9_]*$')
);

create unique index if not exists permissions_code_unique
  on public.permissions (lower(code));

create index if not exists permissions_module_idx
  on public.permissions (module, code);

-- =========================================================
-- BUSINESS ROLES
-- Roles are tenant-owned and may be customized later.
-- System roles are protected from deletion and code changes.
-- =========================================================

create table if not exists public.business_roles (
  id uuid primary key default gen_random_uuid(),

  business_id uuid not null
    references public.businesses(id)
    on delete restrict,

  code text not null,
  name text not null,
  description text,

  is_system boolean not null default false,
  is_owner_role boolean not null default false,
  priority integer not null default 100,

  created_by uuid
    references auth.users(id)
    on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  version bigint not null default 1,

  constraint business_roles_code_format_check
    check (code ~ '^[a-z][a-z0-9_]*$'),

  constraint business_roles_name_not_blank
    check (length(trim(name)) > 0),

  constraint business_roles_priority_check
    check (priority between 0 and 10000)
);

create unique index if not exists business_roles_business_code_unique
  on public.business_roles (business_id, lower(code))
  where deleted_at is null;

create unique index if not exists business_roles_one_owner_role_unique
  on public.business_roles (business_id)
  where is_owner_role = true
    and deleted_at is null;

create index if not exists business_roles_business_idx
  on public.business_roles (business_id, priority, name)
  where deleted_at is null;

-- =========================================================
-- ROLE PERMISSIONS
-- =========================================================

create table if not exists public.role_permissions (
  id uuid primary key default gen_random_uuid(),

  business_id uuid not null
    references public.businesses(id)
    on delete restrict,

  role_id uuid not null
    references public.business_roles(id)
    on delete restrict,

  permission_id uuid not null
    references public.permissions(id)
    on delete restrict,

  granted_by uuid
    references auth.users(id)
    on delete set null,

  created_at timestamptz not null default now()
);

create unique index if not exists role_permissions_role_permission_unique
  on public.role_permissions (role_id, permission_id);

create index if not exists role_permissions_business_idx
  on public.role_permissions (business_id, role_id);

create index if not exists role_permissions_permission_idx
  on public.role_permissions (permission_id, role_id);

-- =========================================================
-- EMPLOYEE LOCATION ACCESS
-- Explicit location grants for employees without all-location access.
-- =========================================================

create table if not exists public.employee_locations (
  id uuid primary key default gen_random_uuid(),

  business_id uuid not null
    references public.businesses(id)
    on delete restrict,

  employee_id uuid not null
    references public.employees(id)
    on delete restrict,

  location_id uuid not null
    references public.business_locations(id)
    on delete restrict,

  status public.access_assignment_status not null default 'active',

  granted_by uuid
    references auth.users(id)
    on delete set null,

  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  version bigint not null default 1,

  constraint employee_locations_revocation_check
    check (
      (status = 'revoked' and revoked_at is not null)
      or status <> 'revoked'
    )
);

create unique index if not exists employee_locations_active_unique
  on public.employee_locations (employee_id, location_id)
  where deleted_at is null
    and status <> 'revoked';

create index if not exists employee_locations_business_employee_idx
  on public.employee_locations (business_id, employee_id)
  where deleted_at is null;

create index if not exists employee_locations_location_idx
  on public.employee_locations (business_id, location_id)
  where deleted_at is null
    and status = 'active';

-- =========================================================
-- EMPLOYEE ROLE ASSIGNMENTS
-- location_id null = business-wide assignment.
-- =========================================================

create table if not exists public.employee_role_assignments (
  id uuid primary key default gen_random_uuid(),

  business_id uuid not null
    references public.businesses(id)
    on delete restrict,

  employee_id uuid not null
    references public.employees(id)
    on delete restrict,

  role_id uuid not null
    references public.business_roles(id)
    on delete restrict,

  location_id uuid
    references public.business_locations(id)
    on delete restrict,

  status public.access_assignment_status not null default 'active',

  valid_from timestamptz not null default now(),
  valid_until timestamptz,

  assigned_by uuid
    references auth.users(id)
    on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  version bigint not null default 1,

  constraint employee_role_assignments_validity_check
    check (valid_until is null or valid_until > valid_from)
);

create unique index if not exists employee_role_assignments_business_scope_unique
  on public.employee_role_assignments (employee_id, role_id)
  where location_id is null
    and deleted_at is null
    and status <> 'revoked';

create unique index if not exists employee_role_assignments_location_scope_unique
  on public.employee_role_assignments (employee_id, role_id, location_id)
  where location_id is not null
    and deleted_at is null
    and status <> 'revoked';

create index if not exists employee_role_assignments_lookup_idx
  on public.employee_role_assignments (
    business_id,
    employee_id,
    location_id,
    status,
    valid_from,
    valid_until
  )
  where deleted_at is null;

-- =========================================================
-- SECURITY AUDIT EVENTS
-- Append-only event store for sensitive actions.
-- =========================================================

create table if not exists public.security_audit_events (
  id uuid primary key default gen_random_uuid(),

  business_id uuid
    references public.businesses(id)
    on delete restrict,

  location_id uuid
    references public.business_locations(id)
    on delete restrict,

  actor_user_id uuid
    references auth.users(id)
    on delete set null,

  actor_employee_id uuid
    references public.employees(id)
    on delete set null,

  event_type text not null,
  action text not null,
  resource_type text,
  resource_id uuid,
  severity public.audit_event_severity not null default 'info',
  success boolean not null default true,

  ip_address inet,
  user_agent text,
  request_id text,

  before_data jsonb,
  after_data jsonb,
  metadata jsonb not null default '{}'::jsonb,

  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),

  constraint security_audit_event_type_not_blank
    check (length(trim(event_type)) > 0),

  constraint security_audit_action_not_blank
    check (length(trim(action)) > 0),

  constraint security_audit_metadata_object_check
    check (jsonb_typeof(metadata) = 'object')
);

create index if not exists security_audit_events_business_time_idx
  on public.security_audit_events (business_id, occurred_at desc);

create index if not exists security_audit_events_actor_time_idx
  on public.security_audit_events (actor_user_id, occurred_at desc);

create index if not exists security_audit_events_resource_idx
  on public.security_audit_events (business_id, resource_type, resource_id, occurred_at desc);

create index if not exists security_audit_events_critical_idx
  on public.security_audit_events (occurred_at desc)
  where severity = 'critical' or success = false;

-- =========================================================
-- TENANT INTEGRITY VALIDATION
-- =========================================================

create or replace function public.validate_business_role_relationships()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if tg_table_name = 'role_permissions' then
    if not exists (
      select 1
      from public.business_roles r
      where r.id = new.role_id
        and r.business_id = new.business_id
        and r.deleted_at is null
    ) then
      raise exception 'Role must belong to the same business.';
    end if;
  end if;

  if tg_table_name = 'employee_locations' then
    if not exists (
      select 1 from public.employees e
      where e.id = new.employee_id
        and e.business_id = new.business_id
        and e.deleted_at is null
    ) then
      raise exception 'Employee must belong to the same business.';
    end if;

    if not exists (
      select 1 from public.business_locations l
      where l.id = new.location_id
        and l.business_id = new.business_id
        and l.deleted_at is null
    ) then
      raise exception 'Location must belong to the same business.';
    end if;
  end if;

  if tg_table_name = 'employee_role_assignments' then
    if not exists (
      select 1 from public.employees e
      where e.id = new.employee_id
        and e.business_id = new.business_id
        and e.deleted_at is null
    ) then
      raise exception 'Employee must belong to the same business.';
    end if;

    if not exists (
      select 1 from public.business_roles r
      where r.id = new.role_id
        and r.business_id = new.business_id
        and r.deleted_at is null
    ) then
      raise exception 'Role must belong to the same business.';
    end if;

    if new.location_id is not null and not exists (
      select 1 from public.business_locations l
      where l.id = new.location_id
        and l.business_id = new.business_id
        and l.deleted_at is null
    ) then
      raise exception 'Role assignment location must belong to the same business.';
    end if;
  end if;

  if tg_table_name = 'security_audit_events'
     and new.business_id is not null
     and new.location_id is not null
     and not exists (
       select 1 from public.business_locations l
       where l.id = new.location_id
         and l.business_id = new.business_id
     ) then
    raise exception 'Audit location must belong to the same business.';
  end if;

  return new;
end;
$$;

create or replace function public.prevent_system_role_mutation()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if old.is_system then
    if new.business_id is distinct from old.business_id
       or new.code is distinct from old.code
       or new.is_system is distinct from old.is_system
       or new.is_owner_role is distinct from old.is_owner_role
       or new.deleted_at is distinct from old.deleted_at then
      raise exception 'Protected system role identity cannot be changed or deleted.';
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.block_audit_event_mutation()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  raise exception 'Security audit events are append-only.';
end;
$$;

-- Validation triggers

drop trigger if exists role_permissions_validate_tenant on public.role_permissions;
create trigger role_permissions_validate_tenant
before insert or update on public.role_permissions
for each row execute function public.validate_business_role_relationships();

drop trigger if exists employee_locations_validate_tenant on public.employee_locations;
create trigger employee_locations_validate_tenant
before insert or update on public.employee_locations
for each row execute function public.validate_business_role_relationships();

drop trigger if exists employee_role_assignments_validate_tenant on public.employee_role_assignments;
create trigger employee_role_assignments_validate_tenant
before insert or update on public.employee_role_assignments
for each row execute function public.validate_business_role_relationships();

drop trigger if exists security_audit_events_validate_tenant on public.security_audit_events;
create trigger security_audit_events_validate_tenant
before insert on public.security_audit_events
for each row execute function public.validate_business_role_relationships();

drop trigger if exists business_roles_protect_system_role on public.business_roles;
create trigger business_roles_protect_system_role
before update on public.business_roles
for each row execute function public.prevent_system_role_mutation();

drop trigger if exists security_audit_events_block_update on public.security_audit_events;
create trigger security_audit_events_block_update
before update on public.security_audit_events
for each row execute function public.block_audit_event_mutation();

drop trigger if exists security_audit_events_block_delete on public.security_audit_events;
create trigger security_audit_events_block_delete
before delete on public.security_audit_events
for each row execute function public.block_audit_event_mutation();

-- Prevent tenant transfer

drop trigger if exists business_roles_prevent_business_change on public.business_roles;
create trigger business_roles_prevent_business_change
before update of business_id on public.business_roles
for each row execute function public.prevent_business_id_change();

drop trigger if exists role_permissions_prevent_business_change on public.role_permissions;
create trigger role_permissions_prevent_business_change
before update of business_id on public.role_permissions
for each row execute function public.prevent_business_id_change();

drop trigger if exists employee_locations_prevent_business_change on public.employee_locations;
create trigger employee_locations_prevent_business_change
before update of business_id on public.employee_locations
for each row execute function public.prevent_business_id_change();

drop trigger if exists employee_role_assignments_prevent_business_change on public.employee_role_assignments;
create trigger employee_role_assignments_prevent_business_change
before update of business_id on public.employee_role_assignments
for each row execute function public.prevent_business_id_change();

-- Version and timestamp triggers

drop trigger if exists business_roles_set_updated_at on public.business_roles;
create trigger business_roles_set_updated_at
before update on public.business_roles
for each row execute function public.set_updated_at();

drop trigger if exists business_roles_increment_version on public.business_roles;
create trigger business_roles_increment_version
before update on public.business_roles
for each row execute function public.increment_record_version();

drop trigger if exists employee_locations_set_updated_at on public.employee_locations;
create trigger employee_locations_set_updated_at
before update on public.employee_locations
for each row execute function public.set_updated_at();

drop trigger if exists employee_locations_increment_version on public.employee_locations;
create trigger employee_locations_increment_version
before update on public.employee_locations
for each row execute function public.increment_record_version();

drop trigger if exists employee_role_assignments_set_updated_at on public.employee_role_assignments;
create trigger employee_role_assignments_set_updated_at
before update on public.employee_role_assignments
for each row execute function public.set_updated_at();

drop trigger if exists employee_role_assignments_increment_version on public.employee_role_assignments;
create trigger employee_role_assignments_increment_version
before update on public.employee_role_assignments
for each row execute function public.increment_record_version();

-- =========================================================
-- AUTHORIZATION HELPER FUNCTIONS
-- SECURITY DEFINER prevents recursive RLS evaluation.
-- Every helper fixes search_path and derives identity from auth.uid().
-- =========================================================

create or replace function public.current_employee_id(p_business_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public, auth
set row_security = off
as $$
  select e.id
  from public.employees e
  join public.businesses b on b.id = e.business_id
  where e.auth_user_id = auth.uid()
    and e.business_id = p_business_id
    and e.status = 'active'
    and e.deleted_at is null
    and b.deleted_at is null
    and b.status in ('trial', 'active', 'past_due')
  order by e.created_at
  limit 1
$$;

create or replace function public.is_business_member(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
set row_security = off
as $$
  select public.current_employee_id(p_business_id) is not null
$$;

create or replace function public.can_access_location(
  p_business_id uuid,
  p_location_id uuid
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
    from public.employees e
    join public.business_locations l
      on l.id = p_location_id
     and l.business_id = p_business_id
     and l.deleted_at is null
     and l.status <> 'archived'
    where e.auth_user_id = auth.uid()
      and e.business_id = p_business_id
      and e.status = 'active'
      and e.deleted_at is null
      and (
        e.can_access_all_locations = true
        or e.home_location_id = p_location_id
        or exists (
          select 1
          from public.employee_locations el
          where el.employee_id = e.id
            and el.business_id = p_business_id
            and el.location_id = p_location_id
            and el.status = 'active'
            and el.deleted_at is null
        )
      )
  )
$$;

create or replace function public.has_permission(
  p_business_id uuid,
  p_permission_code text,
  p_location_id uuid default null
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
    from public.employees e
    join public.employee_role_assignments era
      on era.employee_id = e.id
     and era.business_id = e.business_id
     and era.status = 'active'
     and era.deleted_at is null
     and era.valid_from <= now()
     and (era.valid_until is null or era.valid_until > now())
    join public.business_roles r
      on r.id = era.role_id
     and r.business_id = e.business_id
     and r.deleted_at is null
    join public.role_permissions rp
      on rp.role_id = r.id
     and rp.business_id = e.business_id
    join public.permissions p
      on p.id = rp.permission_id
     and lower(p.code) = lower(p_permission_code)
    where e.auth_user_id = auth.uid()
      and e.business_id = p_business_id
      and e.status = 'active'
      and e.deleted_at is null
      and (
        p_location_id is null
        or (
          public.can_access_location(p_business_id, p_location_id)
          and (era.location_id is null or era.location_id = p_location_id)
        )
      )
  )
$$;

create or replace function public.is_business_owner(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
set row_security = off
as $$
  select exists (
    select 1
    from public.employees e
    join public.employee_role_assignments era
      on era.employee_id = e.id
     and era.business_id = e.business_id
     and era.status = 'active'
     and era.deleted_at is null
     and era.valid_from <= now()
     and (era.valid_until is null or era.valid_until > now())
     and era.location_id is null
    join public.business_roles r
      on r.id = era.role_id
     and r.business_id = e.business_id
     and r.is_owner_role = true
     and r.deleted_at is null
    where e.auth_user_id = auth.uid()
      and e.business_id = p_business_id
      and e.status = 'active'
      and e.deleted_at is null
  )
$$;

revoke all on function public.current_employee_id(uuid) from public;
revoke all on function public.is_business_member(uuid) from public;
revoke all on function public.can_access_location(uuid, uuid) from public;
revoke all on function public.has_permission(uuid, text, uuid) from public;
revoke all on function public.is_business_owner(uuid) from public;

grant execute on function public.current_employee_id(uuid) to authenticated, service_role;
grant execute on function public.is_business_member(uuid) to authenticated, service_role;
grant execute on function public.can_access_location(uuid, uuid) to authenticated, service_role;
grant execute on function public.has_permission(uuid, text, uuid) to authenticated, service_role;
grant execute on function public.is_business_owner(uuid) to authenticated, service_role;

-- =========================================================
-- DEFAULT PERMISSION CATALOG
-- =========================================================

insert into public.permissions (code, module, description, is_sensitive)
values
  ('dashboard.read', 'dashboard', 'View business dashboard', false),
  ('business.read', 'business', 'View business settings', false),
  ('business.update', 'business', 'Update business settings', true),
  ('locations.read', 'locations', 'View allowed locations', false),
  ('locations.manage', 'locations', 'Create and manage locations', true),
  ('employees.read', 'employees', 'View employees', false),
  ('employees.invite', 'employees', 'Invite employees', true),
  ('employees.manage', 'employees', 'Manage employees, roles, and access', true),
  ('roles.read', 'roles', 'View roles and permissions', false),
  ('roles.manage', 'roles', 'Manage custom roles and permissions', true),
  ('products.read', 'products', 'View products and categories', false),
  ('products.create', 'products', 'Create products and categories', false),
  ('products.update', 'products', 'Update products, categories, and barcodes', false),
  ('products.delete', 'products', 'Archive products and categories', true),
  ('inventory.read', 'inventory', 'View inventory balances and movements', false),
  ('inventory.receive', 'inventory', 'Receive inventory', true),
  ('inventory.adjust', 'inventory', 'Post inventory adjustments', true),
  ('inventory.transfer', 'inventory', 'Transfer inventory between locations', true),
  ('customers.read', 'customers', 'View customers and memberships', false),
  ('customers.manage', 'customers', 'Create and update customers and memberships', false),
  ('loyalty.read', 'loyalty', 'View loyalty activity and rewards', false),
  ('loyalty.manage', 'loyalty', 'Manage loyalty rules and rewards', true),
  ('sales.read', 'sales', 'View transactions and visits', false),
  ('sales.create', 'sales', 'Create sales transactions', true),
  ('sales.refund', 'sales', 'Refund or reverse transactions', true),
  ('pricing.read', 'pricing', 'View pricing rules', false),
  ('pricing.manage', 'pricing', 'Manage pricing rules', true),
  ('reports.read', 'reports', 'View operational and financial reports', false),
  ('audit.read', 'audit', 'View security audit events', true),
  ('settings.manage', 'settings', 'Manage security-sensitive settings', true)
on conflict ((lower(code))) do update
set
  module = excluded.module,
  description = excluded.description,
  is_sensitive = excluded.is_sensitive;

-- =========================================================
-- DEFAULT ROLE PROVISIONING
-- =========================================================

create or replace function public.provision_default_business_roles(p_business_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_owner uuid;
  v_admin uuid;
  v_manager uuid;
  v_inventory uuid;
  v_cashier uuid;
  v_staff uuid;
  v_auditor uuid;
begin
  if not exists (
    select 1 from public.businesses b
    where b.id = p_business_id and b.deleted_at is null
  ) then
    raise exception 'Business does not exist.';
  end if;

  insert into public.business_roles
    (business_id, code, name, description, is_system, is_owner_role, priority)
  values
    (p_business_id, 'owner', 'Owner', 'Full business ownership and security authority', true, true, 0)
  on conflict (business_id, (lower(code))) where deleted_at is null
  do update set name = excluded.name
  returning id into v_owner;

  insert into public.business_roles
    (business_id, code, name, description, is_system, priority)
  values
    (p_business_id, 'administrator', 'Administrator', 'Full operational administration except ownership-only controls', true, 10),
    (p_business_id, 'manager', 'Manager', 'Manage daily business operations', true, 20),
    (p_business_id, 'inventory_manager', 'Inventory Manager', 'Manage products, inventory, receiving, and transfers', true, 30),
    (p_business_id, 'cashier', 'Cashier', 'Run sales and customer-facing operations', true, 40),
    (p_business_id, 'staff', 'Staff', 'Basic operational access', true, 50),
    (p_business_id, 'auditor', 'Read-only Auditor', 'Read-only reporting and audit access', true, 60)
  on conflict (business_id, (lower(code))) where deleted_at is null
  do update set name = excluded.name;

  select id into v_admin from public.business_roles where business_id = p_business_id and code = 'administrator' and deleted_at is null;
  select id into v_manager from public.business_roles where business_id = p_business_id and code = 'manager' and deleted_at is null;
  select id into v_inventory from public.business_roles where business_id = p_business_id and code = 'inventory_manager' and deleted_at is null;
  select id into v_cashier from public.business_roles where business_id = p_business_id and code = 'cashier' and deleted_at is null;
  select id into v_staff from public.business_roles where business_id = p_business_id and code = 'staff' and deleted_at is null;
  select id into v_auditor from public.business_roles where business_id = p_business_id and code = 'auditor' and deleted_at is null;

  -- Owner gets every permission.
  insert into public.role_permissions (business_id, role_id, permission_id)
  select p_business_id, v_owner, p.id
  from public.permissions p
  on conflict (role_id, permission_id) do nothing;

  -- Administrator gets all except ownership-sensitive business/settings controls.
  insert into public.role_permissions (business_id, role_id, permission_id)
  select p_business_id, v_admin, p.id
  from public.permissions p
  where p.code not in ('business.update', 'settings.manage')
  on conflict (role_id, permission_id) do nothing;

  -- Manager.
  insert into public.role_permissions (business_id, role_id, permission_id)
  select p_business_id, v_manager, p.id
  from public.permissions p
  where p.code in (
    'dashboard.read','business.read','locations.read',
    'employees.read','employees.invite','roles.read',
    'products.read','products.create','products.update',
    'inventory.read','inventory.receive','inventory.adjust','inventory.transfer',
    'customers.read','customers.manage','loyalty.read','loyalty.manage',
    'sales.read','sales.create','sales.refund',
    'pricing.read','pricing.manage','reports.read'
  )
  on conflict (role_id, permission_id) do nothing;

  -- Inventory Manager.
  insert into public.role_permissions (business_id, role_id, permission_id)
  select p_business_id, v_inventory, p.id
  from public.permissions p
  where p.code in (
    'dashboard.read','locations.read','products.read','products.create','products.update',
    'inventory.read','inventory.receive','inventory.adjust','inventory.transfer',
    'pricing.read','reports.read'
  )
  on conflict (role_id, permission_id) do nothing;

  -- Cashier.
  insert into public.role_permissions (business_id, role_id, permission_id)
  select p_business_id, v_cashier, p.id
  from public.permissions p
  where p.code in (
    'dashboard.read','locations.read','products.read','inventory.read',
    'customers.read','customers.manage','loyalty.read',
    'sales.read','sales.create','pricing.read'
  )
  on conflict (role_id, permission_id) do nothing;

  -- Staff.
  insert into public.role_permissions (business_id, role_id, permission_id)
  select p_business_id, v_staff, p.id
  from public.permissions p
  where p.code in (
    'dashboard.read','locations.read','products.read','inventory.read',
    'customers.read','loyalty.read','sales.read','pricing.read'
  )
  on conflict (role_id, permission_id) do nothing;

  -- Read-only Auditor.
  insert into public.role_permissions (business_id, role_id, permission_id)
  select p_business_id, v_auditor, p.id
  from public.permissions p
  where p.code in (
    'dashboard.read','business.read','locations.read','employees.read','roles.read',
    'products.read','inventory.read','customers.read','loyalty.read',
    'sales.read','pricing.read','reports.read','audit.read'
  )
  on conflict (role_id, permission_id) do nothing;
end;
$$;

revoke all on function public.provision_default_business_roles(uuid) from public;
grant execute on function public.provision_default_business_roles(uuid) to service_role;

create or replace function public.provision_roles_for_new_business()
returns trigger
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
begin
  perform public.provision_default_business_roles(new.id);
  return new;
end;
$$;

drop trigger if exists businesses_provision_default_roles on public.businesses;
create trigger businesses_provision_default_roles
after insert on public.businesses
for each row execute function public.provision_roles_for_new_business();

-- Provision roles for businesses that existed before migration 008.
do $$
declare
  v_business record;
begin
  for v_business in
    select id from public.businesses where deleted_at is null
  loop
    perform public.provision_default_business_roles(v_business.id);
  end loop;
end $$;

-- Backfill role assignments from the legacy employees.role enum.
insert into public.employee_role_assignments
  (business_id, employee_id, role_id, location_id, status, assigned_by)
select
  e.business_id,
  e.id,
  r.id,
  null,
  case when e.status = 'active' then 'active'::public.access_assignment_status
       else 'suspended'::public.access_assignment_status end,
  e.created_by
from public.employees e
join public.business_roles r
  on r.business_id = e.business_id
 and r.code = case e.role::text
   when 'owner' then 'owner'
   when 'manager' then 'manager'
   when 'supervisor' then 'manager'
   else 'staff'
 end
 and r.deleted_at is null
where e.deleted_at is null
on conflict do nothing;

-- Backfill explicit home-location access for employees who do not have all-location access.
insert into public.employee_locations
  (business_id, employee_id, location_id, status, granted_by)
select
  e.business_id,
  e.id,
  e.home_location_id,
  case when e.status = 'active' then 'active'::public.access_assignment_status
       else 'suspended'::public.access_assignment_status end,
  e.created_by
from public.employees e
where e.home_location_id is not null
  and e.can_access_all_locations = false
  and e.deleted_at is null
on conflict do nothing;

-- =========================================================
-- RLS FOUNDATION FOR NEW TABLES
-- =========================================================

alter table public.permissions enable row level security;
alter table public.business_roles enable row level security;
alter table public.role_permissions enable row level security;
alter table public.employee_locations enable row level security;
alter table public.employee_role_assignments enable row level security;
alter table public.security_audit_events enable row level security;

alter table public.permissions force row level security;
alter table public.business_roles force row level security;
alter table public.role_permissions force row level security;
alter table public.employee_locations force row level security;
alter table public.employee_role_assignments force row level security;
alter table public.security_audit_events force row level security;

-- Permission catalog can be read by authenticated users, never directly modified.
drop policy if exists permissions_authenticated_read on public.permissions;
create policy permissions_authenticated_read
on public.permissions for select
to authenticated
using (true);

-- Business roles.
drop policy if exists business_roles_read on public.business_roles;
create policy business_roles_read
on public.business_roles for select
to authenticated
using (
  public.has_permission(business_id, 'roles.read')
  or public.has_permission(business_id, 'employees.manage')
);

drop policy if exists business_roles_insert on public.business_roles;
create policy business_roles_insert
on public.business_roles for insert
to authenticated
with check (
  public.has_permission(business_id, 'roles.manage')
  and is_system = false
  and is_owner_role = false
);

drop policy if exists business_roles_update on public.business_roles;
create policy business_roles_update
on public.business_roles for update
to authenticated
using (public.has_permission(business_id, 'roles.manage'))
with check (
  public.has_permission(business_id, 'roles.manage')
  and is_system = false
  and is_owner_role = false
);

-- Role permissions.
drop policy if exists role_permissions_read on public.role_permissions;
create policy role_permissions_read
on public.role_permissions for select
to authenticated
using (
  public.has_permission(business_id, 'roles.read')
  or public.has_permission(business_id, 'employees.manage')
);

drop policy if exists role_permissions_insert on public.role_permissions;
create policy role_permissions_insert
on public.role_permissions for insert
to authenticated
with check (
  public.has_permission(business_id, 'roles.manage')
  and exists (
    select 1 from public.business_roles r
    where r.id = role_id
      and r.business_id = business_id
      and r.is_system = false
      and r.deleted_at is null
  )
);

drop policy if exists role_permissions_delete on public.role_permissions;
create policy role_permissions_delete
on public.role_permissions for delete
to authenticated
using (
  public.has_permission(business_id, 'roles.manage')
  and exists (
    select 1 from public.business_roles r
    where r.id = role_id
      and r.business_id = business_id
      and r.is_system = false
      and r.deleted_at is null
  )
);

-- Employee locations and assignments.
drop policy if exists employee_locations_read on public.employee_locations;
create policy employee_locations_read
on public.employee_locations for select
to authenticated
using (
  employee_id = public.current_employee_id(business_id)
  or public.has_permission(business_id, 'employees.read')
  or public.has_permission(business_id, 'employees.manage')
);

drop policy if exists employee_locations_manage on public.employee_locations;
create policy employee_locations_manage
on public.employee_locations for all
to authenticated
using (public.has_permission(business_id, 'employees.manage'))
with check (public.has_permission(business_id, 'employees.manage'));

drop policy if exists employee_role_assignments_read on public.employee_role_assignments;
create policy employee_role_assignments_read
on public.employee_role_assignments for select
to authenticated
using (
  employee_id = public.current_employee_id(business_id)
  or public.has_permission(business_id, 'roles.read')
  or public.has_permission(business_id, 'employees.manage')
);

drop policy if exists employee_role_assignments_manage on public.employee_role_assignments;
create policy employee_role_assignments_manage
on public.employee_role_assignments for all
to authenticated
using (
  public.has_permission(business_id, 'employees.manage')
  and not exists (
    select 1 from public.business_roles r
    where r.id = role_id and r.is_owner_role = true
  )
)
with check (
  public.has_permission(business_id, 'employees.manage')
  and not exists (
    select 1 from public.business_roles r
    where r.id = role_id and r.is_owner_role = true
  )
);

-- Audit events are readable only with audit.read. Writes use trusted server code.
drop policy if exists security_audit_events_read on public.security_audit_events;
create policy security_audit_events_read
on public.security_audit_events for select
to authenticated
using (
  public.has_permission(business_id, 'audit.read', location_id)
);

-- =========================================================
-- RLS POLICIES FOR EXISTING CORE TABLES
-- =========================================================

-- Businesses
drop policy if exists businesses_member_read on public.businesses;
create policy businesses_member_read
on public.businesses for select
to authenticated
using (public.is_business_member(id));

drop policy if exists businesses_owner_update on public.businesses;
create policy businesses_owner_update
on public.businesses for update
to authenticated
using (public.is_business_owner(id))
with check (public.is_business_owner(id));

-- Locations
drop policy if exists business_locations_read on public.business_locations;
create policy business_locations_read
on public.business_locations for select
to authenticated
using (
  public.can_access_location(business_id, id)
  or public.has_permission(business_id, 'locations.manage')
);

drop policy if exists business_locations_manage on public.business_locations;
create policy business_locations_manage
on public.business_locations for all
to authenticated
using (public.has_permission(business_id, 'locations.manage'))
with check (public.has_permission(business_id, 'locations.manage'));

-- Employees
drop policy if exists employees_read on public.employees;
create policy employees_read
on public.employees for select
to authenticated
using (
  auth_user_id = auth.uid()
  or public.has_permission(business_id, 'employees.read')
  or public.has_permission(business_id, 'employees.manage')
);

drop policy if exists employees_manage on public.employees;
create policy employees_manage
on public.employees for all
to authenticated
using (public.has_permission(business_id, 'employees.manage'))
with check (public.has_permission(business_id, 'employees.manage'));

-- Customers remain platform identities. Access requires a membership in an allowed tenant.
drop policy if exists customers_tenant_read on public.customers;
create policy customers_tenant_read
on public.customers for select
to authenticated
using (
  auth_user_id = auth.uid()
  or exists (
    select 1
    from public.memberships m
    where m.customer_id = customers.id
      and m.deleted_at is null
      and public.has_permission(m.business_id, 'customers.read')
  )
);

-- Memberships
drop policy if exists memberships_read on public.memberships;
create policy memberships_read
on public.memberships for select
to authenticated
using (public.has_permission(business_id, 'customers.read'));

drop policy if exists memberships_manage on public.memberships;
create policy memberships_manage
on public.memberships for all
to authenticated
using (public.has_permission(business_id, 'customers.manage'))
with check (public.has_permission(business_id, 'customers.manage'));

-- Product categories
drop policy if exists product_categories_read on public.product_categories;
create policy product_categories_read
on public.product_categories for select
to authenticated
using (public.has_permission(business_id, 'products.read'));

drop policy if exists product_categories_insert on public.product_categories;
create policy product_categories_insert
on public.product_categories for insert
to authenticated
with check (public.has_permission(business_id, 'products.create'));

drop policy if exists product_categories_update on public.product_categories;
create policy product_categories_update
on public.product_categories for update
to authenticated
using (public.has_permission(business_id, 'products.update'))
with check (public.has_permission(business_id, 'products.update'));

drop policy if exists product_categories_delete on public.product_categories;
create policy product_categories_delete
on public.product_categories for delete
to authenticated
using (public.has_permission(business_id, 'products.delete'));

-- Products
drop policy if exists products_read on public.products;
create policy products_read
on public.products for select
to authenticated
using (public.has_permission(business_id, 'products.read'));

drop policy if exists products_insert on public.products;
create policy products_insert
on public.products for insert
to authenticated
with check (public.has_permission(business_id, 'products.create'));

drop policy if exists products_update on public.products;
create policy products_update
on public.products for update
to authenticated
using (public.has_permission(business_id, 'products.update'))
with check (public.has_permission(business_id, 'products.update'));

drop policy if exists products_delete on public.products;
create policy products_delete
on public.products for delete
to authenticated
using (public.has_permission(business_id, 'products.delete'));

-- Product barcodes
drop policy if exists product_barcodes_read on public.product_barcodes;
create policy product_barcodes_read
on public.product_barcodes for select
to authenticated
using (public.has_permission(business_id, 'products.read'));

drop policy if exists product_barcodes_insert on public.product_barcodes;
create policy product_barcodes_insert
on public.product_barcodes for insert
to authenticated
with check (public.has_permission(business_id, 'products.update'));

drop policy if exists product_barcodes_update on public.product_barcodes;
create policy product_barcodes_update
on public.product_barcodes for update
to authenticated
using (public.has_permission(business_id, 'products.update'))
with check (public.has_permission(business_id, 'products.update'));

drop policy if exists product_barcodes_delete on public.product_barcodes;
create policy product_barcodes_delete
on public.product_barcodes for delete
to authenticated
using (public.has_permission(business_id, 'products.update'));

-- Inventory balances and movements are read-only through the client.
-- Inventory mutations continue through controlled RPCs/server-side code.
drop policy if exists inventory_balances_read on public.inventory_balances;
create policy inventory_balances_read
on public.inventory_balances for select
to authenticated
using (
  public.has_permission(business_id, 'inventory.read', location_id)
);

drop policy if exists inventory_movements_read on public.inventory_movements;
create policy inventory_movements_read
on public.inventory_movements for select
to authenticated
using (
  public.has_permission(business_id, 'inventory.read', location_id)
);

-- =========================================================
-- GRANTS
-- RLS still controls every row.
-- =========================================================

grant usage on schema public to authenticated;

grant select on public.permissions to authenticated;
grant select, insert, update on public.businesses to authenticated;
grant select, insert, update, delete on public.business_locations to authenticated;
grant select, insert, update, delete on public.employees to authenticated;
grant select on public.customers to authenticated;
grant select, insert, update, delete on public.memberships to authenticated;
grant select, insert, update, delete on public.business_roles to authenticated;
grant select, insert, delete on public.role_permissions to authenticated;
grant select, insert, update, delete on public.employee_locations to authenticated;
grant select, insert, update, delete on public.employee_role_assignments to authenticated;
grant select on public.security_audit_events to authenticated;
grant select, insert, update, delete on public.product_categories to authenticated;
grant select, insert, update, delete on public.products to authenticated;
grant select, insert, update, delete on public.product_barcodes to authenticated;
grant select on public.inventory_balances to authenticated;
grant select on public.inventory_movements to authenticated;
grant select on public.inventory_stock_summary to authenticated;

-- Explicitly keep dangerous audit writes server-only.
revoke insert, update, delete on public.security_audit_events from authenticated;

-- =========================================================
-- COMMENTS
-- =========================================================

comment on table public.permissions is
  'Global immutable permission catalog used by tenant-specific roles.';

comment on table public.business_roles is
  'Tenant-owned roles. System roles are provisioned automatically and protected.';

comment on table public.role_permissions is
  'Permission grants attached to a role within the same business tenant.';

comment on table public.employee_locations is
  'Explicit employee access to business locations when all-location access is disabled.';

comment on table public.employee_role_assignments is
  'Business-wide or location-scoped role assignments for employees.';

comment on table public.security_audit_events is
  'Append-only security and fraud audit event store.';

comment on function public.has_permission(uuid, text, uuid) is
  'Returns true only when auth.uid() maps to an active employee with an active role containing the requested permission and, when supplied, location access.';
