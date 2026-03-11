{{
    config(
        unique_key='order_id',
        incremental_strategy='merge'
    )
}}

with ranked_orders as (
    select
        order_id,
        customer_id,
        order_status,
        order_ts,
        total_amount,
        source_file,
        loaded_at,
        bronze_loaded_at,
        row_number() over (
            partition by order_id
            order by loaded_at desc
        ) as rn
    from {{ ref('brz_orders') }}
),
latest_orders as (
    select
        order_id,
        customer_id,
        order_status,
        order_ts,
        total_amount,
        source_file,
        loaded_at,
        bronze_loaded_at,
        current_timestamp() as silver_loaded_at
    from ranked_orders
    where rn = 1
    {% if is_incremental() %}
    and loaded_at > (select coalesce(max(loaded_at), '1900-01-01'::timestamp_ntz) from {{ this }})
    {% endif %}
)

select * from latest_orders
