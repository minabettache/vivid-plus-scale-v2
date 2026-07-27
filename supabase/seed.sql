-- =========================================================
-- VIVID+ LOCAL DEVELOPMENT SEED
-- Requires migrations 001 through 006.
-- Safe for a fresh `supabase db reset` database.
-- =========================================================

begin;

-- Stable IDs keep local dashboards and tests predictable.
insert into public.businesses (
  id, legal_name, display_name, slug, business_type, description,
  phone, email, timezone, currency_code, country_code,
  status, onboarding_status
) values (
  '10000000-0000-0000-0000-000000000001',
  'Lwalida Export Import LLC',
  'Vivid Orlando',
  'vivid-orlando',
  'smoke_shop_and_hookah_lounge',
  'Connected Vivid Smoke Shop and Vivid Lounge operations with one customer and loyalty ecosystem.',
  '407-868-4229',
  'aliabide426@gmail.com',
  'America/New_York', 'USD', 'US', 'active', 'completed'
) on conflict (id) do nothing;

insert into public.business_locations (
  id, business_id, name, code, phone,
  address_line_1, city, state_region, postal_code, country_code,
  latitude, longitude, timezone, status, is_primary,
  allows_customer_check_in, geofence_radius_meters
) values (
  '20000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  'Vivid Orlando - Smoke Shop & Lounge',
  'ORL-WCOL',
  '407-868-4229',
  '7216 W Colonial Dr', 'Orlando', 'FL', '32818', 'US',
  28.552200, -81.481900,
  'America/New_York', 'active', true, true, 250
) on conflict (id) do nothing;

update public.businesses
set default_location_id = '20000000-0000-0000-0000-000000000001'
where id = '10000000-0000-0000-0000-000000000001';

insert into public.employees (
  id, business_id, home_location_id, employee_number,
  first_name, last_name, display_name, email, phone,
  role, status, hired_at, can_access_all_locations
) values
('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','EMP-001','Ali','Abide','Ali Abide','aliabide426@gmail.com','407-868-4229','owner','active',now()-interval '2 years',true),
('30000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','EMP-002','Jessica',null,'Jessica',null,null,'manager','active',now()-interval '1 year',true),
('30000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','EMP-003','Jasmine',null,'Jasmine',null,null,'staff','active',now()-interval '8 months',false),
('30000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','EMP-004','Thomas','Khalil','Thomas Khalil',null,null,'staff','active',now()-interval '6 months',false),
('30000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','EMP-005','Cynthorie',null,'Cynthorie',null,null,'staff','active',now()-interval '4 months',false)
on conflict (id) do nothing;

insert into public.product_categories (
  id, business_id, name, slug, description, display_order, metadata
) values
('40000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Lounge Hookah','lounge-hookah','Single hookah product; flavor is selected as an order option.',10,'{"business_unit":"lounge"}'),
('40000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','Lounge Drinks','lounge-drinks','Non-alcoholic lounge drinks.',20,'{"business_unit":"lounge"}'),
('40000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','Membership','membership','Vivid+ membership products.',30,'{"business_unit":"shared"}'),
('40000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000001','Disposable Vapes','disposable-vapes','Retail inventory category.',40,'{"business_unit":"smoke_shop","age_restricted":true}'),
('40000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000001','Vape Devices & Juice','vape-devices-juice','Retail inventory category.',50,'{"business_unit":"smoke_shop","age_restricted":true}'),
('40000000-0000-0000-0000-000000000006','10000000-0000-0000-0000-000000000001','Papers, Wraps & Leaf','papers-wraps-leaf','Retail smoking accessories.',60,'{"business_unit":"smoke_shop","age_restricted":true}'),
('40000000-0000-0000-0000-000000000007','10000000-0000-0000-0000-000000000001','Shisha & Charcoal','shisha-charcoal','Lounge and retail supplies.',70,'{"business_unit":"shared","age_restricted":true}'),
('40000000-0000-0000-0000-000000000008','10000000-0000-0000-0000-000000000001','Glass & Accessories','glass-accessories','Legal smoking accessories.',80,'{"business_unit":"smoke_shop","age_restricted":true}'),
('40000000-0000-0000-0000-000000000009','10000000-0000-0000-0000-000000000001','Hemp, CBD & Kratom','hemp-cbd-kratom','Products enabled only where legally carried.',90,'{"business_unit":"smoke_shop","compliance_review_required":true}')
on conflict (id) do nothing;

