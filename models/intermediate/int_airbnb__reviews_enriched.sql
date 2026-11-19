{#
================================================================================
models/intermediate/int_airbnb__reviews_enriched.sql
LAYER: intermediate     BUILT AS: view
================================================================================
PURPOSE
  One row = one review, now with details of the listing it was written about
  (host, neighbourhood, room type) and a month label for monthly reports.

dbt KEYWORD USED HERE
  ref('model_name')
      Points at another dbt model. dbt replaces it with the full Snowflake name
      and adds an arrow to the dependency graph, so the referenced model is
      always built first.
================================================================================
#}

-- CTE 1: the clean reviews.
with reviews as (

    {#- Compiles to: select * from AIRBNB_ANALYTICS.STAGING.stg_airbnb__reviews #}
    select * from {{ ref('stg_airbnb__reviews') }}

),

-- CTE 2: only the listing columns this model needs.
listings as (

    select
        -- The join key.
        listing_id,
        -- Who owns the listing.
        host_id,
        -- The never-NULL neighbourhood name.
        reporting_neighbourhood,
        -- The larger area it belongs to.
        reporting_neighbourhood_group,
        -- The room type category.
        room_type
    {#- Compiles to: from AIRBNB_ANALYTICS.INTERMEDIATE.int_airbnb__listing_enriched #}
    from {{ ref('int_airbnb__listing_enriched') }}

)

-- Final SELECT: combine each review with its listing.
select
    -- The review's unique id (primary key).
    reviews.review_id,
    -- The listing that was reviewed.
    reviews.listing_id,
    -- The host of that listing, taken from the listings CTE.
    listings.host_id,
    -- The day the review was written.
    reviews.review_date,
    -- The 1st day of the review's month, used to group reviews by month.
    date_trunc('month', reviews.review_date)::date as review_month,
    -- The guest who wrote it.
    reviews.reviewer_id,
    -- The guest's first name.
    reviews.reviewer_name,
    -- The review text.
    reviews.review_comments,
    -- How many characters the text has.
    reviews.review_comment_length,
    -- true when the review has text.
    reviews.has_review_comment,
    -- Where the listing is.
    listings.reporting_neighbourhood,
    -- The larger area.
    listings.reporting_neighbourhood_group,
    -- The room type of the listing.
    listings.room_type

-- Start from every review.
from reviews

-- LEFT JOIN keeps every review, even if its listing is missing.
left join listings
    -- Match each review to its listing by id.
    on reviews.listing_id = listings.listing_id
