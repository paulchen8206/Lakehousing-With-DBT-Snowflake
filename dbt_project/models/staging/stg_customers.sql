with source_customers as (
    select
        v:id::string as customer_id,
        v:first_name::string as first_name,
        v:last_name::string as last_name,
        v:email::string as email,
        v:country::string as country,
        metadata$filename as source_file,
        current_timestamp() as loaded_at
    from {{ source('raw', 'customers_ext') }}
)

select
    customer_id,
    first_name,
    last_name,
    email,
    country,
    source_file,
    loaded_at
from source_customers
where customer_id is not null
