# VIVID+ Database Architecture

## Purpose

The VIVID+ database is the shared foundation for:

- Customer App
- Employee App
- Owner Portal
- Platform Admin
- Loyalty and rewards
- Campaigns and notifications
- Revenue attribution
- AI recommendations
- Reporting and experiments
- Subscriptions and billing

The database must support thousands of businesses while ensuring that each business can access only its own data.

---

# Core Architecture Principles

## 1. Multi-Tenant by Design

VIVID+ is a multi-tenant platform.

Each business is an independent tenant.

Most operational records must contain:

- business_id
- location_id when applicable
- created_at
- updated_at
- created_by when applicable

Business data must never be exposed to another business.

---

## 2. One Person, Multiple Business Relationships

A customer may join multiple businesses.

Example:

- Vivid Lounge
- A barber shop
- A restaurant
- A gym

The same person should have one platform customer account but a different membership at each business.

Therefore:

- customers represents the person
- memberships represents the relationship between a customer and a business

---

## 3. Business and Location Separation

A business may have one or many locations.

Example:

Business:

Vivid Lounge

Locations:

- West Colonial
- Downtown Orlando
- Kissimmee

Business-wide settings belong to businesses.

Physical operational activity belongs to locations.

---

## 4. Immutable Financial History

Financial and loyalty history should not be silently overwritten.

Transactions, point adjustments, reward redemptions, and campaign results must be recorded as historical entries.

Corrections should create new adjustment records instead of deleting the original history.

---

## 5. Auditability

Important actions must eventually be tracked through audit logs.

Examples:

- Employee awarded points
- Manager changed a reward
- Owner exported customer data
- Administrator suspended a business
- Campaign was launched
- Transaction was voided

---

## 6. Privacy by Design

VIVID+ should collect only data necessary to provide the product.

Sensitive information must be protected through:

- Supabase authentication
- Row Level Security
- role-based permissions
- secure server-side functions
- consent tracking
- notification preferences
- data export and deletion workflows

---

## 7. AI-Ready Data

The database must preserve enough structured history for VIVID+ to calculate:

- customer lifetime value
- average ticket
- visit frequency
- expected return date
- inactivity risk
- campaign impact
- reward cost
- incremental revenue
- estimated profit
- business health score

AI should never depend only on overwritten summary values.

The underlying historical records must remain available.

---

# Naming Standards

## Table Names

Use lowercase plural snake_case.

Examples:

- businesses
- business_locations
- customers
- employees
- memberships

## Primary Keys

Use UUID primary keys.

Example:

id uuid primary key default gen_random_uuid()

## Time Fields

Use timestamptz.

Standard fields:

- created_at
- updated_at
- deleted_at when soft deletion is required

## Money

Store money as integer cents whenever possible.

Examples:

- total_amount_cents
- discount_amount_cents
- reward_cost_cents

Do not use floating-point values for money.

## Status Fields

Use controlled values through:

- PostgreSQL enums
- check constraints
- lookup tables

Avoid unrestricted status text.

---

# Core Relationship Model

Platform User

? Customer Profile

? Membership

? Business

? Location

? Transaction

? Loyalty Activity

? Campaign Attribution

A platform user may also be:

? Employee

? Manager

? Business Owner

? Platform Administrator

Roles must not be inferred from the interface.

They must be validated in the database and server-side authorization layer.

---

# First Five Core Tables

## 1. businesses

### Purpose

Represents each company using VIVID+.

A business is the primary tenant boundary.

### Key Fields

- id
- legal_name
- display_name
- slug
- business_type
- description
- phone
- email
- website_url
- logo_url
- timezone
- currency_code
- country_code
- status
- onboarding_status
- default_location_id
- created_by
- created_at
- updated_at
- deleted_at

### Suggested Status Values

- trial
- active
- past_due
- suspended
- cancelled
- archived

### Important Rules

- slug must be globally unique
- default currency is USD for U.S. businesses
- timezone must be stored per business
- business deletion should normally be soft deletion
- subscription status should not be stored only in this table
- detailed billing records will belong to separate subscription tables

---

## 2. business_locations

