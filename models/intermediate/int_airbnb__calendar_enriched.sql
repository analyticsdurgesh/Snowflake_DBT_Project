with calendar as (

    select * from {{ ref('stg_airbnb__calendar') }}

),

listings as (

    select
        listing_id,
        host_id,
        reporting_neighbourhood,
        reporting_neighbourhood_group,
        room_type,
        property_type,
        accommodates,
        nightly_price
    from {{ ref('int_airbnb__listing_enriched') }}

),

enriched as (

    select
        calendar.listing_id,
        calendar.calendar_date,
        date_trunc(month, calendar.calendar_date)::date as calendar_month,
        calendar.is_available,
        calendar.calendar_price,
        calendar.adjusted_price,
        coalesce(calendar.adjusted_price, calendar.calendar_price, listings.nightly_price) as effective_nightly_price,
        calendar.minimum_nights,
        calendar.maximum_nights,

        listings.host_id,
        listings.reporting_neighbourhood,
        listings.reporting_neighbourhood_group,
        listings.room_type,
        listings.property_type,
        listings.accommodates,

        -- Inside Airbnb has no booking transactions; unavailable nights are used as a classroom revenue proxy.
        case
            when calendar.is_available = false
                then coalesce(calendar.adjusted_price, calendar.calendar_price, listings.nightly_price, 0)
            else 0
        end as estimated_unavailable_night_revenue

    from calendar
    left join listings
        on calendar.listing_id = listings.listing_id

)

select * from enriched
