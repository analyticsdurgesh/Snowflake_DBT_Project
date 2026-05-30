with source as (

    select * from {{ source('airbnb_raw', 'reviews') }}

),

cleaned as (

    select
        id::number as review_id,
        listing_id::number as listing_id,
        try_to_date(date) as review_date,
        reviewer_id::number as reviewer_id,
        nullif(trim(reviewer_name), '') as reviewer_name,
        nullif(trim(comments), '') as review_comments,
        length(nullif(trim(comments), '')) as review_comment_length,
        nullif(trim(comments), '') is not null as has_review_comment

    from source

)

select * from cleaned