### Purpose

Represents a physical or operational location belonging to a business.

### Key Fields

- id
- business_id
- name
- code
- phone
- email
- address_line_1
- address_line_2
- city
- state_region
- postal_code
- country_code
- latitude
- longitude
- timezone
- status
- is_primary
- allows_customer_check_in
- geofence_radius_meters
- created_at
- updated_at
- deleted_at

### Suggested Status Values

- active
- temporarily_closed
- inactive
- archived

### Important Rules

- every location belongs to one business
- location code should be unique within a business
- only one active primary location should exist per business
- geographic coordinates support future geofencing
- timezone may override the business timezone
- customer check-in may be disabled per location

### Unique Constraint

business_id + code

---

## 3. customers

### Purpose

Represents the person using the VIVID+ customer ecosystem.

This table is platform-wide and should not be owned by one business.

### Key Fields

- id
- auth_user_id
- first_name
- last_name
- display_name
- email
- phone
- date_of_birth
- avatar_url
- preferred_language
- timezone
- country_code
- email_verified_at
- phone_verified_at
- status
- last_active_at
- created_at
- updated_at
- deleted_at

### Suggested Status Values

- active
- restricted
- suspended
- deletion_requested
- deleted

### Important Rules

- auth_user_id links to Supabase auth.users
- email and phone normalization must happen before matching
- duplicate customer detection must be handled carefully
- businesses must not receive unrestricted access to the global customer profile
- date of birth access should be limited
- customer consent must be stored separately
- marketing preferences must be stored separately
- customer data deletion must preserve legally required financial records while removing personal data when appropriate

---

## 4. employees

### Purpose

Represents a person authorized to work for a business.

An employee record is a business relationship, not only a login account.

### Key Fields

- id
- business_id
- auth_user_id
- home_location_id
- employee_number
- first_name
- last_name
- display_name
- email
- phone
- role
- status
- hired_at
- terminated_at
- can_access_all_locations
- created_by
- created_at
- updated_at
- deleted_at

### Suggested Roles

- staff
- supervisor
- manager
- owner

Platform administrators should not be stored as normal business employees.

### Suggested Status Values

- invited
- active
- suspended
- terminated
- archived

### Important Rules

- employee_number should be unique within a business
- one person may work for more than one business
- the same auth user may therefore have multiple employee records
- access must be determined by business relationship and permissions
- employee deletion should be soft deletion
- historical transactions must continue referencing the employee
- role alone is not enough for detailed authorization
- granular permissions will be stored separately

### Unique Constraints

- business_id + employee_number
- business_id + auth_user_id

---

## 5. memberships

### Purpose

Represents the relationship between a customer and a business.

This is the foundation for:

- loyalty
- rewards
- customer value
- visit frequency
- tiers
- campaign eligibility
- customer status
- QR membership identity

### Key Fields

- id
- business_id
- customer_id
- joined_location_id
- referred_by_membership_id
- membership_number
- qr_token_hash
- status
- tier_id
- current_points_balance
- lifetime_points_earned
- lifetime_points_redeemed
- lifetime_spend_cents
- lifetime_visits
- first_visit_at
- last_visit_at
- joined_at
- last_activity_at
- source
- created_by_employee_id
- created_at
- updated_at
- deleted_at

### Suggested Status Values

- pending
- active
- paused
- banned
- closed
- archived

### Suggested Sources

- customer_app
- employee_registration
- owner_import
- website
- qr_signup
- referral
- api
- pos_integration

### Important Rules

- one customer should normally have only one active membership per business
- membership number must be unique within a business
- raw permanent QR secrets must not be stored directly
- QR values should use secure rotating or signed tokens
- current point balance is a cached value
- the source of truth will be the loyalty ledger
- lifetime spend is a cached value calculated from transactions
- lifetime visits is a cached value calculated from verified visits
- membership history must remain available after closure
- a membership may be created before the customer completes full registration
- anonymous or provisional membership support may be added later

### Unique Constraints

- business_id + customer_id
- business_id + membership_number

---

# Initial Entity Relationships

businesses

1 ? many business_locations

businesses

