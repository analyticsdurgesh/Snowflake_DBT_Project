{#
================================================================================
models/staging/stg_airbnb__listings.sql          LAYER: staging     BUILT AS: view
================================================================================
PURPOSE
  Clean the raw listings table. One row = one Airbnb listing (a place to stay).
  The raw table has about 80 text columns. This model keeps the useful ones,
  gives them clear names and converts them to real types.

dbt KEYWORDS USED HERE
  source('airbnb_raw', 'listings')
      Points at the RAW table declared in _staging_sources.yml.
      Compiles to AIRBNB_ANALYTICS.RAW.listings.

  clean_price(), clean_percent(), to_boolean()
      MACROS from macros/cleaning.sql. A macro is a reusable SQL snippet.
      Each call below is replaced by the SQL text the macro returns.

SNOWFLAKE FUNCTIONS YOU WILL SEE REPEATED
  x::number            cast text to a number (fails if the text is not numeric)
  try_to_number(x)     the safe cast: returns NULL instead of failing
  try_to_decimal(x,p,s) safe cast to a decimal with p digits, s after the dot
  try_to_date(x)       safe cast of text such as '2024-05-01' to a DATE
  trim(x)              remove spaces at both ends
  nullif(x, '')        turn an empty text into NULL
  nullif(trim(x), '')  the two combined: "clean text, or NULL when blank"
================================================================================
#}

-- Step 1: a CTE named "source" that reads the raw table.
with source as (

    {#- Compiles to: select * from AIRBNB_ANALYTICS.RAW.listings #}
    select * from {{ source('airbnb_raw', 'listings') }}

),

-- Step 2: a CTE named "cleaned" that renames and converts each column.
cleaned as (

    select

        -- ---------------- Listing identity ----------------

        -- The raw "id" becomes listing_id, the primary key of this model.
        id::number as listing_id,
        -- The web address of the listing. Blank text becomes NULL.
        nullif(trim(listing_url), '') as listing_url,
        -- The id of the scraping run. Kept as text because it is a label, not a quantity.
        scrape_id::string as scrape_id,
        -- The day the listing was scraped, converted to a DATE.
        try_to_date(last_scraped) as last_scraped_date,
        -- How the scraper found the listing. Renamed to avoid the vague name "source".
        nullif(trim(source), '') as scrape_source,

        -- ---------------- Listing text ----------------

        -- The listing title.
        nullif(trim(name), '') as listing_name,
        -- The host's long description of the place.
        nullif(trim(description), '') as description,
        -- The host's description of the area.
        nullif(trim(neighborhood_overview), '') as neighborhood_overview,
        -- The address of the main photo.
        nullif(trim(picture_url), '') as picture_url,

        -- ---------------- Host ----------------

        -- The id of the host who owns the listing. try_to_number is the safe
        -- cast: it returns NULL instead of failing if the text is not numeric.
        try_to_number(host_id) as host_id,
        -- The web address of the host's profile.
        nullif(trim(host_url), '') as host_url,
        -- The host's display name.
        nullif(trim(host_name), '') as host_name,
        -- The day the host joined Airbnb.
        try_to_date(host_since) as host_since_date,
        -- Where the host says they live.
        nullif(trim(host_location), '') as host_location,
        -- How quickly the host answers, for example "within an hour".
        nullif(trim(host_response_time), '') as host_response_time,
        {#- Macro: "98%" becomes 0.98. #}
        {{ clean_percent('host_response_rate') }} as host_response_rate,
        {#- Macro: share of booking requests the host accepts, as a 0-to-1 rate. #}
        {{ clean_percent('host_acceptance_rate') }} as host_acceptance_rate,
        {#- Macro: 't' / 'f' becomes true / false. Renamed with the "is_" prefix,
            a common naming habit for boolean columns. #}
        {{ to_boolean('host_is_superhost') }} as is_superhost,
        -- How many listings Airbnb says this host has.
        try_to_number(host_listings_count) as host_listings_count,
        -- The same count including listings that are no longer active.
        try_to_number(host_total_listings_count) as host_total_listings_count,
        {#- Macro: does the host have a profile photo? #}
        {{ to_boolean('host_has_profile_pic') }} as host_has_profile_pic,
        {#- Macro: has Airbnb verified the host's identity? #}
        {{ to_boolean('host_identity_verified') }} as host_identity_verified,

        -- ---------------- Location ----------------

        -- The free-text neighbourhood typed by the host (messy, kept for reference).
        nullif(trim(neighbourhood), '') as neighbourhood_text,
        -- The official neighbourhood assigned by Inside Airbnb. This is the one we use.
        nullif(trim(neighbourhood_cleansed), '') as neighbourhood,
        -- The larger area the neighbourhood belongs to, when the city has groups.
        nullif(trim(neighbourhood_group_cleansed), '') as neighbourhood_group,
        -- Map coordinates: up to 12 digits in total, 8 of them after the decimal point.
        try_to_decimal(latitude::string, 12, 8) as latitude,
        try_to_decimal(longitude::string, 12, 8) as longitude,

        -- ---------------- Property ----------------

        -- Detailed type, for example "Entire rental unit".
        nullif(trim(property_type), '') as property_type,
        -- room_type must be one of four known categories. Anything else becomes NULL,
        -- which protects the accepted_values test and the dashboard filters.
        case
            when nullif(trim(room_type), '') in ('Entire home/apt', 'Private room', 'Shared room', 'Hotel room')
                then nullif(trim(room_type), '')
            else null
        end as room_type,
        -- How many guests fit.
        try_to_number(accommodates) as accommodates,
        -- Bathrooms can be 1.5, so a decimal with 2 digits after the dot.
        try_to_decimal(bathrooms::string, 10, 2) as bathrooms,
        -- The text version, for example "1.5 shared baths".
        nullif(trim(bathrooms_text), '') as bathrooms_text,
        -- Number of bedrooms.
        try_to_number(bedrooms) as bedrooms,
        -- Number of beds.
        try_to_number(beds) as beds,
        -- The list of amenities, kept as raw text.
        nullif(trim(amenities), '') as amenities,
        {#- Macro: "$1,234.00" becomes 1234.00. Renamed to say what the price is. #}
        {{ clean_price('price') }} as nightly_price,

        -- ---------------- Booking rules and availability ----------------

        -- Shortest stay allowed, in nights.
        try_to_number(minimum_nights) as minimum_nights,
        -- Longest stay allowed, in nights.
        try_to_number(maximum_nights) as maximum_nights,
        {#- Macro: is the listing bookable at all? #}
        {{ to_boolean('has_availability') }} as has_availability,
        -- Number of available nights in the next 30 days.
        try_to_number(availability_30) as availability_30,
        -- Number of available nights in the next 60 days.
        try_to_number(availability_60) as availability_60,
        -- Number of available nights in the next 90 days.
        try_to_number(availability_90) as availability_90,
        -- Number of available nights in the next 365 days.
        try_to_number(availability_365) as availability_365,
        -- The day the calendar was scraped.
        try_to_date(calendar_last_scraped) as calendar_last_scraped_date,

        -- ---------------- Reviews ----------------

        -- Total reviews the listing has ever received.
        try_to_number(number_of_reviews) as number_of_reviews,
        -- Reviews in the last twelve months ("ltm").
        try_to_number(number_of_reviews_ltm) as number_of_reviews_ltm,
        -- Reviews in the last 30 days ("l30d").
        try_to_number(number_of_reviews_l30d) as number_of_reviews_l30d,
        -- Date of the first review.
        try_to_date(first_review) as first_review_date,
        -- Date of the most recent review.
        try_to_date(last_review) as last_review_date,
        -- Review scores are out of 5 and have decimals, so: decimal with 2 places.
        -- Overall rating.
        try_to_decimal(review_scores_rating::string, 10, 2) as review_scores_rating,
        -- Was the listing as described?
        try_to_decimal(review_scores_accuracy::string, 10, 2) as review_scores_accuracy,
        -- How clean was it?
        try_to_decimal(review_scores_cleanliness::string, 10, 2) as review_scores_cleanliness,
        -- How smooth was check-in?
        try_to_decimal(review_scores_checkin::string, 10, 2) as review_scores_checkin,
        -- How well did the host communicate?
        try_to_decimal(review_scores_communication::string, 10, 2) as review_scores_communication,
        -- How good was the location?
        try_to_decimal(review_scores_location::string, 10, 2) as review_scores_location,
        -- Was it good value for money?
        try_to_decimal(review_scores_value::string, 10, 2) as review_scores_value,
        -- The short-term rental licence number, where the city requires one.
        nullif(trim(license), '') as license,
        {#- Macro: can guests book instantly without host approval? #}
        {{ to_boolean('instant_bookable') }} as is_instant_bookable

    -- Read from the first CTE.
    from source

)

-- Return the cleaned rows. This is the output of the view.
select * from cleaned
