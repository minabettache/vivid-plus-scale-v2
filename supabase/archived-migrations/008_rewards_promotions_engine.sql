-- ============================================================
-- VIVID+ REWARDS, COUPONS, CAMPAIGNS AND NOTIFICATIONS ENGINE
-- Migration: 008_rewards_promotions_engine.sql
-- ============================================================

create extension if not exists pgcrypto;

-- ============================================================
-- ENUMS
-- ============================================================

do $$
begin
  create type reward_type as enum (
    'free_cocktail',
    'free_hookah',
    'hookah_and_cocktail',
    'champagne_percentage_discount',
    'bonus_points',
    'points_multiplier'
  );
exception
  when duplicate_object then null;
end
$$;

do $$
begin
  create type promotion_status as enum (
    'draft',
    'scheduled',
    'active',
    'paused',
    'expired'
  );
exception
  when duplicate_object then null;
end
$$;

do $$
begin
  create type redemption_status as enum (
    'issued',
    'redeemed',
    'expired',
    'cancelled'
  );
exception
  when duplicate_object then null;
end
$$;

do $$
begin
  create type notification_channel as enum (
    'in_app',
    'push',
    'email',
    'sms'
  );
exception
  when duplicate_object then null;
end
$$;

-- ============================================================
-- REWARDS CATALOG
-- ============================================================