insert into public.products (
  id,business_id,category_id,name,slug,short_description,
  product_type,status,sku,barcode,price_cents,cost_cents,
  tax_rate_basis_points,track_inventory,is_reward_eligible,
  is_points_earning_eligible,display_order,metadata
) values
('50000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','Hookah','hookah','One hookah product; choose flavor during ordering.','hookah','active','LNG-HOOKAH',null,2000,700,650,false,true,true,10,'{"business_unit":"lounge","option_groups":["flavor"],"pricing_engine":true}'),
('50000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000002','Lounge Drink','lounge-drink','Standard non-alcoholic drink.','beverage','active','LNG-DRINK',null,500,150,650,false,true,true,20,'{"business_unit":"lounge"}'),
('50000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000003','Monthly Membership','monthly-membership','Placeholder membership product.','membership','active','MEM-MONTHLY',null,9900,0,0,false,false,true,30,'{"business_unit":"shared","placeholder":true}'),
('50000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000004','Disposable Vape Demo SKU','disposable-vape-demo','Development catalog example.','physical','active','RET-DISP-001','9000000000001',2499,1250,650,true,true,true,40,'{"business_unit":"smoke_shop","demo":true,"age_restricted":true}'),
('50000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000005','Vape Device Demo SKU','vape-device-demo','Development catalog example.','physical','active','RET-DEV-001','9000000000002',3999,2100,650,true,true,true,50,'{"business_unit":"smoke_shop","demo":true,"age_restricted":true}'),
('50000000-0000-0000-0000-000000000006','10000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000006','Rolling Paper Demo SKU','rolling-paper-demo','Development catalog example.','physical','active','RET-PAPER-001','9000000000003',399,110,650,true,true,true,60,'{"business_unit":"smoke_shop","demo":true,"age_restricted":true}'),
('50000000-0000-0000-0000-000000000007','10000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000007','Shisha Tobacco Demo SKU','shisha-tobacco-demo','Development catalog example.','physical','active','RET-SHISHA-001','9000000000004',1999,950,650,true,true,true,70,'{"business_unit":"shared","demo":true,"age_restricted":true}'),
('50000000-0000-0000-0000-000000000008','10000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000007','Coconut Charcoal Demo SKU','coconut-charcoal-demo','Development catalog example.','physical','active','RET-COAL-001','9000000000005',1299,550,650,true,true,true,80,'{"business_unit":"shared","demo":true}'),
('50000000-0000-0000-0000-000000000009','10000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000008','Grinder Demo SKU','grinder-demo','Development catalog example.','physical','active','RET-GRIND-001','9000000000006',1499,500,650,true,true,true,90,'{"business_unit":"smoke_shop","demo":true,"age_restricted":true}')
on conflict (id) do nothing;

-- Hookah pricing: $20 from 10:00 AM-10:00 PM, $40 from 10:00 PM-2:00 AM,
-- and $50 from 2:00 AM-10:00 AM. Adjust the 10:00 AM boundary to the actual closing/opening time later.
insert into public.pricing_rules (
  id,business_id,location_id,product_id,name,status,
  adjustment_type,amount_cents,priority,is_stackable,
  valid_start_time,valid_end_time,metadata
) values
('60000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','Hookah daytime price','active','fixed_price',2000,300,false,'10:00','22:00','{"label":"Until 10 PM"}'),
('60000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','Hookah late-night price','active','fixed_price',4000,300,false,'22:00','02:00','{"label":"10 PM to 2 AM"}'),
('60000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','Hookah after-hours price','active','fixed_price',5000,300,false,'02:00','10:00','{"label":"After 2 AM"}')
on conflict (id) do nothing;

-- 50 deterministic demo customers and one shared Vivid membership each.
do $$
declare
  i integer;
  v_customer_id uuid;
  v_membership_id uuid;
  first_names text[] := array['Jordan','Taylor','Morgan','Cameron','Alex','Riley','Casey','Avery','Devin','Skyler'];
  last_names text[] := array['Smith','Johnson','Williams','Brown','Jones'];
