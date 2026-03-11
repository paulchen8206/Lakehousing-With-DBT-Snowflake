with orders as (
    select
        cast(order_ts as date) as order_date,
        total_amount,
        customer_id
    from {{ ref('slv_orders') }}
    where order_status not in ('cancelled', 'fraud')
),
customers as (
    select
        customer_id,
        country
    from {{ ref('slv_customers') }}
)

select
    o.order_date,
    c.country,
    count(*) as order_count,
    sum(o.total_amount) as gross_revenue,
    avg(o.total_amount) as avg_order_value,
    current_timestamp() as gold_loaded_at
from orders o
left join customers c
    on o.customer_id = c.customer_id
group by 1, 2
