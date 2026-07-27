begin;

-- Safe defaults for new VIVID+ members
alter table public.members
  alter column points set default 0,
  alter column lifetime_points set default 0,
  alter column total_visits set default 0,
  alter column total_spent set default 0,
  alter column is_active set default true,
  alter column membership_level set default 'Member';

-- Connect each member profile to one Supabase Auth account
alter table public.members
  drop constraint if exists members_user_id_fkey;

alter table public.members
  add constraint members_user_id_fkey
  foreign key (user_id)
  references auth.users(id)
  on delete cascade;

-- One member profile per authenticated user
create unique index if not exists members_user_id_unique_idx
on public.members(user_id)
where user_id is not null;

-- Helpful indexes
create index if not exists members_phone_idx
on public.members(phone);

create index if not exists members_email_idx
on public.members(email);

create index if not exists members_qr_code_idx
on public.members(qr_code);

-- Turn on database security
alter table public.members enable row level security;

-- Remove old policies if they already exist
drop policy if exists members_select_own_policy on public.members;
drop policy if exists members_insert_own_policy on public.members;
drop policy if exists members_update_own_policy on public.members;
drop policy if exists members_staff_select_policy on public.members;

-- Members can read their own profile
create policy members_select_own_policy
on public.members
for select
to authenticated
using (
  user_id = auth.uid()
);

-- Members can create only their own profile
create policy members_insert_own_policy
on public.members
for insert
to authenticated
with check (
  user_id = auth.uid()
);

-- Members can update only their own profile
create policy members_update_own_policy
on public.members
for update
to authenticated
using (
  user_id = auth.uid()
)
with check (
  user_id = auth.uid()
);

-- Active staff can search and view members
create policy members_staff_select_policy
on public.members
for select
to authenticated
using (
  public.is_active_staff()
);

commit;