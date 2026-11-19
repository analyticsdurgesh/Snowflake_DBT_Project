{#
================================================================================
models/marts/agg_neighbourhood_monthly_performance.sql
LAYER: marts     BUILT AS: table
================================================================================
PURPOSE
  One row = one neighbourhood in one month.
  It rolls the listing-month table up one more level, giving the dashboard its
  neighbourhood comparison numbers.

THE ROLL-UP CHAIN (each step is coarser than the one before)
  fct_listing_calendar                    listing + day
  agg_listing_monthly_performance         listing + month
  agg_neighbourhood_monthly_performance   neighbourhood + month   <- this model

dbt KEYWORD USED HERE
  ref('agg_listing_monthly_performance')
      Points at the listing-month model. Because of the chain of ref() calls,
      dbt knows the full build order of all three tables without being told.

HOW dbt BUILDS IT
  marts are "materialized: table", so the whole table is rebuilt on every run.
================================================================================
#}

-- CTE: the listing-month rows.
with listing_monthly as (

    {#- Compiles to: select * from AIRBNB_ANALYTICS.ANALYTICS.agg_listing_monthly_performance #}
    select * from {{ ref('agg_listing_monthly_performance') }}

)

select
    -- ---- Grouping columns ----
    -- The larger area.
    reporting_neighbourhood_group,
    -- The neighbourhood.
    reporting_neighbourhood,
    -- The month (1st day of the month).
    calendar_month,

    -- ---- Aggregates ----
    -- count(distinct x) counts each listing only once: listings with calendar
    -- rows in this neighbourhood and month.
    count(distinct listing_id) as active_listing_count,
    -- Total calendar days across all those listings.
    sum(calendar_days) as calendar_days,
    -- Total available days.
    sum(available_days) as available_days,
    -- Total unavailable days.
    sum(unavailable_days) as unavailable_days,
    -- The rate is recalculated from the totals (sum / sum). Averaging the
    -- listings' own rates would be wrong when listings have different numbers
    -- of days. nullif(..., 0) prevents a division by zero.
    sum(available_days) / nullif(sum(calendar_days), 0) as availability_rate,
    -- The average of the listings' monthly average prices.
    avg(avg_effective_nightly_price) as avg_effective_nightly_price,
    -- Total estimated revenue of the neighbourhood in the month.
    sum(estimated_unavailable_revenue) as estimated_unavailable_revenue

-- Read from the CTE.
from listing_monthly

-- One output row per neighbourhood group + neighbourhood + month.
group by
    reporting_neighbourhood_group,
    reporting_neighbourhood,
    calendar_month
