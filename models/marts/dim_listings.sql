{#
================================================================================
models/marts/dim_listings.sql                    LAYER: marts     BUILT AS: table
================================================================================
PURPOSE
  The LISTING DIMENSION. One row = one listing, with every descriptive column a
  dashboard or analyst needs. The dashboard's listing table, map and filters
  all read from this table.

WHAT IS A DIMENSION TABLE?
  A dimension (prefix dim_) describes a THING: who, what, where.
  You filter and group by its columns ("show me Private rooms in the Sixth Ward").
  A fact table (prefix fct_) holds the events and numbers, and links to
  dimensions through id columns such as listing_id.

HOW dbt BUILDS IT
  dbt_project.yml sets the marts folder to "materialized: table", so dbt runs
      create or replace transient table AIRBNB_ANALYTICS.ANALYTICS.DIM_LISTINGS as ( ... );
  ("transient" is a Snowflake table type without the extra fail-safe backup
  period. dbt uses it by default, because it can rebuild the table at any time.)
  The data is physically stored, which makes dashboard queries fast.
  The table is fully rebuilt on every "dbt run".

dbt KEYWORD USED HERE
  ref('int_airbnb__listing_enriched')
      Points at the intermediate model. dbt fills in the real name and makes
      sure that model is built first.

WHY LIST EVERY COLUMN INSTEAD OF "select *"?
  A mart is a public contract. Naming the columns means a new column added
  upstream never appears here by accident, and readers can see the table's
  exact layout by reading this file.
================================================================================
#}

select
    -- ---------------- Listing identity ----------------
    -- Primary key: one row per listing.
    listing_id,
    -- Link to the listing on the Airbnb website.
    listing_url,
    -- The listing title.
    listing_name,
    -- The host's description of the place.
    description,
    -- Link to the main photo.
    picture_url,

    -- ---------------- Host ----------------
    -- The owner of the listing (links to dim_hosts).
    host_id,
    -- The host's display name.
    host_name,
    -- The day the host joined Airbnb.
    host_since_date,
    -- Days since the host joined.
    host_tenure_days,
    -- true when the host has Superhost status.
    is_superhost,
    -- How quickly the host replies, as text.
    host_response_time,
    -- Share of messages answered (0 to 1).
    host_response_rate,
    -- Share of booking requests accepted (0 to 1).
    host_acceptance_rate,
    -- true when Airbnb verified the host's identity.
    host_identity_verified,

    -- ---------------- Location ----------------
    -- The neighbourhood used in reports (never NULL).
    reporting_neighbourhood,
    -- The larger area the neighbourhood belongs to.
    reporting_neighbourhood_group,
    -- Map coordinates, used by the dashboard map.
    latitude,
    longitude,

    -- ---------------- Property ----------------
    -- Detailed type, for example "Entire rental unit".
    property_type,
    -- One of four categories, for example "Private room".
    room_type,
    -- How many guests fit.
    accommodates,
    -- Number of bathrooms (can be 1.5).
    bathrooms,
    -- Number of bedrooms.
    bedrooms,
    -- Number of beds.
    beds,

    -- ---------------- Price ----------------
    -- The base price per night.
    nightly_price,
    -- Budget / Mid-range / Premium / Luxury / Unknown.
    price_band,
    -- Studio / 1 bedroom / 2-3 bedrooms / 4+ bedrooms / Unknown.
    bedroom_bucket,

    -- ---------------- Booking rules and availability ----------------
    -- Shortest stay allowed, in nights.
    minimum_nights,
    -- Longest stay allowed, in nights.
    maximum_nights,
    -- true when the listing can be booked at all.
    has_availability,
    -- Available nights in the next 30, 60, 90 and 365 days.
    availability_30,
    availability_60,
    availability_90,
    availability_365,

    -- ---------------- Reviews ----------------
    -- Total number of reviews.
    number_of_reviews,
    -- Reviews in the last twelve months.
    number_of_reviews_ltm,
    -- Reviews in the last 30 days.
    number_of_reviews_l30d,
    -- Date of the first review.
    first_review_date,
    -- Date of the latest review.
    last_review_date,
    -- Overall rating out of 5.
    review_scores_rating,
    -- The six detailed ratings out of 5.
    review_scores_accuracy,
    review_scores_cleanliness,
    review_scores_checkin,
    review_scores_communication,
    review_scores_location,
    review_scores_value,

    -- ---------------- Other ----------------
    -- The rental licence number, where required.
    license,
    -- true when guests can book without waiting for host approval.
    is_instant_bookable

{#- Compiles to: from AIRBNB_ANALYTICS.INTERMEDIATE.int_airbnb__listing_enriched #}
from {{ ref('int_airbnb__listing_enriched') }}
