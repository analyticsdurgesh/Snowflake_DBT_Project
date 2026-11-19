{#
================================================================================
models/intermediate/int_airbnb__calendar_enriched.sql
LAYER: intermediate     BUILT AS: view
================================================================================
PURPOSE
  One row = one listing on one date, now with listing details attached
  (host, neighbourhood, room type) and two calculated columns:
    * effective_nightly_price               the best price we know for that night
    * estimated_unavailable_night_revenue   our revenue estimate for that night

WHY "ESTIMATED" REVENUE?
  Inside Airbnb has no booking or payment data. It only shows whether a night
  is available. This project ASSUMES that an unavailable night was booked and
  counts its price as revenue. It is a rough proxy (a host may simply have
  blocked the night), which is why the word "estimated" is in the column name.

dbt KEYWORD USED HERE
  ref('model_name')
      Points at another dbt model. dbt replaces it with the full Snowflake name
      and learns that the other model must be built first.
      This file refs one STAGING model and one INTERMEDIATE model, so dbt will
      always build those two before this one.
================================================================================
#}

-- CTE 1: the clean calendar rows.
with calendar as (

    {#- Compiles to: select * from AIRBNB_ANALYTICS.STAGING.stg_airbnb__calendar #}
    select * from {{ ref('stg_airbnb__calendar') }}

),

-- CTE 2: only the listing columns this model needs.
listings as (

    select
        -- The join key.
        listing_id,
        -- Who owns the listing.
        host_id,
        -- The never-NULL neighbourhood built in int_airbnb__listing_enriched.
        reporting_neighbourhood,
        -- The larger area it belongs to.
        reporting_neighbourhood_group,
        -- Entire home/apt, Private room, Shared room or Hotel room.
        room_type,
        -- Detailed property type.
        property_type,
        -- How many guests fit.
        accommodates,
        -- The listing's base price, used as a fallback price below.
        nightly_price
    {#- Compiles to: from AIRBNB_ANALYTICS.INTERMEDIATE.int_airbnb__listing_enriched #}
    from {{ ref('int_airbnb__listing_enriched') }}

),

-- CTE 3: join calendar rows to their listing and calculate the new columns.
enriched as (

    select
        -- Which listing.
        calendar.listing_id,
        -- Which day.
        calendar.calendar_date,
        -- date_trunc(month, d) moves any date back to the 1st of its month
        -- (2026-02-15 becomes 2026-02-01). "::date" drops the time part.
        -- It gives every row a month label for the monthly reports.
        date_trunc(month, calendar.calendar_date)::date as calendar_month,
        -- true when the night can still be booked.
        calendar.is_available,
        -- The price shown on the calendar for that night (often NULL in this file).
        calendar.calendar_price,
        -- The price after discounts (often NULL in this file).
        calendar.adjusted_price,
        -- coalesce picks the first price that is not NULL, in order of preference:
        -- adjusted price, then calendar price, then the listing's base price.
        coalesce(calendar.adjusted_price, calendar.calendar_price, listings.nightly_price) as effective_nightly_price,
        -- Shortest stay allowed on that date.
        calendar.minimum_nights,
        -- Longest stay allowed on that date.
        calendar.maximum_nights,

        -- Listing details copied onto every calendar row.
        listings.host_id,
        listings.reporting_neighbourhood,
        listings.reporting_neighbourhood_group,
        listings.room_type,
        listings.property_type,
        listings.accommodates,

        -- The revenue estimate for this single night.
        case
            -- The night is NOT available, so we assume it was booked...
            when calendar.is_available = false
                -- ...and count the best known price. The final 0 makes sure the
                -- result is never NULL, even when no price exists at all.
                then coalesce(calendar.adjusted_price, calendar.calendar_price, listings.nightly_price, 0)
            -- The night is still available: no booking, so no revenue.
            else 0
        end as estimated_unavailable_night_revenue

    -- Start from every calendar row.
    from calendar

    -- LEFT JOIN keeps every calendar row, even if its listing is missing.
    left join listings
        -- Match each calendar row to its listing by id.
        on calendar.listing_id = listings.listing_id

)

-- Return the enriched calendar rows.
select * from enriched
