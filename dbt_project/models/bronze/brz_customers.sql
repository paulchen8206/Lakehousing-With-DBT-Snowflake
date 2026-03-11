{{
    config(
        unique_key='customer_id',
        incremental_strategy='merge'
    )
}}

with base as (
    select
        customer_id,
        first_name,
        last_name,
        email,
        country,
        source_file,
        loaded_at,
        current_timestamp() as bronze_loaded_at
    from {{ ref('stg_customers') }}
    {% if is_incremental() %}
    where loaded_at > (select coalesce(max(loaded_at), '1900-01-01'::timestamp_ntz) from {{ this }})
    {% endif %}
)

select * from base