begin
  for i in 1..50 loop
    v_customer_id := (
      substr(md5('vivid-customer-'||i),1,8)||'-'||substr(md5('vivid-customer-'||i),9,4)||'-4'||substr(md5('vivid-customer-'||i),14,3)||'-a'||substr(md5('vivid-customer-'||i),18,3)||'-'||substr(md5('vivid-customer-'||i),21,12)
    )::uuid;
    v_membership_id := (
      substr(md5('vivid-membership-'||i),1,8)||'-'||substr(md5('vivid-membership-'||i),9,4)||'-4'||substr(md5('vivid-membership-'||i),14,3)||'-b'||substr(md5('vivid-membership-'||i),18,3)||'-'||substr(md5('vivid-membership-'||i),21,12)
    )::uuid;

    insert into public.customers (
      id,first_name,last_name,display_name,email,phone,date_of_birth,
      preferred_language,timezone,country_code,status,last_active_at
    ) values (
      v_customer_id,
      first_names[((i-1)%10)+1],
      last_names[((i-1)%5)+1],
      first_names[((i-1)%10)+1]||' '||last_names[((i-1)%5)+1],
      'customer'||lpad(i::text,2,'0')||'@example.test',
      '+1407555'||lpad(i::text,4,'0'),
      date '1985-01-01' + ((i*137)%5000),
      'en','America/New_York','US','active',now()-(i%20)*interval '1 day'
    ) on conflict (id) do nothing;

    insert into public.memberships (
      id,business_id,customer_id,joined_location_id,membership_number,
      status,joined_at,source,created_by_employee_id
    ) values (
      v_membership_id,
      '10000000-0000-0000-0000-000000000001',
      v_customer_id,
      '20000000-0000-0000-0000-000000000001',
      'VIV-'||lpad(i::text,6,'0'),
      'active',now()-(50-i)*interval '1 day','employee_registration',
      '30000000-0000-0000-0000-000000000001'
    ) on conflict (id) do nothing;
  end loop;
end $$;

-- Temporary reward placeholders. Final program rules will replace these.
insert into public.rewards (
  id,business_id,name,description,reward_kind,reward_scope,status,
  product_id,points_cost,fixed_discount_cents,display_order,metadata
) values
('70000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Placeholder: Free Lounge Drink','Temporary development reward.','free_product','product','active','50000000-0000-0000-0000-000000000002',250,null,10,'{"placeholder":true}'),
('70000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','Placeholder: $5 Credit','Temporary development reward.','fixed_discount','transaction','active',null,500,500,20,'{"placeholder":true}'),
('70000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','Placeholder: Free Hookah','Temporary development reward.','free_product','product','active','50000000-0000-0000-0000-000000000001',1200,null,30,'{"placeholder":true}')
on conflict (id) do nothing;

-- 200 deterministic transactions across lounge and smoke-shop examples.
do $$
declare
  i integer;
  member_no integer;
  v_membership_id uuid;
  v_transaction_id uuid;
  v_visit_id uuid;
  v_product_id uuid;
  v_employee_id uuid;
  v_product_name text;
  v_product_sku text;
  v_product_type public.product_type;
  v_unit_price bigint;
  v_unit_cost bigint;
  v_qty numeric(12,3);
  v_subtotal bigint;
  v_tax bigint;
  v_total bigint;
  v_occurred timestamptz;
  v_is_lounge boolean;
