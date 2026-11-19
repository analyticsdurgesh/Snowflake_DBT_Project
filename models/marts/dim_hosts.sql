{#
================================================================================
models/marts/dim_hosts.sql                       LAYER: marts     BUILT AS: table
================================================================================
PURPOSE
  The HOST DIMENSION. One row = one host.
  The source data has no host table. Host details are repeated on every listing
  row, so a host with 5 listings appears 5 times. This model collapses those
  rows into one row per host using GROUP BY, and counts the host's listings.

WHAT IS THE "GRAIN" OF A TABLE?
  The grain is the answer to "what does ONE row represent?".
    int_airbnb__listing_enriched -> one row per LISTING
    dim_hosts                    -> one row per HOST
  Going from a finer grain to a coarser one is called AGGREGATING, and it
  always needs GROUP BY plus an aggregate function for every other column.

dbt KEYWORD USED HERE
  ref('int_airbnb__listing_enriched')
      Points at the intermediate model. dbt fills in the real Snowflake name
      and builds that model first.

HOW dbt BUILDS IT
  marts are "materialized: table", so dbt runs
      create or replace transient table AIRBNB_ANALYTICS.ANALYTICS.DIM_HOSTS as ( ... );
  ("transient" is a Snowflake table type without the extra fail-safe backup
  period. dbt uses it by default, because it can rebuild the table at any time.)
================================================================================
#}

-- CTE: every enriched listing (one row per listing).
with listings as (

    {#- Compiles to: select * from AIRBNB_ANALYTICS.INTERMEDIATE.int_airbnb__listing_enriched #}
    select * from {{ ref('int_airbnb__listing_enriched') }}

)

select
    -- The grouping column. After GROUP BY there is exactly one row per host_id.
    host_id,

    -- An AGGREGATE FUNCTION squeezes many rows into one value.
    -- any_value() returns one of the values in the group. It is the right
    -- choice when all rows of a host carry the same name anyway.
    any_value(host_name) as host_name,

    -- min() = the earliest date found across the host's listings.
    min(host_since_date) as host_since_date,

    -- max() = the largest value found across the host's listings.
    max(host_tenure_days) as host_tenure_days,

    -- boolor_agg() = true if AT LEAST ONE row in the group is true.
    boolor_agg(is_superhost) as is_superhost,

    -- true if the host is identity-verified on any of their listings.
    boolor_agg(host_identity_verified) as host_identity_verified,

    -- Where the host lives (the same on every listing, so any value will do).
    any_value(host_location) as host_location,

    -- How quickly the host replies.
    any_value(host_response_time) as host_response_time,

    -- The host's response rate (0 to 1).
    max(host_response_rate) as host_response_rate,

    -- The host's acceptance rate (0 to 1).
    max(host_acceptance_rate) as host_acceptance_rate,

    -- count(*) counts the rows in the group = how many listings the host has.
    count(*) as listing_count,

    -- count_if(condition) counts only the rows where the condition is true.
    count_if(room_type = 'Entire home/apt') as entire_home_listing_count,

    -- How many of the host's listings are private rooms.
    count_if(room_type = 'Private room') as private_room_listing_count,

    -- avg() = the average price across the host's listings (NULLs are ignored).
    avg(nightly_price) as avg_nightly_price,

    -- sum() = the total number of reviews across all the host's listings.
    sum(number_of_reviews) as total_reviews

-- Read from the CTE.
from listings

-- WHERE filters rows BEFORE grouping. Listings without a host are left out,
-- because a dimension row with a NULL key would be useless.
where host_id is not null

-- GROUP BY puts all rows with the same host_id into one group.
-- Every column in the SELECT must be either in GROUP BY or inside an aggregate.
group by host_id
