{{
    config(
        unique_key='order_id',
        incremental_strategy='merge'
    )
}}

with base as (
    select
        order_id,
        customer_id,
        order_status,
        order_ts,
        total_amount,
        source_file,
        loaded_at,
        current_timestamp() as bronze_loaded_at
    from {{ ref('stg_orders') }}
    {% if is_incremental() %}
    where loaded_at > (select coalesce(max(loaded_at), '1900-01-01'::timestamp_ntz) from {{ this }})
    {% endif %}
)

select * from base
