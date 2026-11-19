{#
================================================================================
models/marts/fct_listing_calendar.sql        LAYER: marts     BUILT AS: incremental
================================================================================
PURPOSE
  The main FACT table. One row = one listing on one date, with availability,
  price and estimated revenue. It is the biggest table in the project
  (about 165,000 rows here, and millions for a large city).

WHAT IS A FACT TABLE?
  In dimensional modelling (the "star schema"):
    * a FACT table (prefix fct_) stores EVENTS or MEASUREMENTS. It has many rows
      and numeric columns you add up or average (price, revenue).
    * a DIMENSION table (prefix dim_) stores the THINGS being described
      (listings, hosts). It has fewer rows and descriptive columns.
  Facts answer "how much / how many". Dimensions answer "who / what / where".

--------------------------------------------------------------------------------
dbt KEYWORD: config()
--------------------------------------------------------------------------------
  A config() block at the top of a model sets options for THIS model only.
  It overrides the folder default from dbt_project.yml (marts = table).
  The block prints nothing into the SQL. It only gives instructions to dbt.
  The five options used below are explained one by one.

  1) materialized='incremental'
       A normal "table" model is dropped and rebuilt from zero on every run.
       For a large fact table that wastes time and money, because yesterday's
       rows did not change.
       An INCREMENTAL model is a table that dbt builds in two different ways:
         * FIRST run (the table does not exist yet):
             create table ... as select ...        -> loads everything
         * EVERY LATER run (the table exists):
             only the NEW or CHANGED rows are selected and merged in.

  2) incremental_strategy='merge'
       HOW the new rows are added on later runs. "merge" uses the SQL MERGE
       statement, also known as an UPSERT (update + insert):
         * the row already exists in the table -> UPDATE it
         * the row does not exist yet          -> INSERT it
       Other strategies exist (append, delete+insert). merge is the Snowflake
       default and the safest choice because it can never create duplicates.

  3) unique_key=['listing_id', 'calendar_date']
       How MERGE decides that two rows are "the same row". Here a row is
       identified by the PAIR listing + date (a composite key, so it is a list).
       Without unique_key, merge would simply append, and running the model
       twice would double the data.

  4) on_schema_change='sync_all_columns'
       What to do when you later add or remove a column in this SELECT, while
       the table in Snowflake still has the old columns.
         ignore (default)   keep the old table layout, new columns are skipped
         fail               stop with an error
         append_new_columns add new columns, never remove old ones
         sync_all_columns   add new columns AND remove deleted ones
       sync_all_columns keeps the table identical to the model.

  5) cluster_by=['calendar_date']
       A Snowflake-only option. It asks Snowflake to keep rows with nearby
       dates stored physically close together. Queries that filter on a date
       range can then skip most of the table ("pruning") and run faster.

--------------------------------------------------------------------------------
dbt KEYWORD: is_incremental()
--------------------------------------------------------------------------------
  A dbt function that returns true or false. It is true ONLY when ALL of these
  are true:
    a) this model is materialized as incremental
    b) the table already exists in Snowflake
    c) the command was NOT run with the --full-refresh flag
  Wrapped in an "if" block, it lets us add a WHERE filter that exists only on
  incremental runs. On the first run the filter is left out and every row loads.

--------------------------------------------------------------------------------
dbt KEYWORD: this
--------------------------------------------------------------------------------
  {{ this }} is the table that THIS model creates, as it exists in Snowflake
  right now:  AIRBNB_ANALYTICS.ANALYTICS.fct_listing_calendar
  It lets the model look at its own existing data ("what is the newest date
  I already have?"). You cannot use ref() for this, because a model that refs
  itself would create a loop in the dependency graph.

--------------------------------------------------------------------------------
dbt FLAG: --full-refresh
--------------------------------------------------------------------------------
  dbt run --full-refresh
  forces dbt to DROP the incremental table and rebuild it from zero, exactly
  like a first run. Use it when the model's logic changed, or when a completely
  new data snapshot was loaded and old rows must not survive.
================================================================================
#}

{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['listing_id', 'calendar_date'],
        on_schema_change='sync_all_columns',
        cluster_by=['calendar_date']
    )
}}

-- CTE: the rows this run should process.
with calendar as (

    {#- Read the enriched calendar rows from the intermediate layer.
        Compiles to: select * from AIRBNB_ANALYTICS.INTERMEDIATE.int_airbnb__calendar_enriched #}
    select * from {{ ref('int_airbnb__calendar_enriched') }}

    {#- A Jinja "if" block. Everything up to "endif" is included in the SQL only
        on an incremental run. On the first run, or with --full-refresh, dbt
        removes these lines completely and all rows are selected. #}
    {% if is_incremental() %}

        -- Incremental run: keep only the dates near or after the newest date
        -- that is already stored in the table.
        where calendar_date >= (

            -- max(calendar_date) is the newest date already in the table.
            -- coalesce(..., '1900-01-01') covers an existing but EMPTY table,
            -- where max() returns NULL.
            -- dateadd(day, -7, x) steps back 7 days. This "lookback window"
            -- re-reads the last week so late corrections are picked up too.
            -- MERGE updates those rows instead of duplicating them.
            select dateadd(day, -7, coalesce(max(calendar_date), '1900-01-01'::date))

            {#- "this" compiles to AIRBNB_ANALYTICS.ANALYTICS.fct_listing_calendar,
                the table this very model writes to. #}
            from {{ this }}

        )

    {#- End of the incremental-only block. #}
    {% endif %}

)

-- The final SELECT lists the columns of the fact table one by one.
-- Listing them by name (instead of "select *") makes the table layout explicit.
select
    -- Key part 1: which listing.
    listing_id,
    -- Key part 2: which day. Together with listing_id it identifies one row.
    calendar_date,
    -- The 1st day of that date's month, for monthly grouping.
    calendar_month,
    -- true when the night can still be booked.
    is_available,
    -- The calendar price for the night.
    calendar_price,
    -- The price after discounts.
    adjusted_price,
    -- The best known price: adjusted, else calendar, else the listing's base price.
    effective_nightly_price,
    -- Shortest stay allowed.
    minimum_nights,
    -- Longest stay allowed.
    maximum_nights,
    -- The host of the listing (links to dim_hosts).
    host_id,
    -- The neighbourhood used in reports.
    reporting_neighbourhood,
    -- The larger area.
    reporting_neighbourhood_group,
    -- The room type category.
    room_type,
    -- The detailed property type.
    property_type,
    -- How many guests fit.
    accommodates,
    -- The estimated revenue for the night (price when unavailable, else 0).
    estimated_unavailable_night_revenue,
    -- current_timestamp() is the moment this row was written by dbt.
    -- An "audit column" like this shows when each row was last loaded or updated.
    current_timestamp() as transformed_at

-- Read from the CTE above.
from calendar
