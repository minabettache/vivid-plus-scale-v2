begin;

create or replace function public.handle_new_member()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_birthday date;
  v_qr_code text;
begin
  -- Only accept a valid YYYY-MM-DD birthday.
  if coalesce(new.raw_user_meta_data ->> 'birthday', '') ~ '^\d{4}-\d{2}-\d{2}$' then
    v_birthday := (new.raw_user_meta_data ->> 'birthday')::date;
  else
    v_birthday := null;
  end if;

  v_qr_code :=
    'VVP-' ||
    upper(substr(replace(new.id::text, '-', ''), 1, 12));

  insert into public.members (
    user_id,
    full_name,
    phone,
    email,
    birthday,
    membership_level,
    points,
    lifetime_points,
    total_visits,
    total_spent,
    qr_code,
    is_active
  )
  values (
    new.id,
    nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'phone'), ''),
    new.email,
    v_birthday,
    'Member',
    100,
    100,
    0,
    0,
    v_qr_code,
    true
  )
  on conflict (user_id) where user_id is not null
  do update set
    full_name = excluded.full_name,
    phone = excluded.phone,
    email = excluded.email,
    birthday = excluded.birthday;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_member();

commit;