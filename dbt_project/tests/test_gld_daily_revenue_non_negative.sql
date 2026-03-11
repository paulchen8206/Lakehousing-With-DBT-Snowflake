select *
from {{ ref('gld_daily_revenue') }}
where gross_revenue < 0
   or avg_order_value < 0
   or order_count < 0
