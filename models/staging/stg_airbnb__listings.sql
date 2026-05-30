with source as (

    select * from {{ source('airbnb_raw', 'listings') }}

),

cleaned as (

    select
        id::number as listing_id,
        nullif(trim(listing_url), '') as listing_url,
        scrape_id::string as scrape_id,
        try_to_date(last_scraped) as last_scraped_date,
        nullif(trim(source), '') as scrape_source,

        -- Listing text fields are kept trimmed so downstream marts can display them safely.
        nullif(trim(name), '') as listing_name,
        nullif(trim(description), '') as description,
        nullif(trim(neighborhood_overview), '') as neighborhood_overview,
        nullif(trim(picture_url), '') as picture_url,

        host_id::number as host_id,
        nullif(trim(host_url), '') as host_url,
        nullif(trim(host_name), '') as host_name,
        try_to_date(host_since) as host_since_date,
        nullif(trim(host_location), '') as host_location,
        nullif(trim(host_response_time), '') as host_response_time,
        {{ clean_percent('host_response_rate') }} as host_response_rate,
        {{ clean_percent('host_acceptance_rate') }} as host_acceptance_rate,
        {{ to_boolean('host_is_superhost') }} as is_superhost,
        try_to_number(host_listings_count) as host_listings_count,
        try_to_number(host_total_listings_count) as host_total_listings_count,
        {{ to_boolean('host_has_profile_pic') }} as host_has_profile_pic,
        {{ to_boolean('host_identity_verified') }} as host_identity_verified,

        nullif(trim(neighbourhood), '') as neighbourhood_text,
        nullif(trim(neighbourhood_cleansed), '') as neighbourhood,
        nullif(trim(neighbourhood_group_cleansed), '') as neighbourhood_group,
        try_to_decimal(latitude::string, 12, 8) as latitude,
        try_to_decimal(longitude::string, 12, 8) as longitude,

        nullif(trim(property_type), '') as property_type,
        nullif(trim(room_type), '') as room_type,
        try_to_number(accommodates) as accommodates,
        try_to_decimal(bathrooms::string, 10, 2) as bathrooms,
        nullif(trim(bathrooms_text), '') as bathrooms_text,
        try_to_number(bedrooms) as bedrooms,
        try_to_number(beds) as beds,
        nullif(trim(amenities), '') as amenities,
        {{ clean_price('price') }} as nightly_price,

        try_to_number(minimum_nights) as minimum_nights,
        try_to_number(maximum_nights) as maximum_nights,
        {{ to_boolean('has_availability') }} as has_availability,
        try_to_number(availability_30) as availability_30,
        try_to_number(availability_60) as availability_60,
        try_to_number(availability_90) as availability_90,
        try_to_number(availability_365) as availability_365,
        try_to_date(calendar_last_scraped) as calendar_last_scraped_date,

        try_to_number(number_of_reviews) as number_of_reviews,
        try_to_number(number_of_reviews_ltm) as number_of_reviews_ltm,
        try_to_number(number_of_reviews_l30d) as number_of_reviews_l30d,
        try_to_date(first_review) as first_review_date,
        try_to_date(last_review) as last_review_date,
        try_to_decimal(review_scores_rating::string, 10, 2) as review_scores_rating,
        try_to_decimal(review_scores_accuracy::string, 10, 2) as review_scores_accuracy,
        try_to_decimal(review_scores_cleanliness::string, 10, 2) as review_scores_cleanliness,
        try_to_decimal(review_scores_checkin::string, 10, 2) as review_scores_checkin,
        try_to_decimal(review_scores_communication::string, 10, 2) as review_scores_communication,
        try_to_decimal(review_scores_location::string, 10, 2) as review_scores_location,
        try_to_decimal(review_scores_value::string, 10, 2) as review_scores_value,
        nullif(trim(license), '') as license,
        {{ to_boolean('instant_bookable') }} as is_instant_bookable

    from source

)

select * from cleaned
