# VIVID+ Secure Loyalty Foundation

## 1. Install dependencies

```bash
npm install
```

## 2. Configure environment variables

Copy `.env.example` to `.env.local` and enter the Supabase project URL and publishable/anon key.

## 3. Run the migration

Open Supabase Dashboard → SQL Editor and run:

`supabase/migrations/001_enterprise_foundation.sql`

This migration is additive. It keeps the existing `members`, `transactions`, and `reward_redemptions` tables and adds the secure staff, points-ledger, and audit foundation.

## 4. Create the first staff login

1. In Supabase Authentication → Users, create a user with email and password.
2. Copy that user's UUID.
3. Run this in the SQL Editor, replacing the values:

```sql
insert into public.staff_users (auth_user_id, full_name, role)
values ('AUTH-USER-UUID-HERE', 'Ali Abide', 'owner');
```

Valid roles: `staff`, `manager`, `admin`, `owner`.

## 5. Start the app

```bash
npm run dev
```

Open `/staff/login`, sign in, then use `/scanner`.

## Security behavior

- The scanner never updates `members.points` directly.
- `/api/points/award` requires an authenticated, active staff account.
- Points are awarded atomically by the database function.
- Every award creates an immutable ledger entry and audit log.
- Idempotency keys prevent accidental duplicate awards.

## Important

The supplied ZIP did not include the previous scanner implementation. A complete secure scanner page was created at `app/scanner/page.tsx`.