create table if not exists rewards (
  id uuid primary key default gen_random_uuid(),

  name text not null,
  description text,

  reward_type reward_type not null,
  points_cost integer not null default 0 check (points_cost >= 0),

  percentage_discount numeric(5,2)
    check (
      percentage_discount is null
      or percentage_discount between 0 and 100
    ),

  maximum_discount_amount numeric(10,2)
    check (
      maximum_discount_amount is null
      or maximum_discount_amount >= 0
    ),

  bonus_points integer
    check (
      bonus_points is null
      or bonus_points >= 0
    ),

  points_multiplier numeric(5,2)
    check (
      points_multiplier is null
      or points_multiplier >= 1
    ),

  minimum_purchase_amount numeric(10,2)
    not null default 0
    check (minimum_purchase_amount >= 0),

  valid_days smallint[]
    not null default array[0,1,2,3,4,5,6],

  valid_start_time time,
  valid_end_time time,

  excluded_during_happy_hour boolean not null default true,
  happy_hour_end_time time not null default '22:00:00',

  allowed_tiers text[]
    not null default array['bronze','silver','gold','platinum'],

  maximum_redemptions_per_member integer
    check (
      maximum_redemptions_per_member is null
      or maximum_redemptions_per_member > 0
    ),

  redemption_cooldown_days integer
    not null default 0
    check (redemption_cooldown_days >= 0),

  requires_staff_approval boolean not null default true,

  starts_at timestamptz,
  ends_at timestamptz,

  is_active boolean not null default true,

  created_by_staff_user_id uuid references staff_users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists rewards_active_idx
  on rewards(is_active);

create index if not exists rewards_type_idx
  on rewards(reward_type);

-- ============================================================
-- MEMBER REWARD WALLET
-- ============================================================

create table if not exists member_rewards (
  id uuid primary key default gen_random_uuid(),

  member_id uuid not null references members(id) on delete cascade,
  reward_id uuid not null references rewards(id),

  status redemption_status not null default 'issued',

  points_spent integer not null default 0
    check (points_spent >= 0),

  issued_at timestamptz not null default now(),
  expires_at timestamptz,
  redeemed_at timestamptz,

  redeemed_sale_id uuid references sales(id),
  redeemed_by_staff_user_id uuid references staff_users(id),

  redemption_code text not null unique,

  notes text,

  created_at timestamptz not null default now()
);

create index if not exists member_rewards_member_idx
  on member_rewards(member_id);

create index if not exists member_rewards_status_idx
  on member_rewards(status);

create index if not exists member_rewards_code_idx
  on member_rewards(redemption_code);

-- ============================================================
-- PROMOTION CAMPAIGNS
-- ============================================================

create table if not exists promotions (
  id uuid primary key default gen_random_uuid(),

  name text not null,
  headline text not null,
  message text not null,

  status promotion_status not null default 'draft',

  reward_id uuid references rewards(id),

  promo_code text unique,

  target_tiers text[]
    not null default array['bronze','silver','gold','platinum'],

  target_inactive_days integer
    check (
      target_inactive_days is null
      or target_inactive_days >= 0
    ),

  target_minimum_lifetime_spend numeric(10,2)
    check (
      target_minimum_lifetime_spend is null
      or target_minimum_lifetime_spend >= 0
    ),

  nearby_radius_miles numeric(5,2)
    check (
      nearby_radius_miles is null
      or nearby_radius_miles between 1 and 50
    ),

  valid_days smallint[]
    not null default array[0,1,2,3,4,5,6],

  valid_start_time time,
  valid_end_time time,

  starts_at timestamptz,
  ends_at timestamptz,

  maximum_total_claims integer
    check (
      maximum_total_claims is null
      or maximum_total_claims > 0
    ),

  maximum_claims_per_member integer
    not null default 1
    check (maximum_claims_per_member > 0),

  cannot_combine_with_happy_hour boolean not null default true,
  cannot_combine_with_other_promotions boolean not null default true,

  created_by_staff_user_id uuid references staff_users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists promotions_status_idx
  on promotions(status);

create index if not exists promotions_code_idx
  on promotions(promo_code);

create index if not exists promotions_schedule_idx
  on promotions(starts_at, ends_at);

-- ============================================================
-- PROMOTION CLAIMS
-- ============================================================

create table if not exists promotion_claims (
  id uuid primary key default gen_random_uuid(),

  promotion_id uuid not null references promotions(id) on delete cascade,
  member_id uuid not null references members(id) on delete cascade,

  member_reward_id uuid references member_rewards(id),

  claimed_at timestamptz not null default now(),
  redeemed_at timestamptz,

  redeemed_sale_id uuid references sales(id),
  redeemed_by_staff_user_id uuid references staff_users(id),

  is_redeemed boolean not null default false,

  unique(promotion_id, member_id)
);

create index if not exists promotion_claims_member_idx
  on promotion_claims(member_id);

create index if not exists promotion_claims_promotion_idx
  on promotion_claims(promotion_id);

-- ============================================================
-- MEMBER NOTIFICATION PREFERENCES
-- ============================================================

create table if not exists member_notification_preferences (
  member_id uuid primary key references members(id) on delete cascade,

  in_app_enabled boolean not null default true,
  push_enabled boolean not null default false,
  email_enabled boolean not null default true,
  sms_enabled boolean not null default false,

  nearby_offers_enabled boolean not null default false,
  location_permission_granted boolean not null default false,

  preferred_radius_miles numeric(5,2)
    not null default 7
    check (preferred_radius_miles between 1 and 50),

  daily_promotion_enabled boolean not null default true,

  last_known_latitude numeric(10,7),
  last_known_longitude numeric(10,7),
  last_location_updated_at timestamptz,

  last_nearby_notification_at timestamptz,
  last_daily_notification_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================
-- NOTIFICATION QUEUE
-- ============================================================

create table if not exists notification_queue (
  id uuid primary key default gen_random_uuid(),

  member_id uuid not null references members(id) on delete cascade,
  promotion_id uuid references promotions(id) on delete set null,

  channel notification_channel not null,

  title text not null,
  message text not null,

  scheduled_for timestamptz not null default now(),
  sent_at timestamptz,

  delivery_status text not null default 'pending'
    check (
      delivery_status in (
        'pending',
        'processing',
        'sent',
        'failed',
        'cancelled'
      )
    ),

  failure_reason text,

  created_at timestamptz not null default now()
);

create index if not exists notification_queue_pending_idx
  on notification_queue(delivery_status, scheduled_for);

create index if not exists notification_queue_member_idx
  on notification_queue(member_id);

-- ============================================================
-- DEVICE TOKENS FOR PUSH NOTIFICATIONS
-- ============================================================

create table if not exists member_devices (
  id uuid primary key default gen_random_uuid(),

  member_id uuid not null references members(id) on delete cascade,

  device_token text not null unique,
  platform text not null
    check (platform in ('ios', 'android', 'web')),

  is_active boolean not null default true,

  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists member_devices_member_idx
  on member_devices(member_id);

-- ============================================================
-- AUTOMATIC UPDATED_AT
-- ============================================================

create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists rewards_set_updated_at on rewards;

create trigger rewards_set_updated_at
before update on rewards
for each row
execute function set_updated_at();

drop trigger if exists promotions_set_updated_at on promotions;

create trigger promotions_set_updated_at
before update on promotions
for each row
execute function set_updated_at();

drop trigger if exists member_notification_preferences_set_updated_at
  on member_notification_preferences;

create trigger member_notification_preferences_set_updated_at
before update on member_notification_preferences
for each row
execute function set_updated_at();

-- ============================================================
-- REDEMPTION CODE GENERATOR
-- ============================================================

create or replace function generate_reward_redemption_code()
returns text
language plpgsql
as $$
declare
  generated_code text;
begin
  loop
    generated_code :=
      'VIVID-' ||
      upper(substr(encode(gen_random_bytes(6), 'hex'), 1, 8));

    exit when not exists (
      select 1
      from member_rewards
      where redemption_code = generated_code
    );
  end loop;

  return generated_code;
end;
$$;

-- ============================================================
-- CLAIM REWARD RPC
-- ============================================================

create or replace function claim_member_reward(
  p_member_id uuid,
  p_reward_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_member members%rowtype;
  selected_reward rewards%rowtype;
  new_member_reward member_rewards%rowtype;

  current_day smallint;
  current_local_time time;
  current_tier text;
  previous_redemptions integer;
  latest_redemption timestamptz;
begin
  select *
  into selected_member
  from members
  where id = p_member_id
  for update;

  if not found then
    raise exception 'Member not found.';
  end if;

  select *
  into selected_reward
  from rewards
  where id = p_reward_id
    and is_active = true;

  if not found then
    raise exception 'Reward is not available.';
  end if;

  if selected_reward.starts_at is not null
     and now() < selected_reward.starts_at then
    raise exception 'Reward is not active yet.';
  end if;

  if selected_reward.ends_at is not null
     and now() > selected_reward.ends_at then
    raise exception 'Reward has expired.';
  end if;

  current_day :=
    extract(
      dow from now() at time zone 'America/New_York'
    )::smallint;

  current_local_time :=
    (now() at time zone 'America/New_York')::time;

  if not current_day = any(selected_reward.valid_days) then
    raise exception 'Reward is not available today.';
  end if;

  if selected_reward.valid_start_time is not null
     and selected_reward.valid_end_time is not null then

    if selected_reward.valid_start_time < selected_reward.valid_end_time then
      if current_local_time < selected_reward.valid_start_time
         or current_local_time > selected_reward.valid_end_time then
        raise exception 'Reward is not available at this time.';
      end if;
    else
      if current_local_time < selected_reward.valid_start_time
         and current_local_time > selected_reward.valid_end_time then
        raise exception 'Reward is not available at this time.';
      end if;
    end if;
  end if;

  if selected_reward.excluded_during_happy_hour
     and current_local_time < selected_reward.happy_hour_end_time then
    raise exception 'Reward cannot be claimed during Happy Hour.';
  end if;

  current_tier := lower(coalesce(selected_member.tier, 'bronze'));

  if not current_tier = any(selected_reward.allowed_tiers) then
    raise exception 'Your membership tier is not eligible for this reward.';
  end if;

  if selected_member.points < selected_reward.points_cost then
    raise exception 'Not enough points.';
  end if;

  select count(*), max(redeemed_at)
  into previous_redemptions, latest_redemption
  from member_rewards
  where member_id = p_member_id
    and reward_id = p_reward_id
    and status in ('issued', 'redeemed');

  if selected_reward.maximum_redemptions_per_member is not null
     and previous_redemptions >=
         selected_reward.maximum_redemptions_per_member then
    raise exception 'Maximum reward redemptions reached.';
  end if;

  if selected_reward.redemption_cooldown_days > 0
     and latest_redemption is not null
     and latest_redemption >
       now() -
       make_interval(days => selected_reward.redemption_cooldown_days) then
    raise exception 'This reward is still in its cooldown period.';
  end if;

  update members
  set points = points - selected_reward.points_cost
  where id = p_member_id;

  if selected_reward.points_cost > 0 then
    insert into points_transactions (
      member_id,
      points,
      transaction_type,
      description
    )
    values (
      p_member_id,
      -selected_reward.points_cost,
      'redemption',
      'Reward claimed: ' || selected_reward.name
    );
  end if;

  insert into member_rewards (
    member_id,
    reward_id,
    points_spent,
    redemption_code,
    expires_at
  )
  values (
    p_member_id,
    p_reward_id,
    selected_reward.points_cost,
    generate_reward_redemption_code(),
    now() + interval '7 days'
  )
  returning *
  into new_member_reward;

  return jsonb_build_object(
    'success', true,
    'member_reward_id', new_member_reward.id,
    'redemption_code', new_member_reward.redemption_code,
    'reward_name', selected_reward.name,
    'points_spent', selected_reward.points_cost,
    'expires_at', new_member_reward.expires_at
  );
end;
$$;

-- ============================================================
-- REDEEM REWARD RPC
-- ============================================================

create or replace function redeem_member_reward(
  p_redemption_code text,
  p_staff_user_id uuid,
  p_sale_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_member_reward member_rewards%rowtype;
  selected_reward rewards%rowtype;
begin
  select *
  into selected_member_reward
  from member_rewards
  where upper(redemption_code) = upper(trim(p_redemption_code))
  for update;

  if not found then
    raise exception 'Reward code not found.';
  end if;

  if selected_member_reward.status <> 'issued' then
    raise exception 'Reward is not available for redemption.';
  end if;

  if selected_member_reward.expires_at is not null
     and selected_member_reward.expires_at < now() then

    update member_rewards
    set status = 'expired'
    where id = selected_member_reward.id;

    raise exception 'Reward has expired.';
  end if;

  select *
  into selected_reward
  from rewards
  where id = selected_member_reward.reward_id;

  update member_rewards
  set
    status = 'redeemed',
    redeemed_at = now(),
    redeemed_sale_id = p_sale_id,
    redeemed_by_staff_user_id = p_staff_user_id
  where id = selected_member_reward.id;

  insert into audit_logs (
    staff_user_id,
    action,
    entity_type,
    entity_id,
    metadata
  )
  values (
    p_staff_user_id,
    'reward_redeemed',
    'member_reward',
    selected_member_reward.id,
    jsonb_build_object(
      'reward_name', selected_reward.name,
      'redemption_code', selected_member_reward.redemption_code,
      'member_id', selected_member_reward.member_id,
      'sale_id', p_sale_id
    )
  );

  return jsonb_build_object(
    'success', true,
    'reward_name', selected_reward.name,
    'reward_type', selected_reward.reward_type,
    'percentage_discount', selected_reward.percentage_discount,
    'maximum_discount_amount', selected_reward.maximum_discount_amount,
    'redeemed_at', now()
  );
end;
$$;

-- ============================================================
-- INITIAL VIVID+ REWARDS
-- These do not stack with Happy Hour.
-- ============================================================

insert into rewards (
  name,
  description,
  reward_type,
  points_cost,
  valid_days,
  valid_start_time,
  valid_end_time,
  excluded_during_happy_hour,
  maximum_redemptions_per_member,
  redemption_cooldown_days
)
select
  'Free Cocktail',
  'One complimentary cocktail. Valid after Happy Hour.',
  'free_cocktail',
  300,
  array[0,1,2,3,4],
  '22:00:00',
  '02:00:00',
  true,
  null,
  7
where not exists (
  select 1 from rewards where name = 'Free Cocktail'
);

insert into rewards (
  name,
  description,
  reward_type,
  points_cost,
  valid_days,
  valid_start_time,
  valid_end_time,
  excluded_during_happy_hour,
  maximum_redemptions_per_member,
  redemption_cooldown_days
)
select
  'Free Hookah',
  'One complimentary hookah. Valid Monday through Wednesday after Happy Hour.',
  'free_hookah',
  700,
  array[1,2,3],
  '22:00:00',
  '02:00:00',
  true,
  null,
  30
where not exists (
  select 1 from rewards where name = 'Free Hookah'
);

insert into rewards (
  name,
  description,
  reward_type,
  points_cost,
  valid_days,
  valid_start_time,
  valid_end_time,
  excluded_during_happy_hour,
  maximum_redemptions_per_member,
  redemption_cooldown_days
)
select
  'Hookah and Cocktail',
  'One complimentary hookah and one complimentary cocktail.',
  'hookah_and_cocktail',
  1200,
  array[1,2,3],
  '22:00:00',
  '02:00:00',
  true,
  null,
  45
where not exists (
  select 1 from rewards where name = 'Hookah and Cocktail'
);

insert into rewards (
  name,
  description,
  reward_type,
  points_cost,
  percentage_discount,
  maximum_discount_amount,
  minimum_purchase_amount,
  valid_days,
  valid_start_time,
  valid_end_time,
  excluded_during_happy_hour,
  maximum_redemptions_per_member,
  redemption_cooldown_days
)
select
  '50% Off Champagne',
  'Receive 50% off one champagne bottle. Maximum discount is $100.',
  'champagne_percentage_discount',
  2500,
  50,
  100,
  50,
  array[1,2,3,4],
  '22:00:00',
  '02:00:00',
  true,
  null,
  90
where not exists (
  select 1 from rewards where name = '50% Off Champagne'
);

-- ============================================================
-- DEFAULT MEMBER NOTIFICATION SETTINGS
-- ============================================================

insert into member_notification_preferences (
  member_id
)
select id
from members
on conflict (member_id) do nothing;

-- ============================================================
-- RLS
-- ============================================================

alter table rewards enable row level security;
alter table member_rewards enable row level security;
alter table promotions enable row level security;
alter table promotion_claims enable row level security;
alter table member_notification_preferences enable row level security;
alter table notification_queue enable row level security;
alter table member_devices enable row level security;

-- Public/member users may view active rewards.

drop policy if exists "Active rewards are viewable"
  on rewards;

create policy "Active rewards are viewable"
on rewards
for select
using (is_active = true);

-- Service role continues to manage all records.
-- Member-specific access will be added through secure API routes.

grant execute on function claim_member_reward(uuid, uuid)
to authenticated;

grant execute on function redeem_member_reward(text, uuid, uuid)
to authenticated;