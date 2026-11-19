{#
================================================================================
models/staging/stg_airbnb__neighbourhoods.sql    LAYER: staging     BUILT AS: view
================================================================================
PURPOSE
  Clean the small neighbourhood lookup list. One row = one neighbourhood.
  Remove blank rows and duplicates so it is safe to join to.

dbt KEYWORD USED HERE
  source('airbnb_raw', 'neighbourhoods')
      Points at the RAW table declared in _staging_sources.yml.
      It compiles to AIRBNB_ANALYTICS.RAW.neighbourhoods.
================================================================================
#}

-- Step 1: read the raw table into a CTE named "source".
with source as (

    {#- Compiles to: select * from AIRBNB_ANALYTICS.RAW.neighbourhoods #}
    select * from {{ source('airbnb_raw', 'neighbourhoods') }}

),

-- Step 2: clean it in a CTE named "cleaned".
cleaned as (

    -- DISTINCT removes duplicate rows, so each neighbourhood appears once.
    -- That matters because the "unique" test in _staging_models.yml checks it.
    select distinct

        -- trim() removes spaces at both ends. nullif(x, '') turns '' into NULL.
        nullif(trim(neighbourhood), '') as neighbourhood,

        -- coalesce(a, b) returns the first value that is not NULL.
        -- This file has no group for most rows, so those become 'Unknown'.
        coalesce(nullif(trim(neighbourhood_group), ''), 'Unknown') as neighbourhood_group

    -- Read from the first CTE.
    from source

    -- WHERE keeps only rows that actually have a neighbourhood name.
    where nullif(trim(neighbourhood), '') is not null

)

-- Return the cleaned lookup list.
select * from cleaned
