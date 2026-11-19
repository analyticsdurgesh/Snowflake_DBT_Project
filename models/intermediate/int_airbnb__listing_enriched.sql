{#
================================================================================
models/intermediate/int_airbnb__listing_enriched.sql
LAYER: intermediate     BUILT AS: view
================================================================================
PURPOSE
  Take the clean listings and add reusable business columns:
    * reporting_neighbourhood   a neighbourhood name that is never NULL
    * host_tenure_days          how long the host has been on Airbnb
    * price_band                Budget / Mid-range / Premium / Luxury
    * bedroom_bucket            Studio / 1 bedroom / 2-3 bedrooms / 4+ bedrooms
  Several marts need these, so they are calculated once here.

THE MOST IMPORTANT dbt KEYWORD: ref()
  {{ ref('stg_airbnb__listings') }} means "the dbt model named
  stg_airbnb__listings". ref is short for "reference". It does TWO jobs:

  1. IT FILLS IN THE REAL NAME.
     When compiling, dbt replaces it with the full Snowflake name:
         AIRBNB_ANALYTICS.STAGING.stg_airbnb__listings
     You never hard-code a database or schema. If the target changes from dev
     to prod, the same code points at the prod objects automatically.

  2. IT BUILDS THE DEPENDENCY GRAPH (the "DAG").
     Because this file refs stg_airbnb__listings, dbt knows the staging model
     must be built BEFORE this one. dbt collects every ref() in the project
     into a graph and works out the correct run order by itself.
     You never write "run this first, then that".
     (DAG = Directed Acyclic Graph: arrows have a direction and never loop.)

  source() versus ref()
     source('group', 'table')  -> a RAW table that dbt did NOT build
     ref('model_name')         -> a MODEL that dbt DID build
================================================================================
#}

-- CTE 1: all clean listings.
with listings as (

    {#- Compiles to: select * from AIRBNB_ANALYTICS.STAGING.stg_airbnb__listings
        This ref() also tells dbt to build that staging model first. #}
    select * from {{ ref('stg_airbnb__listings') }}

),

-- CTE 2: the neighbourhood lookup list.
neighbourhoods as (

    {#- Compiles to: select * from AIRBNB_ANALYTICS.STAGING.stg_airbnb__neighbourhoods #}
    select * from {{ ref('stg_airbnb__neighbourhoods') }}

),

-- CTE 3: join the two and add the new columns.
enriched as (

    select
        -- "listings.*" keeps every column of the listings CTE unchanged.
        listings.*,

        -- coalesce returns the first value that is not NULL, reading left to right:
        -- 1) the listing's own neighbourhood, 2) the name from the lookup list,
        -- 3) the text 'Unknown'. The result is therefore never NULL.
        coalesce(listings.neighbourhood, neighbourhoods.neighbourhood, 'Unknown') as reporting_neighbourhood,

        -- The same idea for the larger neighbourhood group.
        coalesce(listings.neighbourhood_group, neighbourhoods.neighbourhood_group, 'Unknown') as reporting_neighbourhood_group,

        -- datediff(day, start, end) counts the days between two dates.
        -- current_date is today, so this is "days since the host joined".
        datediff(day, listings.host_since_date, current_date) as host_tenure_days,

        -- Turn the numeric price into a readable category.
        -- CASE checks the conditions from top to bottom and stops at the first match,
        -- which is why "< 200" does not need to say ">= 75".
        case
            -- No price known.
            when listings.nightly_price is null then 'Unknown'
            -- Under 75 per night.
            when listings.nightly_price < 75 then 'Budget'
            -- 75 up to 199.99.
            when listings.nightly_price < 200 then 'Mid-range'
            -- 200 up to 499.99.
            when listings.nightly_price < 500 then 'Premium'
            -- 500 and above.
            else 'Luxury'
        end as price_band,

        -- Turn the bedroom count into a readable category.
        case
            -- No bedroom count known.
            when listings.bedrooms is null then 'Unknown'
            -- Zero bedrooms means a studio.
            when listings.bedrooms = 0 then 'Studio'
            -- Exactly one bedroom.
            when listings.bedrooms = 1 then '1 bedroom'
            -- BETWEEN includes both ends: 2 and 3.
            when listings.bedrooms between 2 and 3 then '2-3 bedrooms'
            -- Everything larger.
            else '4+ bedrooms'
        end as bedroom_bucket

    -- Start from every listing.
    from listings

    -- LEFT JOIN keeps EVERY row of the left table (listings), even when no
    -- matching neighbourhood exists. Unmatched rows get NULL in the
    -- neighbourhoods columns. An INNER JOIN would silently drop those listings.
    left join neighbourhoods
        -- lower() on both sides makes the match ignore upper/lower case.
        on lower(listings.neighbourhood) = lower(neighbourhoods.neighbourhood)

)

-- Return the enriched listings.
select * from enriched
