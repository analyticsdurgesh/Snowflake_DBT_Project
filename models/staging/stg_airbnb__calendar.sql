with source as (

    select * from {{ source('airbnb_raw', 'calendar') }}

),

cleaned as (

    select
        listing_id::number as listing_id,
        try_to_date(date) as calendar_date,
        {{ to_boolean('available') }} as is_available,
        {{ clean_price('price') }} as calendar_price,
        {{ clean_price('adjusted_price') }} as adjusted_price,
        try_to_number(minimum_nights) as minimum_nights,
        try_to_number(maximum_nights) as maximum_nights

    from source

)

select * from cleaned
