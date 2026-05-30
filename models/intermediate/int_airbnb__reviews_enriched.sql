with reviews as (

    select * from {{ ref('stg_airbnb__reviews') }}

),

listings as (

    select
        listing_id,
        host_id,
        reporting_neighbourhood,
        reporting_neighbourhood_group,
        room_type
    from {{ ref('int_airbnb__listing_enriched') }}

)

select
    reviews.review_id,
    reviews.listing_id,
    listings.host_id,
    reviews.review_date,
    date_trunc(month, reviews.review_date)::date as review_month,
    reviews.reviewer_id,
    reviews.reviewer_name,
    reviews.review_comments,
    reviews.review_comment_length,
    reviews.has_review_comment,
    listings.reporting_neighbourhood,
    listings.reporting_neighbourhood_group,
    listings.room_type

from reviews
left join listings
    on reviews.listing_id = listings.listing_id