1 ? many employees

businesses

1 ? many memberships

customers

1 ? many memberships

business_locations

1 ? many employees

business_locations

1 ? many memberships through joined_location_id

employees

1 ? many memberships through created_by_employee_id

memberships

many ? 1 customers

memberships

many ? 1 businesses

---

# Data Ownership Rules

## Platform-Owned Data

Examples:

- customers
- authentication identities
- platform administrators
- platform consent records
- global device registrations

## Business-Owned Data

Examples:

- employees
- memberships
- transactions
- rewards
- campaigns
- events
- promotions
- business analytics

## Shared Relationship Data

Memberships connect platform customers to businesses.

Businesses may access only the customer information necessary to operate the membership and only according to consent, law, and platform policy.

---

# Row Level Security Direction

## Business Users

An authenticated employee may access a business record only when:

- an active employee record exists
- employee.business_id matches the requested business
- the employee has the required role or permission

## Customers

An authenticated customer may access:

- their own customer profile
- their own memberships
- their own transaction history
- their own points history
- their own rewards
- their own notification preferences

## Platform Administrators

Platform administrator access must use a separate authorization system.

Platform admin access must be logged.

## Service Role

The Supabase service role must never be exposed to browsers or mobile applications.

Service-role operations must run only in secure server environments.

---

# Performance Strategy

Indexes should be created for common access patterns.

Initial index candidates:

- businesses.slug
- business_locations.business_id
- customers.auth_user_id
- customers.email
- customers.phone
- employees.business_id
- employees.auth_user_id
- memberships.business_id
- memberships.customer_id
- memberships.membership_number
- memberships.last_visit_at
- memberships.status

Composite indexes should be added based on real queries.

Do not create excessive indexes before measuring usage.

---

# Cached Metrics Strategy

Some membership values are stored for fast dashboards:

- current_points_balance
- lifetime_points_earned
- lifetime_points_redeemed
- lifetime_spend_cents
- lifetime_visits
- first_visit_at
- last_visit_at

These values are not the permanent source of truth.

They must be recalculable from:

- transaction records
- visit records
- loyalty ledger entries
- redemption records

Updates should occur through secure database functions or trusted server-side services.

---

# Security Requirements

- Enable Row Level Security on all exposed tables
- Deny access by default
- Never trust business_id supplied by the client without authorization checks
- Never calculate permissions only in the user interface
- Use server-side validation for points and rewards
- Prevent employees from modifying historical financial data directly
- Log high-risk actions
- Rate-limit customer lookup and QR scanning
- Store QR token hashes, not reusable raw secrets
- Protect personal information from bulk unauthorized export

---

# Future Core Tables

The next database groups will include:

## Identity and Authorization

- employee_location_access
- roles
- permissions
- role_permissions
- employee_permissions
- platform_admins
- audit_logs

## Loyalty

- loyalty_programs
- loyalty_rules
- loyalty_ledger
- membership_tiers
- rewards
- reward_redemptions

## Commerce

- transactions
- transaction_items
- products
- product_categories
- visits
- payments
- refunds

## Growth and Marketing

- campaigns
- campaign_audiences
- campaign_deliveries
- offers
- offer_redemptions
- experiments
- experiment_groups
- attribution_events

## Communication

- notifications
- notification_templates
- customer_devices
- customer_consents
- communication_preferences

## Events

- events
- event_registrations
- event_attendance
- event_transactions

## SaaS Platform

- subscriptions
- subscription_plans
- invoices
- usage_records
- integrations
- webhooks

## Intelligence

- customer_scores
- business_scores
- recommendations
- forecasts
- model_predictions
- insight_feedback

---

# Completion Standard

The database foundation is considered complete only when:

- migrations are version controlled
- foreign keys are enforced
- indexes support important queries
- all exposed tables use Row Level Security
- permission policies are tested
- financial history is immutable
- loyalty balances are ledger-backed
- data can support multiple businesses and locations
- customers can belong to multiple businesses
- employee access is role and permission controlled
- audit logs exist for high-risk actions
- database backups and recovery procedures are tested
- seed data exists for development
- automated database tests pass
