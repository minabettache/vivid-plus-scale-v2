select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'product_barcodes',
    'inventory_balances',
    'inventory_movements'
  )
order by table_name;