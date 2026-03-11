{{
    config(
        unique_key='customer_id',
        incremental_strategy='merge'
    )
}}

with ranked_customers as (
    select
        customer_id,
        first_name,
        last_name,
        email,
        country,
        source_file,
        loaded_at,
        bronze_loaded_at,
        row_number() over (
            partition by customer_id
            order by loaded_at desc
        ) as rn
    from {{ ref('brz_customers') }}
),
latest_customers as (
    select
        customer_id,
        first_name,
        last_name,
        email,
        country,
        source_file,
        loaded_at,
        bronze_loaded_at,
        current_timestamp() as silver_loaded_at
    from ranked_customers
    where rn = 1
    {% if is_incremental() %}
    and loaded_at > (select coalesce(max(loaded_at), '1900-01-01'::timestamp_ntz) from {{ this }})
    {% endif %}
)

select * from latest_customers
