{#
================================================================================
models/marts/agg_listing_monthly_performance.sql   LAYER: marts   BUILT AS: table
================================================================================
PURPOSE
  An AGGREGATE table (prefix agg_). One row = one listing in one month.
  It summarises the daily fact table into monthly numbers: how many days were
  available, the average price, and the estimated revenue.

WHY BUILD AN AGGREGATE TABLE?
  The dashboard needs monthly numbers. Calculating them from 165,000 daily rows
  on every page load would be slow. Here dbt does the heavy calculation once,
  at build time, and the dashboard reads a small ready-made table.

GRAIN CHANGE
  fct_listing_calendar             -> one row per listing per DAY
  agg_listing_monthly_performance  -> one row per listing per MONTH

dbt KEYWORD USED HERE
  ref('fct_listing_calendar')
      A mart may ref another mart. dbt builds the fact table first because of
      this ref(), then builds this table from it.

HOW dbt BUILDS IT
  marts are "materialized: table", so the whole table is rebuilt on every run.
================================================================================
#}

-- CTE: every daily row of the fact table.
with calendar as (

    {#- Compiles to: select * from AIRBNB_ANALYTICS.ANALYTICS.fct_listing_calendar #}
    select * from {{ ref('fct_listing_calendar') }}

)

select
    -- ---- Grouping columns: they define what one output row represents ----
    -- Which listing.
    listing_id,
    -- Its host.
    host_id,
    -- Which month (always the 1st day of the month).
    calendar_month,
    -- The listing's neighbourhood.
    reporting_neighbourhood,
    -- The larger area.
    reporting_neighbourhood_group,
    -- The listing's room type.
    room_type,

    -- ---- Aggregates: each one turns the month's daily rows into one number ----
    -- count(*) = number of daily rows = number of calendar days in the month.
    count(*) as calendar_days,
    -- count_if counts only the rows where the condition is true: available days.
    count_if(is_available) as available_days,
    -- "not is_available" flips the boolean: days that were NOT available.
    count_if(not is_available) as unavailable_days,
    -- Availability rate = available days / all days (a number from 0 to 1).
    -- nullif(count(*), 0) turns a zero into NULL, so we can never divide by zero.
    count_if(is_available) / nullif(count(*), 0) as availability_rate,
    -- The average nightly price over the month. avg() ignores NULL prices.
    avg(effective_nightly_price) as avg_effective_nightly_price,
    -- The month's estimated revenue: the sum of the nightly estimates.
    sum(estimated_unavailable_night_revenue) as estimated_unavailable_revenue

-- Read from the CTE.
from calendar

-- GROUP BY creates one group per unique combination of these columns.
-- Every non-aggregated column in the SELECT must be repeated here.
group by
    listing_id,
    host_id,
    calendar_month,
    reporting_neighbourhood,
    reporting_neighbourhood_group,
    room_type
