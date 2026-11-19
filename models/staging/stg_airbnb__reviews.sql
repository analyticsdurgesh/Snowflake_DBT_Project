{#
================================================================================
models/staging/stg_airbnb__reviews.sql           LAYER: staging     BUILT AS: view
================================================================================
PURPOSE
  Clean the raw reviews table. One row = one guest review.
  Rename columns, convert text into numbers and dates, and add two small helper
  columns about the review comment.

dbt KEYWORD USED HERE
  source('airbnb_raw', 'reviews')
      Points at a RAW table that dbt did not build. It is declared in
      _staging_sources.yml and compiles to AIRBNB_ANALYTICS.RAW.reviews.

HOW dbt BUILDS IT
  dbt_project.yml sets staging models to "materialized: view", so dbt runs
      create or replace view AIRBNB_ANALYTICS.STAGING.STG_AIRBNB__REVIEWS as ( ... );
  A view stores only the query. The cleaning happens each time it is read.
================================================================================
#}

-- Step 1: a CTE named "source" that reads the raw table.
with source as (

    {#- Compiles to: select * from AIRBNB_ANALYTICS.RAW.reviews #}
    select * from {{ source('airbnb_raw', 'reviews') }}

),

-- Step 2: a CTE named "cleaned" that renames and converts each column.
cleaned as (

    select
        -- The raw column "id" is renamed review_id so its meaning is obvious
        -- when it sits next to listing_id. "::number" casts text to a number.
        id::number as review_id,

        -- The listing this review was written about (a foreign key to listings).
        listing_id::number as listing_id,

        -- Convert the text date into a real DATE. NULL if the text is not a date.
        try_to_date(date) as review_date,

        -- The guest who wrote the review.
        reviewer_id::number as reviewer_id,

        -- trim() removes spaces at both ends. nullif(x, '') then turns an
        -- empty text into NULL, so "no name" is always NULL and never ''.
        nullif(trim(reviewer_name), '') as reviewer_name,

        -- The review text, cleaned the same way.
        nullif(trim(comments), '') as review_comments,

        -- length() counts the characters of the cleaned comment.
        -- It is NULL when there is no comment.
        length(nullif(trim(comments), '')) as review_comment_length,

        -- "x is not null" is an expression that returns true or false.
        -- true when the review has text, false when it is empty.
        nullif(trim(comments), '') is not null as has_review_comment

    -- Read from the first CTE.
    from source

)

-- Return the cleaned rows. This is the output of the view.
select * from cleaned
