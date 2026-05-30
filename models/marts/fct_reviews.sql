select
    review_id,
    listing_id,
    host_id,
    review_date,
    review_month,
    reviewer_id,
    reviewer_name,
    review_comments,
    review_comment_length,
    has_review_comment,
    reporting_neighbourhood,
    reporting_neighbourhood_group,
    room_type

from {{ ref('int_airbnb__reviews_enriched') }}
