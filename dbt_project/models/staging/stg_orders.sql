with source_orders as (
    select
        v:id::string as order_id,
        v:customer_id::string as customer_id,
        v:status::string as order_status,
        v:order_date::timestamp_ntz as order_ts,
        v:total_amount::number(18,2) as total_amount,
        metadata$filename as source_file,
        current_timestamp() as loaded_at
    from {{ source('raw', 'orders_ext') }}
)

select
    order_id,
    customer_id,
    order_status,
    order_ts,
    total_amount,
    source_file,
    loaded_at
from source_orders
where order_id is not null
