begin;

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),

  title text not null,
  description text,
  event_date date not null,
  start_time time,
  end_time time,

  flyer_url text,
  flyer_path text,

  tag text not null default 'VIVID EVENT',
  dj text,
  admission text,

  is_published boolean not null default false,

  created_by uuid references public.staff_users(id) on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists events_date_idx
on public.events(event_date asc);

create index if not exists events_published_date_idx
on public.events(is_published, event_date asc);

drop trigger if exists events_set_updated_at on public.events;

create trigger events_set_updated_at
before update on public.events
for each row execute function public.set_updated_at();

alter table public.events enable row level security;

drop policy if exists events_public_read_policy
on public.events;

create policy events_public_read_policy
on public.events
for select
to anon, authenticated
using (
  is_published = true
  and event_date >= current_date
);

drop policy if exists events_owner_read_policy
on public.events;

create policy events_owner_read_policy
on public.events
for select
to authenticated
using (
  public.has_staff_role(array['admin', 'owner'])
);

drop policy if exists events_owner_insert_policy
on public.events;

create policy events_owner_insert_policy
on public.events
for insert
to authenticated
with check (
  public.has_staff_role(array['admin', 'owner'])
);

drop policy if exists events_owner_update_policy
on public.events;

create policy events_owner_update_policy
on public.events
for update
to authenticated
using (
  public.has_staff_role(array['admin', 'owner'])
)
with check (
  public.has_staff_role(array['admin', 'owner'])
);

drop policy if exists events_owner_delete_policy
on public.events;

create policy events_owner_delete_policy
on public.events
for delete
to authenticated
using (
  public.has_staff_role(array['admin', 'owner'])
);

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'event-flyers',
  'event-flyers',
  true,
  10485760,
  array[
    'image/jpeg',
    'image/png',
    'image/webp'
  ]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists event_flyers_public_read
on storage.objects;

create policy event_flyers_public_read
on storage.objects
for select
to public
using (
  bucket_id = 'event-flyers'
);

drop policy if exists event_flyers_owner_insert
on storage.objects;

create policy event_flyers_owner_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'event-flyers'
  and public.has_staff_role(array['admin', 'owner'])
);

drop policy if exists event_flyers_owner_update
on storage.objects;

create policy event_flyers_owner_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'event-flyers'
  and public.has_staff_role(array['admin', 'owner'])
);

drop policy if exists event_flyers_owner_delete
on storage.objects;

create policy event_flyers_owner_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'event-flyers'
  and public.has_staff_role(array['admin', 'owner'])
);

commit;