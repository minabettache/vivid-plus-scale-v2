select *
from public.resolve_product_price(
  '50000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  null,
  now()
);