begin
  for i in 1..200 loop
    member_no := ((i-1)%50)+1;
    v_membership_id := (
      substr(md5('vivid-membership-'||member_no),1,8)||'-'||substr(md5('vivid-membership-'||member_no),9,4)||'-4'||substr(md5('vivid-membership-'||member_no),14,3)||'-b'||substr(md5('vivid-membership-'||member_no),18,3)||'-'||substr(md5('vivid-membership-'||member_no),21,12)
    )::uuid;
    v_transaction_id := (
      substr(md5('vivid-transaction-'||i),1,8)||'-'||substr(md5('vivid-transaction-'||i),9,4)||'-4'||substr(md5('vivid-transaction-'||i),14,3)||'-c'||substr(md5('vivid-transaction-'||i),18,3)||'-'||substr(md5('vivid-transaction-'||i),21,12)
    )::uuid;
    v_visit_id := (
      substr(md5('vivid-visit-'||i),1,8)||'-'||substr(md5('vivid-visit-'||i),9,4)||'-4'||substr(md5('vivid-visit-'||i),14,3)||'-d'||substr(md5('vivid-visit-'||i),18,3)||'-'||substr(md5('vivid-visit-'||i),21,12)
    )::uuid;

    v_occurred := now() - ((200-i)%45)*interval '1 day' - ((i*17)%20)*interval '1 hour';
    v_is_lounge := (i % 2 = 0);
    v_employee_id := ('30000000-0000-0000-0000-'||lpad((((i-1)%5)+1)::text,12,'0'))::uuid;

    if v_is_lounge then
      v_product_id := case when i%4=0 then '50000000-0000-0000-0000-000000000001'::uuid else '50000000-0000-0000-0000-000000000002'::uuid end;
    else
      v_product_id := ('50000000-0000-0000-0000-'||lpad((((i-1)%6)+4)::text,12,'0'))::uuid;
    end if;

    select p.name, p.sku, p.product_type, p.price_cents, coalesce(p.cost_cents, 0)
      into v_product_name, v_product_sku, v_product_type, v_unit_price, v_unit_cost
    from public.products as p
    where p.id = v_product_id;

    if v_product_id='50000000-0000-0000-0000-000000000001'::uuid then
      v_unit_price := case
        when extract(hour from v_occurred at time zone 'America/New_York') >= 22 then 4000
        when extract(hour from v_occurred at time zone 'America/New_York') < 2 then 4000
        when extract(hour from v_occurred at time zone 'America/New_York') < 10 then 5000
        else 2000 end;
    end if;

    v_qty := case when v_product_type='physical' then ((i%3)+1)::numeric else 1 end;
    v_subtotal := round(v_unit_price*v_qty)::bigint;
    v_tax := round(v_subtotal*0.065)::bigint;
    v_total := v_subtotal+v_tax;

    if v_is_lounge then
      insert into public.visits (
        id,business_id,location_id,membership_id,checked_in_by_employee_id,
        visit_number,status,source,checked_in_at,checked_out_at,guest_count,metadata
      ) values (
        v_visit_id,'10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001',
        v_membership_id,v_employee_id,'VIS-'||lpad(i::text,6,'0'),'completed','manual',v_occurred-interval '90 minutes',v_occurred,1,
        '{"business_unit":"lounge","seed":true}'
      ) on conflict (id) do nothing;
    else
      v_visit_id := null;
    end if;

    insert into public.transactions (
      id,business_id,location_id,membership_id,visit_id,employee_id,
      transaction_number,status,payment_status,source,currency_code,
      subtotal_cents,discount_cents,tax_cents,tip_cents,total_cents,
      estimated_cost_cents,refunded_cents,occurred_at,metadata
    ) values (
      v_transaction_id,'10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001',
      v_membership_id,v_visit_id,v_employee_id,'TX-'||lpad(i::text,7,'0'),'draft','unpaid','manual','USD',
      v_subtotal,0,v_tax,0,v_total,round(v_unit_cost*v_qty)::bigint,0,v_occurred,
      jsonb_build_object('business_unit',case when v_is_lounge then 'lounge' else 'smoke_shop' end,'seed',true)
    ) on conflict (id) do nothing;

    insert into public.transaction_items (
      business_id,transaction_id,product_id,line_number,
      product_name_snapshot,product_sku_snapshot,product_type_snapshot,
      quantity,unit_price_cents,unit_cost_cents,subtotal_cents,
      discount_cents,tax_cents,total_cents,estimated_cost_cents,metadata
    ) values (
      '10000000-0000-0000-0000-000000000001',v_transaction_id,v_product_id,1,
      v_product_name,v_product_sku,v_product_type,v_qty,v_unit_price,v_unit_cost,v_subtotal,
      0,v_tax,v_total,round(v_unit_cost*v_qty)::bigint,'{"seed":true}'
    ) on conflict (transaction_id,line_number) do nothing;

    update public.transactions set
      status='completed',payment_status='paid',completed_at=v_occurred
    where id=v_transaction_id and status='draft';

    insert into public.loyalty_ledger (
      business_id,membership_id,location_id,transaction_id,direction,event_type,
      points_amount,idempotency_key,description,occurred_at,created_by_employee_id,metadata
    ) values (
      '10000000-0000-0000-0000-000000000001',v_membership_id,
      '20000000-0000-0000-0000-000000000001',v_transaction_id,'credit','purchase',
      greatest(1,floor(v_total/100.0)::bigint),'seed-purchase-'||i,'Demo purchase points',v_occurred,v_employee_id,'{"seed":true}'
    ) on conflict (business_id,idempotency_key) where idempotency_key is not null do nothing;
  end loop;
end $$;

-- Cache spend and visit metrics from the source tables.
update public.memberships m set
  lifetime_spend_cents = coalesce(x.spend,0),
  lifetime_visits = coalesce(x.visits,0),
  first_visit_at = x.first_at,
  last_visit_at = x.last_at,
  last_activity_at = greatest(coalesce(m.last_activity_at,m.joined_at),coalesce(x.last_at,m.joined_at))
from (
  select membership_id,
         sum(total_cents-refunded_cents)::bigint spend,
         count(distinct visit_id) filter (where visit_id is not null)::integer visits,
         min(occurred_at) first_at,
         max(occurred_at) last_at
  from public.transactions
  where business_id='10000000-0000-0000-0000-000000000001'
    and status in ('completed','partially_refunded','refunded')
  group by membership_id
) x
where m.id=x.membership_id;

commit;
