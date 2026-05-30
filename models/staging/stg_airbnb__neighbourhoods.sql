with source as (

    select * from {{ source('airbnb_raw', 'neighbourhoods') }}

),

cleaned as (

    select distinct
        nullif(trim(neighbourhood), '') as neighbourhood,
        coalesce(nullif(trim(neighbourhood_group), ''), 'Unknown') as neighbourhood_group

    from source
    where nullif(trim(neighbourhood), '') is not null

)

select * from cleaned
