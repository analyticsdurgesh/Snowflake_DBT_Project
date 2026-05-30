with listings as (

    select * from {{ ref('stg_airbnb__listings') }}

),

neighbourhoods as (

    select * from {{ ref('stg_airbnb__neighbourhoods') }}

),

enriched as (

    select
        listings.*,

        -- Prefer the listing-level neighbourhood, then fall back to the reference file.
        coalesce(listings.neighbourhood, neighbourhoods.neighbourhood, 'Unknown') as reporting_neighbourhood,
        coalesce(listings.neighbourhood_group, neighbourhoods.neighbourhood_group, 'Unknown') as reporting_neighbourhood_group,

        datediff(day, listings.host_since_date, current_date) as host_tenure_days,

        case
            when listings.nightly_price is null then 'Unknown'
            when listings.nightly_price < 75 then 'Budget'
            when listings.nightly_price < 200 then 'Mid-range'
            when listings.nightly_price < 500 then 'Premium'
            else 'Luxury'
        end as price_band,

        case
            when listings.bedrooms is null then 'Unknown'
            when listings.bedrooms = 0 then 'Studio'
            when listings.bedrooms = 1 then '1 bedroom'
            when listings.bedrooms between 2 and 3 then '2-3 bedrooms'
            else '4+ bedrooms'
        end as bedroom_bucket

    from listings
    left join neighbourhoods
        on lower(listings.neighbourhood) = lower(neighbourhoods.neighbourhood)

)

select * from enriched
