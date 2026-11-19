{#
================================================================================
models/staging/stg_airbnb__calendar.sql          LAYER: staging     BUILT AS: view
================================================================================
PURPOSE
  Clean the raw calendar table. One row = one listing on one date.
  Every raw column is text. This model gives each column a proper name and a
  proper data type (number, date, boolean). No joins and no business logic.

WHAT IS A dbt MODEL?
  A model is one .sql file that contains exactly ONE SELECT statement.
  You never write CREATE TABLE or CREATE VIEW. When you run "dbt run", dbt wraps
  your SELECT like this (because dbt_project.yml says staging = view):

      create or replace view AIRBNB_ANALYTICS.STAGING.STG_AIRBNB__CALENDAR as (
          ...the SELECT below...
      );

  The file name becomes the view name.

WHAT IS source()?
  {{ source('airbnb_raw', 'calendar') }} means: "the table called calendar inside
  the source group called airbnb_raw". Both names are declared in
  _staging_sources.yml. When dbt compiles this file it replaces the whole
  expression with the real name:

      AIRBNB_ANALYTICS.RAW.calendar

  Using source() instead of typing the name also tells dbt "this model depends
  on that raw table", which is how the lineage graph is drawn.

THE CTE PATTERN (used in every model of this project)
  A CTE (Common Table Expression) is a named, temporary result written as
      with some_name as ( select ... )
  It exists only while the query runs. Think of it as a named step.
  Every staging model follows the same three steps:
      1. source   -> read the raw table
      2. cleaned  -> rename and convert the columns
      3. final select -> return the result
================================================================================
#}

-- WITH starts the list of CTEs. "source" is the name we give the first step.
with source as (

    {#- source('airbnb_raw', 'calendar') compiles to AIRBNB_ANALYTICS.RAW.calendar.
        "select *" means "every column". It is fine here because the very next
        step picks the columns it wants by name. #}
    select * from {{ source('airbnb_raw', 'calendar') }}

-- The closing bracket ends the CTE. The comma says another CTE follows.
),

-- Second step: "cleaned" reads from "source" and fixes names and types.
cleaned as (

    select
        -- "::number" casts text to a whole number. "::" is Snowflake's cast operator.
        -- "as listing_id" gives the output column its name (an alias).
        listing_id::number as listing_id,

        -- try_to_date turns text such as '2026-02-15' into a real DATE.
        -- The "try_" version returns NULL for bad text instead of failing.
        -- The raw column is called "date", a reserved SQL word, so we rename it.
        try_to_date(date) as calendar_date,

        {#- Macro call. to_boolean is defined in macros/cleaning.sql. dbt replaces
            this line with a CASE expression that turns 't' into true and 'f'
            into false. The quotes around 'available' pass the column NAME as text. #}
        {{ to_boolean('available') }} as is_available,

        {#- Macro call. clean_price removes "$" and "," from text such as
            "$1,234.00" and returns the number 1234.00. #}
        {{ clean_price('price') }} as calendar_price,

        {#- The same macro reused for a second column. This is the point of
            macros: write the logic once, use it many times. #}
        {{ clean_price('adjusted_price') }} as adjusted_price,

        -- try_to_number turns text into a number, or NULL when it is not numeric.
        try_to_number(minimum_nights) as minimum_nights,

        -- The longest stay the host allows, converted the same way.
        try_to_number(maximum_nights) as maximum_nights

    -- Read from the first CTE, not from the raw table directly.
    from source

)

-- The final SELECT is what the view returns to anyone who queries it.
select * from cleaned
