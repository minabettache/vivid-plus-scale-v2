-- =========================================================
-- VIVID+ MIGRATION 012
-- ENTERPRISE ACCOUNTING CORE
-- Double-entry general ledger, fiscal periods, chart of
-- accounts, AP, AR, banking, expenses, reconciliation,
-- financial reporting functions, and POS posting RPC.
-- =========================================================

begin;

-- =========================================================
-- ENUMS
-- =========================================================

do $$ begin
  create type public.accounting_account_type as enum (
    'asset','liability','equity','revenue','expense'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.accounting_normal_balance as enum ('debit','credit');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.accounting_period_status as enum ('open','soft_closed','closed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.accounting_journal_status as enum (
    'draft','posted','reversed','voided'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.accounting_source_type as enum (
    'manual','pos_sale','pos_refund','vendor_bill','vendor_payment',
    'customer_invoice','customer_payment','expense','bank','inventory',
    'loyalty','opening_balance','period_close','reversal'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.ap_document_status as enum (
    'draft','submitted','approved','partially_paid','paid','voided'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.ar_document_status as enum (
    'draft','issued','partially_paid','paid','overdue','voided'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.bank_transaction_type as enum (
    'deposit','withdrawal','transfer_in','transfer_out','fee','interest','adjustment'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.reconciliation_status as enum (
    'draft','in_progress','completed','voided'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.expense_claim_status as enum (
    'draft','submitted','approved','rejected','reimbursed','voided'
  );
exception when duplicate_object then null; end $$;

-- =========================================================
-- PERMISSIONS
-- =========================================================

insert into public.permissions (code, module, description, is_sensitive)
values
  ('accounting.read',          'accounting', 'View accounting records and financial reports.', true),
  ('accounting.manage',        'accounting', 'Manage accounts, periods, journals, and accounting settings.', true),
  ('accounting.post',          'accounting', 'Post balanced journal entries to the general ledger.', true),
  ('accounting.close_period',  'accounting', 'Soft-close, close, and reopen fiscal periods.', true),
  ('accounting.ap_read',       'accounting', 'View vendors, bills, and accounts payable.', true),
  ('accounting.ap_manage',     'accounting', 'Manage vendors, bills, and vendor payments.', true),
  ('accounting.ar_read',       'accounting', 'View customer invoices and accounts receivable.', true),
  ('accounting.ar_manage',     'accounting', 'Manage customer invoices, payments, and credits.', true),
  ('accounting.bank_read',     'accounting', 'View bank accounts, transactions, and reconciliations.', true),
  ('accounting.bank_manage',   'accounting', 'Manage bank transactions, transfers, and reconciliations.', true),
  ('accounting.expense_read',  'accounting', 'View expense claims and categories.', true),
  ('accounting.expense_manage','accounting', 'Manage, approve, and reimburse expense claims.', true),
  ('accounting.export',        'accounting', 'Export accounting and financial report data.', true)
on conflict ((lower(code))) do update
set module = excluded.module,
    description = excluded.description,
    is_sensitive = excluded.is_sensitive;

-- =========================================================
-- FISCAL PERIODS
-- =========================================================

create table if not exists public.accounting_periods (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  code text not null,
  name text not null,
  starts_on date not null,
  ends_on date not null,
  status public.accounting_period_status not null default 'open',
  soft_closed_at timestamptz,
  soft_closed_by uuid references auth.users(id) on delete set null,
  closed_at timestamptz,
  closed_by uuid references auth.users(id) on delete set null,
  reopened_at timestamptz,
  reopened_by uuid references auth.users(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint accounting_periods_code_not_blank check (length(trim(code)) > 0),
  constraint accounting_periods_name_not_blank check (length(trim(name)) > 0),
  constraint accounting_periods_dates_check check (ends_on >= starts_on),
  constraint accounting_periods_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint accounting_periods_version_positive check (version >= 1)
);

create unique index if not exists accounting_periods_business_code_uq
  on public.accounting_periods (business_id, lower(code))
  where deleted_at is null;

create unique index if not exists accounting_periods_business_dates_uq
  on public.accounting_periods (business_id, starts_on, ends_on)
  where deleted_at is null;

create index if not exists accounting_periods_lookup_idx
  on public.accounting_periods (business_id, starts_on, ends_on, status)
  where deleted_at is null;

create or replace function public.prevent_overlapping_accounting_periods()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if exists (
    select 1
    from public.accounting_periods p
    where p.business_id = new.business_id
      and p.id <> coalesce(new.id, gen_random_uuid())
      and p.deleted_at is null
      and daterange(p.starts_on, p.ends_on, '[]')
          && daterange(new.starts_on, new.ends_on, '[]')
  ) then
    raise exception 'Accounting periods may not overlap.';
  end if;
  return new;
end;
$$;

drop trigger if exists accounting_periods_prevent_overlap on public.accounting_periods;
create trigger accounting_periods_prevent_overlap
before insert or update of business_id, starts_on, ends_on, deleted_at
on public.accounting_periods
for each row execute function public.prevent_overlapping_accounting_periods();

-- =========================================================
-- CHART OF ACCOUNTS
-- =========================================================

create table if not exists public.accounting_accounts (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  parent_account_id uuid references public.accounting_accounts(id) on delete restrict,
  code text not null,
  name text not null,
  description text,
  account_type public.accounting_account_type not null,
  normal_balance public.accounting_normal_balance not null,
  currency_code char(3) not null default 'USD',
  is_control_account boolean not null default false,
  allow_manual_posting boolean not null default true,
  is_active boolean not null default true,
  system_key text,
  display_order integer not null default 100,
  metadata jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint accounting_accounts_code_not_blank check (length(trim(code)) > 0),
  constraint accounting_accounts_name_not_blank check (length(trim(name)) > 0),
  constraint accounting_accounts_currency_upper check (currency_code::text = upper(currency_code::text)),
  constraint accounting_accounts_display_nonnegative check (display_order >= 0),
  constraint accounting_accounts_system_key_not_blank check (system_key is null or length(trim(system_key)) > 0),
  constraint accounting_accounts_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint accounting_accounts_version_positive check (version >= 1),
  constraint accounting_accounts_normal_balance_check check (
    (account_type in ('asset','expense') and normal_balance = 'debit')
    or (account_type in ('liability','equity','revenue') and normal_balance = 'credit')
  )
);

create unique index if not exists accounting_accounts_business_code_uq
  on public.accounting_accounts (business_id, lower(code))
  where deleted_at is null;

create unique index if not exists accounting_accounts_business_system_key_uq
  on public.accounting_accounts (business_id, lower(system_key))
  where system_key is not null and deleted_at is null;

create index if not exists accounting_accounts_tree_idx
  on public.accounting_accounts (business_id, parent_account_id, display_order, code)
  where deleted_at is null;

create or replace function public.validate_accounting_account_parent()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.parent_account_id is null then
    return new;
  end if;

  if new.parent_account_id = new.id then
    raise exception 'An account cannot be its own parent.';
  end if;

  if not exists (
    select 1 from public.accounting_accounts p
    where p.id = new.parent_account_id
      and p.business_id = new.business_id
      and p.deleted_at is null
  ) then
    raise exception 'Parent account must belong to the same business.';
  end if;

  return new;
end;
$$;

drop trigger if exists accounting_accounts_validate_parent on public.accounting_accounts;
create trigger accounting_accounts_validate_parent
before insert or update on public.accounting_accounts
for each row execute function public.validate_accounting_account_parent();

-- =========================================================
-- JOURNAL ENTRIES AND LINES
-- =========================================================

create table if not exists public.accounting_journal_entries (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  location_id uuid references public.business_locations(id) on delete set null,
  period_id uuid not null references public.accounting_periods(id) on delete restrict,
  journal_number text not null,
  entry_date date not null,
  description text not null,
  source_type public.accounting_source_type not null default 'manual',
  source_id uuid,
  source_reference text,
  idempotency_key text,
  currency_code char(3) not null default 'USD',
  status public.accounting_journal_status not null default 'draft',
  total_debit_cents bigint not null default 0,
  total_credit_cents bigint not null default 0,
  posted_at timestamptz,
  posted_by uuid references auth.users(id) on delete set null,
  reversal_of_entry_id uuid references public.accounting_journal_entries(id) on delete restrict,
  reversed_by_entry_id uuid references public.accounting_journal_entries(id) on delete restrict,
  reversed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint accounting_journal_number_not_blank check (length(trim(journal_number)) > 0),
  constraint accounting_journal_description_not_blank check (length(trim(description)) > 0),
  constraint accounting_journal_currency_upper check (currency_code::text = upper(currency_code::text)),
  constraint accounting_journal_totals_nonnegative check (
    total_debit_cents >= 0 and total_credit_cents >= 0
  ),
  constraint accounting_journal_posted_balance check (
    status <> 'posted' or (
      total_debit_cents > 0
      and total_debit_cents = total_credit_cents
      and posted_at is not null
    )
  ),
  constraint accounting_journal_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint accounting_journal_version_positive check (version >= 1),
  constraint accounting_journal_reversal_not_self check (
    reversal_of_entry_id is null or reversal_of_entry_id <> id
  )
);

create unique index if not exists accounting_journal_business_number_uq
  on public.accounting_journal_entries (business_id, lower(journal_number));

create unique index if not exists accounting_journal_idempotency_uq
  on public.accounting_journal_entries (business_id, idempotency_key)
  where idempotency_key is not null;

create unique index if not exists accounting_journal_source_uq
  on public.accounting_journal_entries (business_id, source_type, source_id)
  where source_id is not null and status <> 'voided';

create index if not exists accounting_journal_period_date_idx
  on public.accounting_journal_entries (business_id, period_id, entry_date, status);

create table if not exists public.accounting_journal_lines (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  journal_entry_id uuid not null references public.accounting_journal_entries(id) on delete restrict,
  account_id uuid not null references public.accounting_accounts(id) on delete restrict,
  location_id uuid references public.business_locations(id) on delete set null,
  line_number integer not null,
  description text,
  debit_cents bigint not null default 0,
  credit_cents bigint not null default 0,
  customer_id uuid references public.customers(id) on delete set null,
  membership_id uuid references public.memberships(id) on delete set null,
  vendor_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint accounting_journal_lines_number_positive check (line_number >= 1),
  constraint accounting_journal_lines_amount_nonnegative check (debit_cents >= 0 and credit_cents >= 0),
  constraint accounting_journal_lines_one_side check (
    (debit_cents > 0 and credit_cents = 0)
    or (credit_cents > 0 and debit_cents = 0)
  ),
  constraint accounting_journal_lines_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists accounting_journal_lines_number_uq
  on public.accounting_journal_lines (journal_entry_id, line_number);

create index if not exists accounting_journal_lines_account_idx
  on public.accounting_journal_lines (business_id, account_id, journal_entry_id);

-- =========================================================
-- VENDORS
-- =========================================================

create table if not exists public.accounting_vendors (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  code text not null,
  legal_name text not null,
  display_name text,
  email text,
  phone text,
  website text,
  tax_id_masked text,
  default_expense_account_id uuid references public.accounting_accounts(id) on delete set null,
  accounts_payable_account_id uuid references public.accounting_accounts(id) on delete set null,
  payment_terms_days integer not null default 30,
  currency_code char(3) not null default 'USD',
  billing_address jsonb not null default '{}'::jsonb,
  remittance_address jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint accounting_vendors_code_not_blank check (length(trim(code)) > 0),
  constraint accounting_vendors_name_not_blank check (length(trim(legal_name)) > 0),
  constraint accounting_vendors_terms_nonnegative check (payment_terms_days >= 0),
  constraint accounting_vendors_currency_upper check (currency_code::text = upper(currency_code::text)),
  constraint accounting_vendors_billing_object check (jsonb_typeof(billing_address) = 'object'),
  constraint accounting_vendors_remittance_object check (jsonb_typeof(remittance_address) = 'object'),
  constraint accounting_vendors_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint accounting_vendors_version_positive check (version >= 1)
);

create unique index if not exists accounting_vendors_business_code_uq
  on public.accounting_vendors (business_id, lower(code))
  where deleted_at is null;

alter table public.accounting_journal_lines
  drop constraint if exists accounting_journal_lines_vendor_id_fkey;
alter table public.accounting_journal_lines
  add constraint accounting_journal_lines_vendor_id_fkey
  foreign key (vendor_id) references public.accounting_vendors(id) on delete set null;

-- =========================================================
-- ACCOUNTS PAYABLE
-- =========================================================

create table if not exists public.vendor_bills (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  location_id uuid references public.business_locations(id) on delete set null,
  vendor_id uuid not null references public.accounting_vendors(id) on delete restrict,
  accounts_payable_account_id uuid not null references public.accounting_accounts(id) on delete restrict,
  bill_number text not null,
  vendor_invoice_number text,
  bill_date date not null,
  due_date date not null,
  currency_code char(3) not null default 'USD',
  subtotal_cents bigint not null default 0,
  tax_cents bigint not null default 0,
  total_cents bigint not null default 0,
  paid_cents bigint not null default 0,
  status public.ap_document_status not null default 'draft',
  journal_entry_id uuid references public.accounting_journal_entries(id) on delete set null,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint vendor_bills_number_not_blank check (length(trim(bill_number)) > 0),
  constraint vendor_bills_dates_check check (due_date >= bill_date),
  constraint vendor_bills_currency_upper check (currency_code::text = upper(currency_code::text)),
  constraint vendor_bills_amounts_nonnegative check (
    subtotal_cents >= 0 and tax_cents >= 0 and total_cents >= 0 and paid_cents >= 0
  ),
  constraint vendor_bills_total_math check (total_cents = subtotal_cents + tax_cents),
  constraint vendor_bills_paid_limit check (paid_cents <= total_cents),
  constraint vendor_bills_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint vendor_bills_version_positive check (version >= 1)
);

create unique index if not exists vendor_bills_business_number_uq
  on public.vendor_bills (business_id, lower(bill_number))
  where deleted_at is null;

create index if not exists vendor_bills_aging_idx
  on public.vendor_bills (business_id, vendor_id, status, due_date)
  where deleted_at is null;

create table if not exists public.vendor_bill_lines (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  vendor_bill_id uuid not null references public.vendor_bills(id) on delete cascade,
  line_number integer not null,
  expense_account_id uuid not null references public.accounting_accounts(id) on delete restrict,
  description text not null,
  quantity numeric(18,4) not null default 1,
  unit_cost_cents bigint not null default 0,
  subtotal_cents bigint not null default 0,
  tax_cents bigint not null default 0,
  total_cents bigint not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint vendor_bill_lines_number_positive check (line_number >= 1),
  constraint vendor_bill_lines_description_not_blank check (length(trim(description)) > 0),
  constraint vendor_bill_lines_quantity_positive check (quantity > 0),
  constraint vendor_bill_lines_amounts_nonnegative check (
    unit_cost_cents >= 0 and subtotal_cents >= 0 and tax_cents >= 0 and total_cents >= 0
  ),
  constraint vendor_bill_lines_total_math check (total_cents = subtotal_cents + tax_cents),
  constraint vendor_bill_lines_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists vendor_bill_lines_number_uq
  on public.vendor_bill_lines (vendor_bill_id, line_number);

-- =========================================================
-- BANKING
-- =========================================================

create table if not exists public.accounting_bank_accounts (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  location_id uuid references public.business_locations(id) on delete set null,
  ledger_account_id uuid not null references public.accounting_accounts(id) on delete restrict,
  code text not null,
  name text not null,
  institution_name text,
  account_mask text,
  routing_mask text,
  currency_code char(3) not null default 'USD',
  opening_balance_cents bigint not null default 0,
  opening_balance_date date,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint accounting_bank_accounts_code_not_blank check (length(trim(code)) > 0),
  constraint accounting_bank_accounts_name_not_blank check (length(trim(name)) > 0),
  constraint accounting_bank_accounts_currency_upper check (currency_code::text = upper(currency_code::text)),
  constraint accounting_bank_accounts_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint accounting_bank_accounts_version_positive check (version >= 1)
);

create unique index if not exists accounting_bank_accounts_business_code_uq
  on public.accounting_bank_accounts (business_id, lower(code))
  where deleted_at is null;

create table if not exists public.accounting_bank_transactions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  bank_account_id uuid not null references public.accounting_bank_accounts(id) on delete restrict,
  location_id uuid references public.business_locations(id) on delete set null,
  transaction_type public.bank_transaction_type not null,
  transaction_date date not null,
  amount_cents bigint not null,
  description text not null,
  external_id text,
  idempotency_key text,
  journal_entry_id uuid references public.accounting_journal_entries(id) on delete set null,
  is_cleared boolean not null default false,
  cleared_at timestamptz,
  reconciled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint accounting_bank_transactions_amount_positive check (amount_cents > 0),
  constraint accounting_bank_transactions_description_not_blank check (length(trim(description)) > 0),
  constraint accounting_bank_transactions_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists accounting_bank_transactions_idempotency_uq
  on public.accounting_bank_transactions (business_id, idempotency_key)
  where idempotency_key is not null;

create index if not exists accounting_bank_transactions_account_date_idx
  on public.accounting_bank_transactions (bank_account_id, transaction_date, is_cleared);

create table if not exists public.bank_reconciliations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  bank_account_id uuid not null references public.accounting_bank_accounts(id) on delete restrict,
  period_id uuid references public.accounting_periods(id) on delete restrict,
  statement_start_date date not null,
  statement_end_date date not null,
  opening_balance_cents bigint not null,
  closing_balance_cents bigint not null,
  cleared_balance_cents bigint not null default 0,
  difference_cents bigint not null default 0,
  status public.reconciliation_status not null default 'draft',
  completed_at timestamptz,
  completed_by uuid references auth.users(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint bank_reconciliations_dates_check check (statement_end_date >= statement_start_date),
  constraint bank_reconciliations_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint bank_reconciliations_version_positive check (version >= 1),
  constraint bank_reconciliations_completed_check check (
    status <> 'completed' or (completed_at is not null and difference_cents = 0)
  )
);

create unique index if not exists bank_reconciliations_account_period_uq
  on public.bank_reconciliations (bank_account_id, statement_start_date, statement_end_date)
  where deleted_at is null;

create table if not exists public.bank_reconciliation_items (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  reconciliation_id uuid not null references public.bank_reconciliations(id) on delete cascade,
  bank_transaction_id uuid not null references public.accounting_bank_transactions(id) on delete restrict,
  cleared_amount_cents bigint not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint bank_reconciliation_items_amount_positive check (cleared_amount_cents > 0)
);

create unique index if not exists bank_reconciliation_items_transaction_uq
  on public.bank_reconciliation_items (reconciliation_id, bank_transaction_id);

-- =========================================================
-- ACCOUNTS RECEIVABLE
-- =========================================================

create table if not exists public.customer_invoices (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  location_id uuid references public.business_locations(id) on delete set null,
  customer_id uuid not null references public.customers(id) on delete restrict,
  membership_id uuid references public.memberships(id) on delete set null,
  accounts_receivable_account_id uuid not null references public.accounting_accounts(id) on delete restrict,
  invoice_number text not null,
  invoice_date date not null,
  due_date date not null,
  currency_code char(3) not null default 'USD',
  subtotal_cents bigint not null default 0,
  tax_cents bigint not null default 0,
  total_cents bigint not null default 0,
  paid_cents bigint not null default 0,
  status public.ar_document_status not null default 'draft',
  journal_entry_id uuid references public.accounting_journal_entries(id) on delete set null,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint customer_invoices_number_not_blank check (length(trim(invoice_number)) > 0),
  constraint customer_invoices_dates_check check (due_date >= invoice_date),
  constraint customer_invoices_currency_upper check (currency_code::text = upper(currency_code::text)),
  constraint customer_invoices_amounts_nonnegative check (
    subtotal_cents >= 0 and tax_cents >= 0 and total_cents >= 0 and paid_cents >= 0
  ),
  constraint customer_invoices_total_math check (total_cents = subtotal_cents + tax_cents),
  constraint customer_invoices_paid_limit check (paid_cents <= total_cents),
  constraint customer_invoices_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint customer_invoices_version_positive check (version >= 1)
);

create unique index if not exists customer_invoices_business_number_uq
  on public.customer_invoices (business_id, lower(invoice_number))
  where deleted_at is null;

create index if not exists customer_invoices_aging_idx
  on public.customer_invoices (business_id, customer_id, status, due_date)
  where deleted_at is null;

create table if not exists public.customer_invoice_lines (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  customer_invoice_id uuid not null references public.customer_invoices(id) on delete cascade,
  line_number integer not null,
  revenue_account_id uuid not null references public.accounting_accounts(id) on delete restrict,
  description text not null,
  quantity numeric(18,4) not null default 1,
  unit_price_cents bigint not null default 0,
  subtotal_cents bigint not null default 0,
  tax_cents bigint not null default 0,
  total_cents bigint not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint customer_invoice_lines_number_positive check (line_number >= 1),
  constraint customer_invoice_lines_description_not_blank check (length(trim(description)) > 0),
  constraint customer_invoice_lines_quantity_positive check (quantity > 0),
  constraint customer_invoice_lines_amounts_nonnegative check (
    unit_price_cents >= 0 and subtotal_cents >= 0 and tax_cents >= 0 and total_cents >= 0
  ),
  constraint customer_invoice_lines_total_math check (total_cents = subtotal_cents + tax_cents),
  constraint customer_invoice_lines_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists customer_invoice_lines_number_uq
  on public.customer_invoice_lines (customer_invoice_id, line_number);

-- =========================================================
-- PAYMENTS
-- =========================================================

create table if not exists public.vendor_payments (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  vendor_id uuid not null references public.accounting_vendors(id) on delete restrict,
  bank_account_id uuid references public.accounting_bank_accounts(id) on delete set null,
  payment_number text not null,
  payment_date date not null,
  amount_cents bigint not null,
  currency_code char(3) not null default 'USD',
  journal_entry_id uuid references public.accounting_journal_entries(id) on delete set null,
  reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint vendor_payments_number_not_blank check (length(trim(payment_number)) > 0),
  constraint vendor_payments_amount_positive check (amount_cents > 0),
  constraint vendor_payments_currency_upper check (currency_code::text = upper(currency_code::text)),
  constraint vendor_payments_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists vendor_payments_business_number_uq
  on public.vendor_payments (business_id, lower(payment_number));

create table if not exists public.vendor_payment_allocations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  vendor_payment_id uuid not null references public.vendor_payments(id) on delete cascade,
  vendor_bill_id uuid not null references public.vendor_bills(id) on delete restrict,
  amount_cents bigint not null,
  created_at timestamptz not null default now(),
  constraint vendor_payment_allocations_amount_positive check (amount_cents > 0)
);

create unique index if not exists vendor_payment_allocations_bill_uq
  on public.vendor_payment_allocations (vendor_payment_id, vendor_bill_id);

create table if not exists public.customer_payments (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  customer_id uuid not null references public.customers(id) on delete restrict,
  membership_id uuid references public.memberships(id) on delete set null,
  bank_account_id uuid references public.accounting_bank_accounts(id) on delete set null,
  payment_number text not null,
  payment_date date not null,
  amount_cents bigint not null,
  currency_code char(3) not null default 'USD',
  journal_entry_id uuid references public.accounting_journal_entries(id) on delete set null,
  reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint customer_payments_number_not_blank check (length(trim(payment_number)) > 0),
  constraint customer_payments_amount_positive check (amount_cents > 0),
  constraint customer_payments_currency_upper check (currency_code::text = upper(currency_code::text)),
  constraint customer_payments_metadata_object check (jsonb_typeof(metadata) = 'object')
);

create unique index if not exists customer_payments_business_number_uq
  on public.customer_payments (business_id, lower(payment_number));

create table if not exists public.customer_payment_allocations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  customer_payment_id uuid not null references public.customer_payments(id) on delete cascade,
  customer_invoice_id uuid not null references public.customer_invoices(id) on delete restrict,
  amount_cents bigint not null,
  created_at timestamptz not null default now(),
  constraint customer_payment_allocations_amount_positive check (amount_cents > 0)
);

create unique index if not exists customer_payment_allocations_invoice_uq
  on public.customer_payment_allocations (customer_payment_id, customer_invoice_id);

-- =========================================================
-- EXPENSES
-- =========================================================

create table if not exists public.expense_categories (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  expense_account_id uuid not null references public.accounting_accounts(id) on delete restrict,
  code text not null,
  name text not null,
  description text,
  requires_receipt boolean not null default false,
  requires_approval boolean not null default true,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint expense_categories_code_not_blank check (length(trim(code)) > 0),
  constraint expense_categories_name_not_blank check (length(trim(name)) > 0),
  constraint expense_categories_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint expense_categories_version_positive check (version >= 1)
);

create unique index if not exists expense_categories_business_code_uq
  on public.expense_categories (business_id, lower(code))
  where deleted_at is null;

create table if not exists public.expense_claims (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  location_id uuid references public.business_locations(id) on delete set null,
  employee_id uuid not null references public.employees(id) on delete restrict,
  expense_category_id uuid not null references public.expense_categories(id) on delete restrict,
  claim_number text not null,
  expense_date date not null,
  merchant_name text,
  description text not null,
  amount_cents bigint not null,
  tax_cents bigint not null default 0,
  currency_code char(3) not null default 'USD',
  status public.expense_claim_status not null default 'draft',
  receipt_url text,
  journal_entry_id uuid references public.accounting_journal_entries(id) on delete set null,
  submitted_at timestamptz,
  approved_at timestamptz,
  approved_by uuid references auth.users(id) on delete set null,
  rejected_at timestamptz,
  rejected_by uuid references auth.users(id) on delete set null,
  rejection_reason text,
  reimbursed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint expense_claims_number_not_blank check (length(trim(claim_number)) > 0),
  constraint expense_claims_description_not_blank check (length(trim(description)) > 0),
  constraint expense_claims_amount_positive check (amount_cents > 0),
  constraint expense_claims_tax_nonnegative check (tax_cents >= 0),
  constraint expense_claims_currency_upper check (currency_code::text = upper(currency_code::text)),
  constraint expense_claims_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint expense_claims_version_positive check (version >= 1)
);

create unique index if not exists expense_claims_business_number_uq
  on public.expense_claims (business_id, lower(claim_number))
  where deleted_at is null;

create index if not exists expense_claims_workflow_idx
  on public.expense_claims (business_id, status, expense_date)
  where deleted_at is null;

-- =========================================================
-- TENANT VALIDATION
-- =========================================================

create or replace function public.validate_accounting_journal_entry()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.accounting_periods p
    where p.id = new.period_id
      and p.business_id = new.business_id
      and p.deleted_at is null
      and new.entry_date between p.starts_on and p.ends_on
  ) then
    raise exception 'Journal period must belong to the business and contain the entry date.';
  end if;

  if new.location_id is not null and not exists (
    select 1 from public.business_locations l
    where l.id = new.location_id
      and l.business_id = new.business_id
      and l.deleted_at is null
  ) then
    raise exception 'Journal location must belong to the same business.';
  end if;

  return new;
end;
$$;

create or replace function public.validate_accounting_journal_line()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_entry_business uuid;
  v_entry_status public.accounting_journal_status;
begin
  select business_id, status
    into v_entry_business, v_entry_status
  from public.accounting_journal_entries
  where id = new.journal_entry_id;

  if v_entry_business is null or v_entry_business <> new.business_id then
    raise exception 'Journal line and entry must belong to the same business.';
  end if;

  if v_entry_status <> 'draft' then
    raise exception 'Lines can only be changed while a journal is draft.';
  end if;

  if not exists (
    select 1 from public.accounting_accounts a
    where a.id = new.account_id
      and a.business_id = new.business_id
      and a.deleted_at is null
      and a.is_active
  ) then
    raise exception 'Journal account must be active and belong to the same business.';
  end if;

  if new.location_id is not null and not exists (
    select 1 from public.business_locations l
    where l.id = new.location_id and l.business_id = new.business_id and l.deleted_at is null
  ) then
    raise exception 'Journal line location must belong to the same business.';
  end if;

  return new;
end;
$$;

create or replace function public.block_posted_journal_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.status in ('posted','reversed') then
    raise exception 'Posted accounting journals are immutable. Create a reversal instead.';
  end if;
  return new;
end;
$$;

create or replace function public.block_journal_line_delete_or_update()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_status public.accounting_journal_status;
begin
  select status into v_status
  from public.accounting_journal_entries
  where id = old.journal_entry_id;

  if v_status <> 'draft' then
    raise exception 'Posted accounting journal lines are immutable.';
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

-- =========================================================
-- POSTING ENGINE
-- =========================================================

create or replace function public.post_accounting_journal(p_journal_entry_id uuid)
returns public.accounting_journal_entries
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_entry public.accounting_journal_entries%rowtype;
  v_debits bigint;
  v_credits bigint;
  v_line_count integer;
  v_period_status public.accounting_period_status;
begin
  select * into v_entry
  from public.accounting_journal_entries
  where id = p_journal_entry_id
  for update;

  if not found then
    raise exception 'Journal entry not found.';
  end if;

  if v_entry.status = 'posted' then
    return v_entry;
  end if;

  if v_entry.status <> 'draft' then
    raise exception 'Only draft journals can be posted.';
  end if;

  if auth.uid() is not null and not public.has_permission(
    v_entry.business_id, 'accounting.post', v_entry.location_id
  ) then
    raise exception 'Permission denied to post this journal.';
  end if;

  select status into v_period_status
  from public.accounting_periods
  where id = v_entry.period_id
    and business_id = v_entry.business_id
    and deleted_at is null;

  if v_period_status is null then
    raise exception 'Accounting period not found.';
  end if;

  if v_period_status <> 'open' then
    raise exception 'Accounting period is not open.';
  end if;

  select
    count(*)::integer,
    coalesce(sum(debit_cents),0)::bigint,
    coalesce(sum(credit_cents),0)::bigint
  into v_line_count, v_debits, v_credits
  from public.accounting_journal_lines
  where journal_entry_id = v_entry.id;

  if v_line_count < 2 then
    raise exception 'A journal entry requires at least two lines.';
  end if;

  if v_debits <= 0 or v_debits <> v_credits then
    raise exception 'Journal is not balanced. Debits: %, credits: %.', v_debits, v_credits;
  end if;

  update public.accounting_journal_entries
  set total_debit_cents = v_debits,
      total_credit_cents = v_credits,
      status = 'posted',
      posted_at = now(),
      posted_by = auth.uid(),
      updated_by = auth.uid(),
      updated_at = now()
  where id = v_entry.id
  returning * into v_entry;

  return v_entry;
end;
$$;

create or replace function public.reverse_accounting_journal(
  p_journal_entry_id uuid,
  p_reversal_date date,
  p_reason text
)
returns public.accounting_journal_entries
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_original public.accounting_journal_entries%rowtype;
  v_period_id uuid;
  v_reversal public.accounting_journal_entries%rowtype;
  v_number text;
begin
  select * into v_original
  from public.accounting_journal_entries
  where id = p_journal_entry_id
  for update;

  if not found or v_original.status <> 'posted' then
    raise exception 'Only a posted journal can be reversed.';
  end if;

  if v_original.reversed_by_entry_id is not null then
    raise exception 'Journal has already been reversed.';
  end if;

  if auth.uid() is not null and not public.has_permission(
    v_original.business_id, 'accounting.post', v_original.location_id
  ) then
    raise exception 'Permission denied to reverse this journal.';
  end if;

  select id into v_period_id
  from public.accounting_periods
  where business_id = v_original.business_id
    and deleted_at is null
    and status = 'open'
    and p_reversal_date between starts_on and ends_on
  limit 1;

  if v_period_id is null then
    raise exception 'No open accounting period contains the reversal date.';
  end if;

  v_number := v_original.journal_number || '-REV-' ||
              to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS');

  insert into public.accounting_journal_entries (
    business_id, location_id, period_id, journal_number, entry_date,
    description, source_type, source_id, source_reference,
    idempotency_key, currency_code, reversal_of_entry_id,
    metadata, created_by, updated_by
  )
  values (
    v_original.business_id, v_original.location_id, v_period_id, v_number,
    p_reversal_date, 'Reversal: ' || v_original.description ||
    case when p_reason is null then '' else ' â€” ' || p_reason end,
    'reversal', v_original.id, v_original.journal_number,
    'journal-reversal:' || v_original.id::text,
    v_original.currency_code, v_original.id,
    jsonb_build_object('reason', p_reason), auth.uid(), auth.uid()
  )
  returning * into v_reversal;

  insert into public.accounting_journal_lines (
    business_id, journal_entry_id, account_id, location_id,
    line_number, description, debit_cents, credit_cents,
    customer_id, membership_id, vendor_id, metadata, created_by
  )
  select
    business_id, v_reversal.id, account_id, location_id,
    line_number, 'Reversal: ' || coalesce(description, ''),
    credit_cents, debit_cents,
    customer_id, membership_id, vendor_id, metadata, auth.uid()
  from public.accounting_journal_lines
  where journal_entry_id = v_original.id
  order by line_number;

  perform public.post_accounting_journal(v_reversal.id);

  update public.accounting_journal_entries
  set status = 'reversed',
      reversed_by_entry_id = v_reversal.id,
      reversed_at = now(),
      updated_by = auth.uid(),
      updated_at = now()
  where id = v_original.id;

  select * into v_reversal
  from public.accounting_journal_entries
  where id = v_reversal.id;

  return v_reversal;
end;
$$;

-- =========================================================
-- POS SALE POSTING RPC
-- =========================================================

create or replace function public.post_pos_transaction_to_accounting(
  p_transaction_id uuid
)
returns public.accounting_journal_entries
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_tx public.transactions%rowtype;
  v_period_id uuid;
  v_cash_account uuid;
  v_sales_account uuid;
  v_tax_account uuid;
  v_tip_account uuid;
  v_cogs_account uuid;
  v_inventory_account uuid;
  v_entry public.accounting_journal_entries%rowtype;
  v_line integer := 0;
  v_net_sales bigint;
begin
  select * into v_tx
  from public.transactions
  where id = p_transaction_id;

  if not found then
    raise exception 'Transaction not found.';
  end if;

  if v_tx.status::text not in ('completed','partially_refunded','refunded') then
    raise exception 'Only completed transactions can be posted.';
  end if;

  if auth.uid() is not null and not public.has_permission(
    v_tx.business_id, 'accounting.post', v_tx.location_id
  ) then
    raise exception 'Permission denied to post this transaction.';
  end if;

  select id into v_period_id
  from public.accounting_periods
  where business_id = v_tx.business_id
    and deleted_at is null
    and status = 'open'
    and v_tx.occurred_at::date between starts_on and ends_on
  limit 1;

  if v_period_id is null then
    raise exception 'No open accounting period contains the transaction date.';
  end if;

  select id into v_cash_account from public.accounting_accounts
   where business_id=v_tx.business_id and system_key='cash' and deleted_at is null;
  select id into v_sales_account from public.accounting_accounts
   where business_id=v_tx.business_id and system_key='sales_revenue' and deleted_at is null;
  select id into v_tax_account from public.accounting_accounts
   where business_id=v_tx.business_id and system_key='sales_tax_payable' and deleted_at is null;
  select id into v_tip_account from public.accounting_accounts
   where business_id=v_tx.business_id and system_key='tips_payable' and deleted_at is null;
  select id into v_cogs_account from public.accounting_accounts
   where business_id=v_tx.business_id and system_key='cost_of_goods_sold' and deleted_at is null;
  select id into v_inventory_account from public.accounting_accounts
   where business_id=v_tx.business_id and system_key='inventory' and deleted_at is null;

  if v_cash_account is null or v_sales_account is null or v_tax_account is null
     or v_tip_account is null or v_cogs_account is null or v_inventory_account is null then
    raise exception 'Required system accounting accounts are missing.';
  end if;

  v_net_sales := v_tx.subtotal_cents - v_tx.discount_cents;

  insert into public.accounting_journal_entries (
    business_id, location_id, period_id, journal_number, entry_date,
    description, source_type, source_id, source_reference,
    idempotency_key, currency_code, metadata, created_by, updated_by
  )
  values (
    v_tx.business_id, v_tx.location_id, v_period_id,
    'POS-' || v_tx.transaction_number, v_tx.occurred_at::date,
    'POS sale ' || v_tx.transaction_number,
    'pos_sale', v_tx.id, v_tx.transaction_number,
    'pos-sale:' || v_tx.id::text, v_tx.currency_code,
    jsonb_build_object('transaction_id', v_tx.id), auth.uid(), auth.uid()
  )
  on conflict (business_id, idempotency_key)
    where idempotency_key is not null
  do update set updated_at = excluded.updated_at
  returning * into v_entry;

  if v_entry.status = 'posted' then
    return v_entry;
  end if;

  delete from public.accounting_journal_lines
  where journal_entry_id = v_entry.id;

  v_line := v_line + 1;
  insert into public.accounting_journal_lines (
    business_id,journal_entry_id,account_id,location_id,line_number,
    description,debit_cents,credit_cents,membership_id,created_by
  ) values (
    v_tx.business_id,v_entry.id,v_cash_account,v_tx.location_id,v_line,
    'Cash and card receipts',v_tx.total_cents,0,v_tx.membership_id,auth.uid()
  );

  if v_net_sales > 0 then
    v_line := v_line + 1;
    insert into public.accounting_journal_lines (
      business_id,journal_entry_id,account_id,location_id,line_number,
      description,debit_cents,credit_cents,membership_id,created_by
    ) values (
      v_tx.business_id,v_entry.id,v_sales_account,v_tx.location_id,v_line,
      'Sales revenue',0,v_net_sales,v_tx.membership_id,auth.uid()
    );
  end if;

  if v_tx.tax_cents > 0 then
    v_line := v_line + 1;
    insert into public.accounting_journal_lines (
      business_id,journal_entry_id,account_id,location_id,line_number,
      description,debit_cents,credit_cents,membership_id,created_by
    ) values (
      v_tx.business_id,v_entry.id,v_tax_account,v_tx.location_id,v_line,
      'Sales tax payable',0,v_tx.tax_cents,v_tx.membership_id,auth.uid()
    );
  end if;

  if v_tx.tip_cents > 0 then
    v_line := v_line + 1;
    insert into public.accounting_journal_lines (
      business_id,journal_entry_id,account_id,location_id,line_number,
      description,debit_cents,credit_cents,membership_id,created_by
    ) values (
      v_tx.business_id,v_entry.id,v_tip_account,v_tx.location_id,v_line,
      'Tips payable',0,v_tx.tip_cents,v_tx.membership_id,auth.uid()
    );
  end if;

  if v_tx.estimated_cost_cents > 0 then
    v_line := v_line + 1;
    insert into public.accounting_journal_lines (
      business_id,journal_entry_id,account_id,location_id,line_number,
      description,debit_cents,credit_cents,membership_id,created_by
    ) values (
      v_tx.business_id,v_entry.id,v_cogs_account,v_tx.location_id,v_line,
      'Cost of goods sold',v_tx.estimated_cost_cents,0,v_tx.membership_id,auth.uid()
    );

    v_line := v_line + 1;
    insert into public.accounting_journal_lines (
      business_id,journal_entry_id,account_id,location_id,line_number,
      description,debit_cents,credit_cents,membership_id,created_by
    ) values (
      v_tx.business_id,v_entry.id,v_inventory_account,v_tx.location_id,v_line,
      'Inventory relieved',0,v_tx.estimated_cost_cents,v_tx.membership_id,auth.uid()
    );
  end if;

  return public.post_accounting_journal(v_entry.id);
end;
$$;

-- =========================================================
-- REPORTING FUNCTIONS
-- =========================================================

create or replace function public.accounting_trial_balance(
  p_business_id uuid,
  p_as_of_date date
)
returns table (
  account_id uuid,
  account_code text,
  account_name text,
  account_type public.accounting_account_type,
  debit_cents bigint,
  credit_cents bigint,
  net_balance_cents bigint
)
language sql
stable
security definer
set search_path = public, auth
set row_security = off
as $$
  select
    a.id,
    a.code,
    a.name,
    a.account_type,
    coalesce(sum(l.debit_cents),0)::bigint,
    coalesce(sum(l.credit_cents),0)::bigint,
    case
      when a.normal_balance = 'debit'
        then (coalesce(sum(l.debit_cents),0) - coalesce(sum(l.credit_cents),0))::bigint
      else (coalesce(sum(l.credit_cents),0) - coalesce(sum(l.debit_cents),0))::bigint
    end
  from public.accounting_accounts a
  left join public.accounting_journal_lines l on l.account_id = a.id
  left join public.accounting_journal_entries j
    on j.id = l.journal_entry_id
   and j.status in ('posted','reversed')
   and j.entry_date <= p_as_of_date
  where a.business_id = p_business_id
    and a.deleted_at is null
    and (
      auth.uid() is null
      or public.has_permission(p_business_id, 'accounting.read')
    )
  group by a.id, a.code, a.name, a.account_type, a.normal_balance
  order by a.code;
$$;

create or replace function public.accounting_profit_and_loss(
  p_business_id uuid,
  p_start_date date,
  p_end_date date
)
returns table (
  account_id uuid,
  account_code text,
  account_name text,
  account_type public.accounting_account_type,
  amount_cents bigint
)
language sql
stable
security definer
set search_path = public, auth
set row_security = off
as $$
  select
    a.id,
    a.code,
    a.name,
    a.account_type,
    case
      when a.account_type = 'revenue'
        then (coalesce(sum(l.credit_cents),0) - coalesce(sum(l.debit_cents),0))::bigint
      else (coalesce(sum(l.debit_cents),0) - coalesce(sum(l.credit_cents),0))::bigint
    end
  from public.accounting_accounts a
  join public.accounting_journal_lines l on l.account_id = a.id
  join public.accounting_journal_entries j on j.id = l.journal_entry_id
  where a.business_id = p_business_id
    and a.deleted_at is null
    and a.account_type in ('revenue','expense')
    and j.status in ('posted','reversed')
    and j.entry_date between p_start_date and p_end_date
    and (
      auth.uid() is null
      or public.has_permission(p_business_id, 'accounting.read')
    )
  group by a.id, a.code, a.name, a.account_type
  order by a.account_type desc, a.code;
$$;

-- =========================================================
-- PERIOD MANAGEMENT
-- =========================================================

create or replace function public.set_accounting_period_status(
  p_period_id uuid,
  p_status public.accounting_period_status
)
returns public.accounting_periods
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
declare
  v_period public.accounting_periods%rowtype;
begin
  select * into v_period
  from public.accounting_periods
  where id = p_period_id
  for update;

  if not found then raise exception 'Accounting period not found.'; end if;

  if auth.uid() is not null and not public.has_permission(
    v_period.business_id, 'accounting.close_period'
  ) then
    raise exception 'Permission denied to change accounting period status.';
  end if;

  if p_status = 'closed' and exists (
    select 1 from public.accounting_journal_entries j
    where j.period_id = v_period.id and j.status = 'draft'
  ) then
    raise exception 'Cannot close a period containing draft journals.';
  end if;

  update public.accounting_periods
  set status = p_status,
      soft_closed_at = case when p_status='soft_closed' then now() else soft_closed_at end,
      soft_closed_by = case when p_status='soft_closed' then auth.uid() else soft_closed_by end,
      closed_at = case when p_status='closed' then now() else closed_at end,
      closed_by = case when p_status='closed' then auth.uid() else closed_by end,
      reopened_at = case when p_status='open' and status <> 'open' then now() else reopened_at end,
      reopened_by = case when p_status='open' and status <> 'open' then auth.uid() else reopened_by end,
      updated_by = auth.uid(),
      updated_at = now()
  where id = v_period.id
  returning * into v_period;

  return v_period;
end;
$$;

-- =========================================================
-- TRIGGERS
-- =========================================================

drop trigger if exists accounting_journal_entries_validate on public.accounting_journal_entries;
create trigger accounting_journal_entries_validate
before insert or update on public.accounting_journal_entries
for each row execute function public.validate_accounting_journal_entry();

drop trigger if exists accounting_journal_entries_block_posted_mutation on public.accounting_journal_entries;
create trigger accounting_journal_entries_block_posted_mutation
before update or delete on public.accounting_journal_entries
for each row execute function public.block_posted_journal_mutation();

drop trigger if exists accounting_journal_lines_validate on public.accounting_journal_lines;
create trigger accounting_journal_lines_validate
before insert or update on public.accounting_journal_lines
for each row execute function public.validate_accounting_journal_line();

drop trigger if exists accounting_journal_lines_block_mutation on public.accounting_journal_lines;
create trigger accounting_journal_lines_block_mutation
before update or delete on public.accounting_journal_lines
for each row execute function public.block_journal_line_delete_or_update();

-- Business ID immutability
do $$
declare
  t text;
begin
  foreach t in array array[
    'accounting_periods','accounting_accounts','accounting_journal_entries',
    'accounting_vendors','vendor_bills','accounting_bank_accounts',
    'bank_reconciliations','customer_invoices','expense_categories','expense_claims'
  ]
  loop
    execute format('drop trigger if exists %I on public.%I', t || '_prevent_business_change', t);
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.prevent_business_id_change()',
      t || '_prevent_business_change', t
    );
  end loop;
end $$;

-- Updated at and version triggers
do $$
declare
  t text;
begin
  foreach t in array array[
    'accounting_periods','accounting_accounts','accounting_journal_entries',
    'accounting_vendors','vendor_bills','accounting_bank_accounts',
    'bank_reconciliations','customer_invoices','expense_categories','expense_claims'
  ]
  loop
    execute format('drop trigger if exists %I on public.%I', t || '_set_updated_at', t);
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      t || '_set_updated_at', t
    );
    execute format('drop trigger if exists %I on public.%I', t || '_increment_version', t);
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.increment_record_version()',
      t || '_increment_version', t
    );
  end loop;
end $$;

-- =========================================================
-- DEFAULT CHART OF ACCOUNTS
-- =========================================================

insert into public.accounting_accounts (
  business_id, code, name, description, account_type, normal_balance,
  is_control_account, allow_manual_posting, system_key, display_order
)
select
  b.id, v.code, v.name, v.description,
  v.account_type::public.accounting_account_type,
  v.normal_balance::public.accounting_normal_balance,
  v.is_control, v.manual_posting, v.system_key, v.display_order
from public.businesses b
cross join (
  values
    ('1000','Cash','Cash on hand and undeposited receipts.','asset','debit',true,false,'cash',10),
    ('1010','Bank Accounts','Operating and deposit bank balances.','asset','debit',true,false,'bank',20),
    ('1100','Accounts Receivable','Amounts owed by customers.','asset','debit',true,false,'accounts_receivable',30),
    ('1200','Inventory','Inventory asset at historical cost.','asset','debit',true,false,'inventory',40),
    ('1300','Prepaid Expenses','Expenses paid before recognition.','asset','debit',false,true,'prepaid_expenses',50),
    ('2000','Accounts Payable','Amounts owed to vendors.','liability','credit',true,false,'accounts_payable',100),
    ('2100','Sales Tax Payable','Collected sales tax owed to tax authorities.','liability','credit',true,false,'sales_tax_payable',110),
    ('2200','Tips Payable','Employee or contractor tips awaiting distribution.','liability','credit',true,false,'tips_payable',120),
    ('2300','Loyalty Liability','Estimated liability for earned customer rewards.','liability','credit',true,false,'loyalty_liability',130),
    ('3000','Owner Equity','Owner contributed equity.','equity','credit',true,false,'owner_equity',200),
    ('3100','Retained Earnings','Accumulated retained earnings.','equity','credit',true,false,'retained_earnings',210),
    ('4000','Sales Revenue','Gross revenue from product and service sales.','revenue','credit',false,true,'sales_revenue',300),
    ('4100','Other Revenue','Non-operating and miscellaneous revenue.','revenue','credit',false,true,'other_revenue',310),
    ('5000','Cost of Goods Sold','Historical cost of products sold.','expense','debit',false,true,'cost_of_goods_sold',400),
    ('6000','Operating Expenses','General operating expenses.','expense','debit',false,true,'operating_expense',500),
    ('6100','Rent Expense','Facility rent expense.','expense','debit',false,true,'rent_expense',510),
    ('6200','Payroll Expense','Employee payroll expense.','expense','debit',false,true,'payroll_expense',520),
    ('6300','Marketing Expense','Advertising and promotion expense.','expense','debit',false,true,'marketing_expense',530),
    ('6400','Bank Fees','Banking and payment processing fees.','expense','debit',false,true,'bank_fees',540),
    ('6500','Refunds and Allowances','Sales refunds and customer allowances.','expense','debit',false,true,'refunds_allowances',550)
) as v(
  code,name,description,account_type,normal_balance,
  is_control,manual_posting,system_key,display_order
)
where b.deleted_at is null
  and not exists (
    select 1 from public.accounting_accounts a
    where a.business_id = b.id
      and lower(a.code) = lower(v.code)
      and a.deleted_at is null
  );

-- Current calendar-year period for existing businesses.
insert into public.accounting_periods (
  business_id, code, name, starts_on, ends_on, status
)
select
  b.id,
  extract(year from current_date)::int::text,
  'Fiscal Year ' || extract(year from current_date)::int::text,
  make_date(extract(year from current_date)::int,1,1),
  make_date(extract(year from current_date)::int,12,31),
  'open'
from public.businesses b
where b.deleted_at is null
  and not exists (
    select 1 from public.accounting_periods p
    where p.business_id = b.id
      and current_date between p.starts_on and p.ends_on
      and p.deleted_at is null
  );

-- =========================================================
-- ROLE PROVISIONING
-- =========================================================

create or replace function public.provision_accounting_role_permissions(p_business_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
set row_security = off
as $$
begin
  insert into public.role_permissions (business_id, role_id, permission_id)
  select p_business_id, r.id, p.id
  from public.business_roles r
  cross join public.permissions p
  where r.business_id = p_business_id
    and r.deleted_at is null
    and r.code in ('owner','administrator')
    and p.module = 'accounting'
    and not exists (
      select 1 from public.role_permissions rp
      where rp.role_id = r.id and rp.permission_id = p.id
    );

  insert into public.role_permissions (business_id, role_id, permission_id)
  select p_business_id, r.id, p.id
  from public.business_roles r
  cross join public.permissions p
  where r.business_id = p_business_id
    and r.deleted_at is null
    and r.code = 'manager'
    and p.code in (
      'accounting.read','accounting.ap_read','accounting.ap_manage',
      'accounting.ar_read','accounting.ar_manage',
      'accounting.bank_read','accounting.expense_read','accounting.expense_manage'
    )
    and not exists (
      select 1 from public.role_permissions rp
      where rp.role_id = r.id and rp.permission_id = p.id
    );

  insert into public.role_permissions (business_id, role_id, permission_id)
  select p_business_id, r.id, p.id
  from public.business_roles r
  cross join public.permissions p
  where r.business_id = p_business_id
    and r.deleted_at is null
    and r.code = 'auditor'
    and p.code in (
      'accounting.read','accounting.ap_read','accounting.ar_read',
      'accounting.bank_read','accounting.expense_read','accounting.export'
    )
    and not exists (
      select 1 from public.role_permissions rp
      where rp.role_id = r.id and rp.permission_id = p.id
    );
end;
$$;

select public.provision_accounting_role_permissions(b.id)
from public.businesses b
where b.deleted_at is null;

-- =========================================================
-- ROW LEVEL SECURITY
-- =========================================================

do $$
declare
  t text;
begin
  foreach t in array array[
    'accounting_periods','accounting_accounts','accounting_journal_entries',
    'accounting_journal_lines','accounting_vendors','vendor_bills',
    'vendor_bill_lines','accounting_bank_accounts','accounting_bank_transactions',
    'bank_reconciliations','bank_reconciliation_items','customer_invoices',
    'customer_invoice_lines','vendor_payments','vendor_payment_allocations',
    'customer_payments','customer_payment_allocations','expense_categories',
    'expense_claims'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('alter table public.%I force row level security', t);
  end loop;
end $$;

-- General accounting
drop policy if exists accounting_periods_read on public.accounting_periods;
create policy accounting_periods_read on public.accounting_periods
for select to authenticated using (public.has_permission(business_id,'accounting.read'));

drop policy if exists accounting_periods_manage on public.accounting_periods;
create policy accounting_periods_manage on public.accounting_periods
to authenticated
using (public.has_permission(business_id,'accounting.manage'))
with check (public.has_permission(business_id,'accounting.manage'));

drop policy if exists accounting_accounts_read on public.accounting_accounts;
create policy accounting_accounts_read on public.accounting_accounts
for select to authenticated using (public.has_permission(business_id,'accounting.read'));

drop policy if exists accounting_accounts_manage on public.accounting_accounts;
create policy accounting_accounts_manage on public.accounting_accounts
to authenticated
using (public.has_permission(business_id,'accounting.manage'))
with check (public.has_permission(business_id,'accounting.manage'));

drop policy if exists accounting_journal_entries_read on public.accounting_journal_entries;
create policy accounting_journal_entries_read on public.accounting_journal_entries
for select to authenticated
using (public.has_permission(business_id,'accounting.read',location_id));

drop policy if exists accounting_journal_entries_create on public.accounting_journal_entries;
create policy accounting_journal_entries_create on public.accounting_journal_entries
for insert to authenticated
with check (public.has_permission(business_id,'accounting.manage',location_id));

drop policy if exists accounting_journal_entries_draft_update on public.accounting_journal_entries;
create policy accounting_journal_entries_draft_update on public.accounting_journal_entries
for update to authenticated
using (status='draft' and public.has_permission(business_id,'accounting.manage',location_id))
with check (public.has_permission(business_id,'accounting.manage',location_id));

drop policy if exists accounting_journal_lines_read on public.accounting_journal_lines;
create policy accounting_journal_lines_read on public.accounting_journal_lines
for select to authenticated using (public.has_permission(business_id,'accounting.read',location_id));

drop policy if exists accounting_journal_lines_manage on public.accounting_journal_lines;
create policy accounting_journal_lines_manage on public.accounting_journal_lines
to authenticated
using (public.has_permission(business_id,'accounting.manage',location_id))
with check (public.has_permission(business_id,'accounting.manage',location_id));

-- AP
drop policy if exists accounting_vendors_read on public.accounting_vendors;
create policy accounting_vendors_read on public.accounting_vendors
for select to authenticated using (public.has_permission(business_id,'accounting.ap_read'));

drop policy if exists accounting_vendors_manage on public.accounting_vendors;
create policy accounting_vendors_manage on public.accounting_vendors
to authenticated
using (public.has_permission(business_id,'accounting.ap_manage'))
with check (public.has_permission(business_id,'accounting.ap_manage'));

drop policy if exists vendor_bills_read on public.vendor_bills;
create policy vendor_bills_read on public.vendor_bills
for select to authenticated using (public.has_permission(business_id,'accounting.ap_read',location_id));

drop policy if exists vendor_bills_manage on public.vendor_bills;
create policy vendor_bills_manage on public.vendor_bills
to authenticated
using (public.has_permission(business_id,'accounting.ap_manage',location_id))
with check (public.has_permission(business_id,'accounting.ap_manage',location_id));

drop policy if exists vendor_bill_lines_read on public.vendor_bill_lines;
create policy vendor_bill_lines_read on public.vendor_bill_lines
for select to authenticated using (public.has_permission(business_id,'accounting.ap_read'));

drop policy if exists vendor_bill_lines_manage on public.vendor_bill_lines;
create policy vendor_bill_lines_manage on public.vendor_bill_lines
to authenticated
using (public.has_permission(business_id,'accounting.ap_manage'))
with check (public.has_permission(business_id,'accounting.ap_manage'));

drop policy if exists vendor_payments_read on public.vendor_payments;
create policy vendor_payments_read on public.vendor_payments
for select to authenticated using (public.has_permission(business_id,'accounting.ap_read'));

drop policy if exists vendor_payments_manage on public.vendor_payments;
create policy vendor_payments_manage on public.vendor_payments
to authenticated
using (public.has_permission(business_id,'accounting.ap_manage'))
with check (public.has_permission(business_id,'accounting.ap_manage'));

drop policy if exists vendor_payment_allocations_read on public.vendor_payment_allocations;
create policy vendor_payment_allocations_read on public.vendor_payment_allocations
for select to authenticated using (public.has_permission(business_id,'accounting.ap_read'));

drop policy if exists vendor_payment_allocations_manage on public.vendor_payment_allocations;
create policy vendor_payment_allocations_manage on public.vendor_payment_allocations
to authenticated
using (public.has_permission(business_id,'accounting.ap_manage'))
with check (public.has_permission(business_id,'accounting.ap_manage'));

-- AR
drop policy if exists customer_invoices_read on public.customer_invoices;
create policy customer_invoices_read on public.customer_invoices
for select to authenticated using (public.has_permission(business_id,'accounting.ar_read',location_id));

drop policy if exists customer_invoices_manage on public.customer_invoices;
create policy customer_invoices_manage on public.customer_invoices
to authenticated
using (public.has_permission(business_id,'accounting.ar_manage',location_id))
with check (public.has_permission(business_id,'accounting.ar_manage',location_id));

drop policy if exists customer_invoice_lines_read on public.customer_invoice_lines;
create policy customer_invoice_lines_read on public.customer_invoice_lines
for select to authenticated using (public.has_permission(business_id,'accounting.ar_read'));

drop policy if exists customer_invoice_lines_manage on public.customer_invoice_lines;
create policy customer_invoice_lines_manage on public.customer_invoice_lines
to authenticated
using (public.has_permission(business_id,'accounting.ar_manage'))
with check (public.has_permission(business_id,'accounting.ar_manage'));

drop policy if exists customer_payments_read on public.customer_payments;
create policy customer_payments_read on public.customer_payments
for select to authenticated using (public.has_permission(business_id,'accounting.ar_read'));

drop policy if exists customer_payments_manage on public.customer_payments;
create policy customer_payments_manage on public.customer_payments
to authenticated
using (public.has_permission(business_id,'accounting.ar_manage'))
with check (public.has_permission(business_id,'accounting.ar_manage'));

drop policy if exists customer_payment_allocations_read on public.customer_payment_allocations;
create policy customer_payment_allocations_read on public.customer_payment_allocations
for select to authenticated using (public.has_permission(business_id,'accounting.ar_read'));

drop policy if exists customer_payment_allocations_manage on public.customer_payment_allocations;
create policy customer_payment_allocations_manage on public.customer_payment_allocations
to authenticated
using (public.has_permission(business_id,'accounting.ar_manage'))
with check (public.has_permission(business_id,'accounting.ar_manage'));

-- Banking
drop policy if exists accounting_bank_accounts_read on public.accounting_bank_accounts;
create policy accounting_bank_accounts_read on public.accounting_bank_accounts
for select to authenticated using (public.has_permission(business_id,'accounting.bank_read',location_id));

drop policy if exists accounting_bank_accounts_manage on public.accounting_bank_accounts;
create policy accounting_bank_accounts_manage on public.accounting_bank_accounts
to authenticated
using (public.has_permission(business_id,'accounting.bank_manage',location_id))
with check (public.has_permission(business_id,'accounting.bank_manage',location_id));

drop policy if exists accounting_bank_transactions_read on public.accounting_bank_transactions;
create policy accounting_bank_transactions_read on public.accounting_bank_transactions
for select to authenticated using (public.has_permission(business_id,'accounting.bank_read',location_id));

drop policy if exists accounting_bank_transactions_manage on public.accounting_bank_transactions;
create policy accounting_bank_transactions_manage on public.accounting_bank_transactions
to authenticated
using (public.has_permission(business_id,'accounting.bank_manage',location_id))
with check (public.has_permission(business_id,'accounting.bank_manage',location_id));

drop policy if exists bank_reconciliations_read on public.bank_reconciliations;
create policy bank_reconciliations_read on public.bank_reconciliations
for select to authenticated using (public.has_permission(business_id,'accounting.bank_read'));

drop policy if exists bank_reconciliations_manage on public.bank_reconciliations;
create policy bank_reconciliations_manage on public.bank_reconciliations
to authenticated
using (public.has_permission(business_id,'accounting.bank_manage'))
with check (public.has_permission(business_id,'accounting.bank_manage'));

drop policy if exists bank_reconciliation_items_read on public.bank_reconciliation_items;
create policy bank_reconciliation_items_read on public.bank_reconciliation_items
for select to authenticated using (public.has_permission(business_id,'accounting.bank_read'));

drop policy if exists bank_reconciliation_items_manage on public.bank_reconciliation_items;
create policy bank_reconciliation_items_manage on public.bank_reconciliation_items
to authenticated
using (public.has_permission(business_id,'accounting.bank_manage'))
with check (public.has_permission(business_id,'accounting.bank_manage'));

-- Expenses
drop policy if exists expense_categories_read on public.expense_categories;
create policy expense_categories_read on public.expense_categories
for select to authenticated using (public.has_permission(business_id,'accounting.expense_read'));

drop policy if exists expense_categories_manage on public.expense_categories;
create policy expense_categories_manage on public.expense_categories
to authenticated
using (public.has_permission(business_id,'accounting.expense_manage'))
with check (public.has_permission(business_id,'accounting.expense_manage'));

drop policy if exists expense_claims_read on public.expense_claims;
create policy expense_claims_read on public.expense_claims
for select to authenticated
using (
  public.has_permission(business_id,'accounting.expense_read',location_id)
  or employee_id = public.current_employee_id(business_id)
);

drop policy if exists expense_claims_manage on public.expense_claims;
create policy expense_claims_manage on public.expense_claims
to authenticated
using (
  public.has_permission(business_id,'accounting.expense_manage',location_id)
  or (employee_id = public.current_employee_id(business_id) and status in ('draft','submitted'))
)
with check (
  public.has_permission(business_id,'accounting.expense_manage',location_id)
  or employee_id = public.current_employee_id(business_id)
);

-- =========================================================
-- GRANTS
-- =========================================================

grant select, insert, update on public.accounting_periods to authenticated;
grant select, insert, update on public.accounting_accounts to authenticated;
grant select, insert, update on public.accounting_journal_entries to authenticated;
grant select, insert, update, delete on public.accounting_journal_lines to authenticated;
grant select, insert, update on public.accounting_vendors to authenticated;
grant select, insert, update on public.vendor_bills to authenticated;
grant select, insert, update, delete on public.vendor_bill_lines to authenticated;
grant select, insert, update on public.accounting_bank_accounts to authenticated;
grant select, insert, update on public.accounting_bank_transactions to authenticated;
grant select, insert, update on public.bank_reconciliations to authenticated;
grant select, insert, update, delete on public.bank_reconciliation_items to authenticated;
grant select, insert, update on public.customer_invoices to authenticated;
grant select, insert, update, delete on public.customer_invoice_lines to authenticated;
grant select, insert, update on public.vendor_payments to authenticated;
grant select, insert, update, delete on public.vendor_payment_allocations to authenticated;
grant select, insert, update on public.customer_payments to authenticated;
grant select, insert, update, delete on public.customer_payment_allocations to authenticated;
grant select, insert, update on public.expense_categories to authenticated;
grant select, insert, update on public.expense_claims to authenticated;

grant execute on function public.post_accounting_journal(uuid) to authenticated;
grant execute on function public.reverse_accounting_journal(uuid,date,text) to authenticated;
grant execute on function public.post_pos_transaction_to_accounting(uuid) to authenticated;
grant execute on function public.accounting_trial_balance(uuid,date) to authenticated;
grant execute on function public.accounting_profit_and_loss(uuid,date,date) to authenticated;
grant execute on function public.set_accounting_period_status(uuid,public.accounting_period_status) to authenticated;

comment on table public.accounting_accounts is
  'Tenant-specific chart of accounts supporting double-entry bookkeeping.';
comment on table public.accounting_journal_entries is
  'Accounting journal headers. Posted and reversed journals are immutable.';
comment on table public.accounting_journal_lines is
  'Debit and credit lines belonging to accounting journals.';
comment on table public.accounting_periods is
  'Non-overlapping fiscal periods with open, soft-closed, and closed states.';
comment on function public.post_accounting_journal(uuid) is
  'Validates permissions, period state, line count, and debit-credit balance before posting.';
comment on function public.post_pos_transaction_to_accounting(uuid) is
  'Creates and posts an idempotent double-entry journal for a completed POS transaction.';

commit;
