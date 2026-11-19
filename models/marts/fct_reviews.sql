{#
================================================================================
models/marts/fct_reviews.sql                     LAYER: marts     BUILT AS: table
================================================================================
PURPOSE
  The REVIEW FACT table. One row = one guest review (an event that happened on
  a date), with the listing's neighbourhood and room type attached so reviews
  can be counted by area and by month without extra joins.

WHY DOES THIS FILE LOOK SO SIMPLE?
  All the real work (cleaning, joining) was done in the staging and intermediate
  layers. A mart often just picks the final columns and stores them as a table.
  That is the layered design working as intended.

HOW dbt BUILDS IT
  marts are "materialized: table", so dbt runs
      create or replace transient table AIRBNB_ANALYTICS.ANALYTICS.FCT_REVIEWS as ( ... );
  ("transient" is a Snowflake table type without the extra fail-safe backup
  period. dbt uses it by default, because it can rebuild the table at any time.)

dbt KEYWORD USED HERE
  ref('int_airbnb__reviews_enriched')
      Points at the intermediate model. dbt fills in the real name and builds
      that model first.
================================================================================
#}

select
    -- Primary key: one row per review.
    review_id,
    -- The listing that was reviewed (links to dim_listings).
    listing_id,
    -- The host of that listing (links to dim_hosts).
    host_id,
    -- The day the review was written.
    review_date,
    -- The 1st day of that month, for monthly counts.
    review_month,
    -- The guest who wrote the review.
    reviewer_id,
    -- The guest's first name.
    reviewer_name,
    -- The review text.
    review_comments,
    -- Number of characters in the text.
    review_comment_length,
    -- true when the review has text.
    has_review_comment,
    -- The neighbourhood of the listing.
    reporting_neighbourhood,
    -- The larger area.
    reporting_neighbourhood_group,
    -- The room type of the listing.
    room_type

{#- Compiles to: from AIRBNB_ANALYTICS.INTERMEDIATE.int_airbnb__reviews_enriched #}
from {{ ref('int_airbnb__reviews_enriched') }}
