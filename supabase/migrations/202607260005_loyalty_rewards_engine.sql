-- =========================================================
-- VIVID+ LOYALTY LEDGER & REWARDS ENGINE
-- Migration 005
--
-- Creates:
--   1. rewards
--   2. reward_rules
--   3. reward_redemptions
--   4. loyalty_ledger
--
-- Core rules:
--   - Loyalty ledger entries are append-only.
--   - Membership point balances are cached.
--   - The loyalty ledger remains the source of truth.
--   - Point debits cannot create negative balances.
--   - Rewards are generic and industry-agnostic.
--   - Every business relationship is tenant validated.
-- =========================================================

-- =========================================================
-- ENUMS
-- =========================================================

do $$
begin
  create type public.loyalty_entry_direction as enum (
    'credit',
    'debit'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.loyalty_event_type as enum (
    'purchase',
    'reward_redemption',
    'referral',
    'birthday_bonus',
    'welcome_bonus',
    'anniversary_bonus',
    'tier_bonus',
    'promotion',
    'campaign_bonus',
    'manual_adjustment',
    'refund',
    'expiration',
    'reversal',
    'migration',
    'other'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.reward_kind as enum (
    'free_product',
    'fixed_discount',
    'percentage_discount',
    'bonus_points',
    'points_multiplier',
    'membership_benefit',
    'custom'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.reward_scope as enum (
    'transaction',
    'product',
    'category',
    'membership',
    'custom'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.reward_status as enum (
    'draft',
    'active',
    'inactive',
    'archived'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.reward_redemption_status as enum (
    'pending',
    'approved',
    'redeemed',
    'cancelled',
    'expired',
    'reversed'
  );
exception
  when duplicate_object then null;
end $$;

-- =========================================================
-- REWARDS
-- =========================================================

create table if not exists public.rewards (
  id uuid primary key default gen_random_uuid(),

  business_id uuid not null
    references public.businesses(id)
    on delete restrict,

  name text not null,
  description text,

  reward_kind public.reward_kind not null,
  reward_scope public.reward_scope not null,

  status public.reward_status not null default 'draft',

  product_id uuid
    references public.products(id)
    on delete set null,

  category_id uuid
    references public.product_categories(id)
    on delete set null,

  points_cost bigint not null default 0,

  fixed_discount_cents bigint,
  percentage_discount_basis_points integer,

  bonus_points bigint,
  points_multiplier_basis_points integer,

  maximum_discount_cents bigint,

  image_url text,

  display_order integer not null default 0,

  starts_at timestamptz,
  ends_at timestamptz,

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

  constraint rewards_name_not_blank
    check (length(trim(name)) > 0),

  constraint rewards_points_cost_nonnegative
    check (points_cost >= 0),

  constraint rewards_fixed_discount_nonnegative
    check (
      fixed_discount_cents is null
      or fixed_discount_cents >= 0
    ),

  constraint rewards_percentage_discount_check
    check (
      percentage_discount_basis_points is null
      or percentage_discount_basis_points between 1 and 10000
    ),

  constraint rewards_bonus_points_nonnegative
    check (
      bonus_points is null
      or bonus_points >= 0
    ),

  constraint rewards_points_multiplier_check
    check (
      points_multiplier_basis_points is null
      or points_multiplier_basis_points >= 10000
    ),

  constraint rewards_maximum_discount_nonnegative
    check (
      maximum_discount_cents is null
      or maximum_discount_cents >= 0
    ),

  constraint rewards_display_order_check
    check (display_order >= 0),

  constraint rewards_date_range_check
    check (
      starts_at is null
      or ends_at is null
      or ends_at >= starts_at
    ),

  constraint rewards_version_check
    check (version >= 1),

  constraint rewards_metadata_object_check
    check (jsonb_typeof(metadata) = 'object'),

  constraint rewards_scope_reference_check
    check (
      (
        reward_scope = 'product'
        and product_id is not null
        and category_id is null
      )
      or (
        reward_scope = 'category'
        and category_id is not null
        and product_id is null
      )
      or (
        reward_scope in (
          'transaction',
          'membership',
          'custom'
        )
        and product_id is null
        and category_id is null
      )
    ),

  constraint rewards_kind_value_check
    check (
      (
        reward_kind = 'free_product'
        and reward_scope = 'product'
        and product_id is not null
      )
      or (
        reward_kind = 'fixed_discount'
        and fixed_discount_cents is not null
      )
      or (
        reward_kind = 'percentage_discount'
        and percentage_discount_basis_points is not null
      )
      or (
        reward_kind = 'bonus_points'
        and bonus_points is not null
      )
      or (
        reward_kind = 'points_multiplier'
        and points_multiplier_basis_points is not null
      )
      or reward_kind in (
        'membership_benefit',
        'custom'
      )
    )
);

create index if not exists
  rewards_business_id_idx
on public.rewards (business_id)
where deleted_at is null;

create index if not exists
  rewards_business_status_idx
on public.rewards (
  business_id,
  status
)
where deleted_at is null;

create index if not exists
  rewards_business_catalog_idx
on public.rewards (
  business_id,
  status,
  display_order,
  name
)
where deleted_at is null;

create index if not exists
  rewards_product_id_idx
on public.rewards (product_id)
where product_id is not null
  and deleted_at is null;

create index if not exists
  rewards_category_id_idx
on public.rewards (category_id)
where category_id is not null
  and deleted_at is null;

-- =========================================================
-- REWARD RULES
-- =========================================================

create table if not exists public.reward_rules (
  id uuid primary key default gen_random_uuid(),

  business_id uuid not null
    references public.businesses(id)
    on delete restrict,

  reward_id uuid not null
    references public.rewards(id)
    on delete restrict,

  location_id uuid
    references public.business_locations(id)
    on delete set null,

  name text not null,

  is_active boolean not null default true,

  minimum_purchase_cents bigint not null default 0,

  maximum_redemptions_total bigint,
  maximum_redemptions_per_membership integer,

  cooldown_hours integer,

  valid_days smallint[] not null
    default array[0,1,2,3,4,5,6]::smallint[],

  valid_start_time time,
  valid_end_time time,

  starts_at timestamptz,
  ends_at timestamptz,

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

  constraint reward_rules_name_not_blank
    check (length(trim(name)) > 0),

  constraint reward_rules_minimum_purchase_check
    check (minimum_purchase_cents >= 0),

  constraint reward_rules_maximum_total_check
    check (
      maximum_redemptions_total is null
      or maximum_redemptions_total >= 1
    ),

  constraint reward_rules_maximum_member_check
    check (
      maximum_redemptions_per_membership is null
      or maximum_redemptions_per_membership >= 1
    ),

  constraint reward_rules_cooldown_check
    check (
      cooldown_hours is null
      or cooldown_hours >= 0
    ),

  constraint reward_rules_valid_days_check
    check (
      cardinality(valid_days) between 1 and 7
      and valid_days <@ array[0,1,2,3,4,5,6]::smallint[]
    ),

  constraint reward_rules_date_range_check
    check (
      starts_at is null
      or ends_at is null
      or ends_at >= starts_at
    ),

  constraint reward_rules_version_check
    check (version >= 1),

  constraint reward_rules_metadata_object_check
    check (jsonb_typeof(metadata) = 'object')
);

create index if not exists
  reward_rules_business_id_idx
on public.reward_rules (business_id)
where deleted_at is null;

create index if not exists
  reward_rules_reward_id_idx
on public.reward_rules (reward_id)
where deleted_at is null;

create index if not exists
  reward_rules_location_id_idx
on public.reward_rules (location_id)
where location_id is not null
  and deleted_at is null;

create index if not exists
  reward_rules_business_active_idx
on public.reward_rules (
  business_id,
  is_active
)
where deleted_at is null;

-- =========================================================
-- REWARD REDEMPTIONS
-- =========================================================

create table if not exists public.reward_redemptions (
  id uuid primary key default gen_random_uuid(),

  business_id uuid not null
    references public.businesses(id)
    on delete restrict,

  location_id uuid
    references public.business_locations(id)
    on delete set null,

  membership_id uuid not null
    references public.memberships(id)
    on delete restrict,

  reward_id uuid not null
    references public.rewards(id)
    on delete restrict,

  reward_rule_id uuid
    references public.reward_rules(id)
    on delete set null,

  transaction_id uuid
    references public.transactions(id)
    on delete set null,

  approved_by_employee_id uuid
    references public.employees(id)
    on delete set null,

  redeemed_by_employee_id uuid
    references public.employees(id)
    on delete set null,

  redemption_code_hash text,

  status public.reward_redemption_status
    not null default 'pending',

  reward_name_snapshot text not null,
  reward_kind_snapshot public.reward_kind not null,
  reward_scope_snapshot public.reward_scope not null,

  points_cost_snapshot bigint not null default 0,

  fixed_discount_cents_snapshot bigint,
  percentage_discount_basis_points_snapshot integer,
  bonus_points_snapshot bigint,

  requested_at timestamptz not null default now(),
  approved_at timestamptz,
  redeemed_at timestamptz,
  cancelled_at timestamptz,
  expires_at timestamptz,
  reversed_at timestamptz,

  notes text,

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

  constraint reward_redemptions_name_not_blank
    check (length(trim(reward_name_snapshot)) > 0),

  constraint reward_redemptions_points_cost_check
    check (points_cost_snapshot >= 0),

  constraint reward_redemptions_fixed_discount_check
    check (
      fixed_discount_cents_snapshot is null
      or fixed_discount_cents_snapshot >= 0
    ),

  constraint reward_redemptions_percentage_check
    check (
      percentage_discount_basis_points_snapshot is null
      or percentage_discount_basis_points_snapshot
        between 1 and 10000
    ),

  constraint reward_redemptions_bonus_points_check
    check (
      bonus_points_snapshot is null
      or bonus_points_snapshot >= 0
    ),

  constraint reward_redemptions_approval_time_check
    check (
      status <> 'approved'
      or approved_at is not null
    ),

  constraint reward_redemptions_redeemed_time_check
    check (
      status <> 'redeemed'
      or redeemed_at is not null
    ),

  constraint reward_redemptions_cancelled_time_check
    check (
      status <> 'cancelled'
      or cancelled_at is not null
    ),

  constraint reward_redemptions_reversed_time_check
    check (
      status <> 'reversed'
      or reversed_at is not null
    ),

  constraint reward_redemptions_expiration_check
    check (
      expires_at is null
      or expires_at >= requested_at
    ),

  constraint reward_redemptions_version_check
    check (version >= 1),

  constraint reward_redemptions_metadata_object_check
    check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists
  reward_redemptions_code_hash_unique
on public.reward_redemptions (
  business_id,
  redemption_code_hash
)
where redemption_code_hash is not null;

create index if not exists
  reward_redemptions_business_id_idx
on public.reward_redemptions (business_id);

create index if not exists
  reward_redemptions_membership_id_idx
on public.reward_redemptions (membership_id);

create index if not exists
  reward_redemptions_reward_id_idx
on public.reward_redemptions (reward_id);

create index if not exists
  reward_redemptions_transaction_id_idx
on public.reward_redemptions (transaction_id)
where transaction_id is not null;

create index if not exists
  reward_redemptions_business_status_idx
on public.reward_redemptions (
  business_id,
  status,
  requested_at desc
);

create index if not exists
  reward_redemptions_membership_history_idx
on public.reward_redemptions (
  membership_id,
  requested_at desc
);

-- =========================================================
-- LOYALTY LEDGER
-- =========================================================

create table if not exists public.loyalty_ledger (
  id uuid primary key default gen_random_uuid(),

  business_id uuid not null
    references public.businesses(id)
    on delete restrict,

  membership_id uuid not null
    references public.memberships(id)
    on delete restrict,

  location_id uuid
    references public.business_locations(id)
    on delete set null,

  transaction_id uuid
    references public.transactions(id)
    on delete set null,

  reward_redemption_id uuid
    references public.reward_redemptions(id)
    on delete set null,

  reversed_ledger_entry_id uuid
    references public.loyalty_ledger(id)
    on delete restrict,

  direction public.loyalty_entry_direction not null,
  event_type public.loyalty_event_type not null,

  points_amount bigint not null,

  balance_before bigint not null default 0,
  balance_after bigint not null default 0,

  idempotency_key text,

  external_source text,
  external_reference_id text,

  description text,

  occurred_at timestamptz not null default now(),
  expires_at timestamptz,

  metadata jsonb not null default '{}'::jsonb,

  created_by_employee_id uuid
    references public.employees(id)
    on delete set null,

  created_by uuid
    references auth.users(id)
    on delete set null,

  created_at timestamptz not null default now(),

  constraint loyalty_ledger_points_positive
    check (points_amount > 0),

  constraint loyalty_ledger_balances_nonnegative
    check (
      balance_before >= 0
      and balance_after >= 0
    ),

  constraint loyalty_ledger_expiration_check
    check (
      expires_at is null
      or expires_at >= occurred_at
    ),

  constraint loyalty_ledger_metadata_object_check
    check (jsonb_typeof(metadata) = 'object'),

  constraint loyalty_ledger_reversal_reference_check
    check (
      event_type <> 'reversal'
      or reversed_ledger_entry_id is not null
    )
);

create unique index if not exists
  loyalty_ledger_business_idempotency_unique
on public.loyalty_ledger (
  business_id,
  idempotency_key
)
where idempotency_key is not null;

create unique index if not exists
  loyalty_ledger_reversed_entry_unique
on public.loyalty_ledger (
  reversed_ledger_entry_id
)
where reversed_ledger_entry_id is not null;

create index if not exists
  loyalty_ledger_business_id_idx
on public.loyalty_ledger (business_id);

create index if not exists
  loyalty_ledger_membership_history_idx
on public.loyalty_ledger (
  membership_id,
  occurred_at desc,
  created_at desc
);

create index if not exists
  loyalty_ledger_business_event_idx
on public.loyalty_ledger (
  business_id,
  event_type,
  occurred_at desc
);

create index if not exists
  loyalty_ledger_transaction_id_idx
on public.loyalty_ledger (transaction_id)
where transaction_id is not null;

create index if not exists
  loyalty_ledger_redemption_id_idx
on public.loyalty_ledger (reward_redemption_id)
where reward_redemption_id is not null;

-- =========================================================
-- REWARD TENANT VALIDATION
-- =========================================================

create or replace function
  public.validate_reward_business_relationships()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.product_id is not null then
    if not exists (
      select 1
      from public.products p
      where p.id = new.product_id
        and p.business_id = new.business_id
        and p.deleted_at is null
    ) then
      raise exception
        'Reward product must belong to the same business.';
    end if;
  end if;

  if new.category_id is not null then
    if not exists (
      select 1
      from public.product_categories pc
      where pc.id = new.category_id
        and pc.business_id = new.business_id
        and pc.deleted_at is null
    ) then
      raise exception
        'Reward category must belong to the same business.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists
  rewards_validate_business_relationships
on public.rewards;

create trigger rewards_validate_business_relationships
before insert or update of
  business_id,
  product_id,
  category_id
on public.rewards
for each row
execute function
  public.validate_reward_business_relationships();

-- =========================================================
-- REWARD RULE TENANT VALIDATION
-- =========================================================

create or replace function
  public.validate_reward_rule_relationships()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.rewards r
    where r.id = new.reward_id
      and r.business_id = new.business_id
      and r.deleted_at is null
  ) then
    raise exception
      'Reward rule must belong to the same business as its reward.';
  end if;

  if new.location_id is not null then
    if not exists (
      select 1
      from public.business_locations bl
      where bl.id = new.location_id
        and bl.business_id = new.business_id
        and bl.deleted_at is null
    ) then
      raise exception
        'Reward rule location must belong to the same business.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists
  reward_rules_validate_relationships
on public.reward_rules;

create trigger reward_rules_validate_relationships
before insert or update of
  business_id,
  reward_id,
  location_id
on public.reward_rules
for each row
execute function
  public.validate_reward_rule_relationships();

-- =========================================================
-- REDEMPTION TENANT VALIDATION
-- =========================================================

create or replace function
  public.validate_reward_redemption_relationships()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.memberships m
    where m.id = new.membership_id
      and m.business_id = new.business_id
      and m.deleted_at is null
  ) then
    raise exception
      'Reward redemption membership must belong to the same business.';
  end if;

  if not exists (
    select 1
    from public.rewards r
    where r.id = new.reward_id
      and r.business_id = new.business_id
      and r.deleted_at is null
  ) then
    raise exception
      'Reward redemption reward must belong to the same business.';
  end if;

  if new.reward_rule_id is not null then
    if not exists (
      select 1
      from public.reward_rules rr
      where rr.id = new.reward_rule_id
        and rr.reward_id = new.reward_id
        and rr.business_id = new.business_id
        and rr.deleted_at is null
    ) then
      raise exception
        'Reward rule must belong to the same reward and business.';
    end if;
  end if;

  if new.location_id is not null then
    if not exists (
      select 1
      from public.business_locations bl
      where bl.id = new.location_id
        and bl.business_id = new.business_id
        and bl.deleted_at is null
    ) then
      raise exception
        'Reward redemption location must belong to the same business.';
    end if;
  end if;

  if new.transaction_id is not null then
    if not exists (
      select 1
      from public.transactions t
      where t.id = new.transaction_id
        and t.business_id = new.business_id
    ) then
      raise exception
        'Reward redemption transaction must belong to the same business.';
    end if;
  end if;

  if new.approved_by_employee_id is not null then
    if not exists (
      select 1
      from public.employees e
      where e.id = new.approved_by_employee_id
        and e.business_id = new.business_id
        and e.deleted_at is null
    ) then
      raise exception
        'Approving employee must belong to the same business.';
    end if;
  end if;

  if new.redeemed_by_employee_id is not null then
    if not exists (
      select 1
      from public.employees e
      where e.id = new.redeemed_by_employee_id
        and e.business_id = new.business_id
        and e.deleted_at is null
    ) then
      raise exception
        'Redeeming employee must belong to the same business.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists
  reward_redemptions_validate_relationships
on public.reward_redemptions;

create trigger reward_redemptions_validate_relationships
before insert or update of
  business_id,
  location_id,
  membership_id,
  reward_id,
  reward_rule_id,
  transaction_id,
  approved_by_employee_id,
  redeemed_by_employee_id
on public.reward_redemptions
for each row
execute function
  public.validate_reward_redemption_relationships();

-- =========================================================
-- LOYALTY LEDGER VALIDATION AND BALANCE SYNCHRONIZATION
-- =========================================================

create or replace function
  public.prepare_loyalty_ledger_entry()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  membership_record public.memberships%rowtype;
  calculated_balance bigint;
  reversed_entry public.loyalty_ledger%rowtype;
begin
  select *
  into membership_record
  from public.memberships m
  where m.id = new.membership_id
    and m.business_id = new.business_id
    and m.deleted_at is null
  for update;

  if not found then
    raise exception
      'Loyalty ledger membership must belong to the same business.';
  end if;

  if new.location_id is not null then
    if not exists (
      select 1
      from public.business_locations bl
      where bl.id = new.location_id
        and bl.business_id = new.business_id
        and bl.deleted_at is null
    ) then
      raise exception
        'Loyalty ledger location must belong to the same business.';
    end if;
  end if;

  if new.transaction_id is not null then
    if not exists (
      select 1
      from public.transactions t
      where t.id = new.transaction_id
        and t.business_id = new.business_id
        and (
          t.membership_id is null
          or t.membership_id = new.membership_id
        )
    ) then
      raise exception
        'Loyalty transaction must belong to the same business and membership.';
    end if;
  end if;

  if new.reward_redemption_id is not null then
    if not exists (
      select 1
      from public.reward_redemptions rr
      where rr.id = new.reward_redemption_id
        and rr.business_id = new.business_id
        and rr.membership_id = new.membership_id
    ) then
      raise exception
        'Reward redemption must belong to the same business and membership.';
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
        'Ledger employee must belong to the same business.';
    end if;
  end if;

  if new.reversed_ledger_entry_id is not null then
    select *
    into reversed_entry
    from public.loyalty_ledger ll
    where ll.id = new.reversed_ledger_entry_id
      and ll.business_id = new.business_id
      and ll.membership_id = new.membership_id;

    if not found then
      raise exception
        'Reversed ledger entry must belong to the same business and membership.';
    end if;

    if new.event_type <> 'reversal' then
      raise exception
        'A reversed ledger reference requires the reversal event type.';
    end if;

    if new.direction = reversed_entry.direction then
      raise exception
        'A reversal must use the opposite direction of the original entry.';
    end if;

    if new.points_amount <> reversed_entry.points_amount then
      raise exception
        'A reversal must use the same point amount as the original entry.';
    end if;
  end if;

  new.balance_before := membership_record.current_points_balance;

  if new.direction = 'credit' then
    calculated_balance :=
      membership_record.current_points_balance
      + new.points_amount;
  else
    calculated_balance :=
      membership_record.current_points_balance
      - new.points_amount;
  end if;

  if calculated_balance < 0 then
    raise exception
      'Insufficient loyalty points. Available: %, requested debit: %.',
      membership_record.current_points_balance,
      new.points_amount;
  end if;

  new.balance_after := calculated_balance;

  return new;
end;
$$;

create or replace function
  public.apply_loyalty_ledger_entry()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.memberships
  set
    current_points_balance = new.balance_after,

    lifetime_points_earned =
      lifetime_points_earned
      + case
          when new.direction = 'credit'
          then new.points_amount
          else 0
        end,

    lifetime_points_redeemed =
      lifetime_points_redeemed
      + case
          when new.direction = 'debit'
            and new.event_type = 'reward_redemption'
          then new.points_amount
          else 0
        end,

    last_activity_at = greatest(
      coalesce(last_activity_at, new.occurred_at),
      new.occurred_at
    ),

    updated_at = now()

  where id = new.membership_id
    and business_id = new.business_id;

  return new;
end;
$$;

drop trigger if exists
  loyalty_ledger_prepare_entry
on public.loyalty_ledger;

create trigger loyalty_ledger_prepare_entry
before insert on public.loyalty_ledger
for each row
execute function public.prepare_loyalty_ledger_entry();

drop trigger if exists
  loyalty_ledger_apply_entry
on public.loyalty_ledger;

create trigger loyalty_ledger_apply_entry
after insert on public.loyalty_ledger
for each row
execute function public.apply_loyalty_ledger_entry();

-- =========================================================
-- APPEND-ONLY LEDGER PROTECTION
-- =========================================================

create or replace function
  public.prevent_loyalty_ledger_mutation()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  raise exception
    'Loyalty ledger entries are immutable. Create a reversal entry instead.';
end;
$$;

drop trigger if exists
  loyalty_ledger_prevent_update
on public.loyalty_ledger;

create trigger loyalty_ledger_prevent_update
before update on public.loyalty_ledger
for each row
execute function public.prevent_loyalty_ledger_mutation();

drop trigger if exists
  loyalty_ledger_prevent_delete
on public.loyalty_ledger;

create trigger loyalty_ledger_prevent_delete
before delete on public.loyalty_ledger
for each row
execute function public.prevent_loyalty_ledger_mutation();

-- =========================================================
-- PREVENT TENANT TRANSFERS
-- =========================================================

drop trigger if exists
  rewards_prevent_business_change
on public.rewards;

create trigger rewards_prevent_business_change
before update of business_id
on public.rewards
for each row
execute function public.prevent_business_id_change();

drop trigger if exists
  reward_rules_prevent_business_change
on public.reward_rules;

create trigger reward_rules_prevent_business_change
before update of business_id
on public.reward_rules
for each row
execute function public.prevent_business_id_change();

drop trigger if exists
  reward_redemptions_prevent_business_change
on public.reward_redemptions;

create trigger reward_redemptions_prevent_business_change
before update of business_id
on public.reward_redemptions
for each row
execute function public.prevent_business_id_change();

-- =========================================================
-- VERSION AND UPDATED-AT MANAGEMENT
-- =========================================================

drop trigger if exists
  rewards_increment_version
on public.rewards;

create trigger rewards_increment_version
before update on public.rewards
for each row
execute function public.increment_record_version();

drop trigger if exists
  reward_rules_increment_version
on public.reward_rules;

create trigger reward_rules_increment_version
before update on public.reward_rules
for each row
execute function public.increment_record_version();

drop trigger if exists
  reward_redemptions_increment_version
on public.reward_redemptions;

create trigger reward_redemptions_increment_version
before update on public.reward_redemptions
for each row
execute function public.increment_record_version();

drop trigger if exists
  rewards_set_updated_at
on public.rewards;

create trigger rewards_set_updated_at
before update on public.rewards
for each row
execute function public.set_updated_at();

drop trigger if exists
  reward_rules_set_updated_at
on public.reward_rules;

create trigger reward_rules_set_updated_at
before update on public.reward_rules
for each row
execute function public.set_updated_at();

drop trigger if exists
  reward_redemptions_set_updated_at
on public.reward_redemptions;

create trigger reward_redemptions_set_updated_at
before update on public.reward_redemptions
for each row
execute function public.set_updated_at();

-- =========================================================
-- ROW LEVEL SECURITY
-- No public policies are added yet.
-- Access remains denied by default.
-- =========================================================

alter table public.rewards
  enable row level security;

alter table public.rewards
  force row level security;

alter table public.reward_rules
  enable row level security;

alter table public.reward_rules
  force row level security;

alter table public.reward_redemptions
  enable row level security;

alter table public.reward_redemptions
  force row level security;

alter table public.loyalty_ledger
  enable row level security;

alter table public.loyalty_ledger
  force row level security;

-- =========================================================
-- COMMENTS
-- =========================================================

comment on table public.rewards is
  'Business-owned catalog of configurable, industry-agnostic loyalty rewards.';

comment on table public.reward_rules is
  'Eligibility, timing, location, purchase, frequency, and usage restrictions for rewards.';

comment on table public.reward_redemptions is
  'Auditable lifecycle and historical snapshot of each membership reward redemption.';

comment on table public.loyalty_ledger is
  'Append-only source of truth for every loyalty point credit and debit.';

comment on column public.rewards.points_multiplier_basis_points is
  'Points multiplier represented in basis points. Example: 20000 represents 2.00x points.';

comment on column public.loyalty_ledger.balance_before is
  'Membership cached point balance immediately before this immutable ledger entry.';

comment on column public.loyalty_ledger.balance_after is
  'Membership cached point balance immediately after this immutable ledger entry.';

comment on column public.loyalty_ledger.idempotency_key is
  'Optional business-scoped key used to prevent duplicate point events from retries or integrations.';

comment on function public.prepare_loyalty_ledger_entry() is
  'Locks the membership, validates tenant relationships, prevents negative balances, and calculates point balances.';

comment on function public.apply_loyalty_ledger_entry() is
  'Synchronizes membership cached loyalty totals after an immutable ledger entry is created.';

comment on function public.prevent_loyalty_ledger_mutation() is
  'Prevents updates and deletes of loyalty ledger history. Corrections require reversal entries.';
