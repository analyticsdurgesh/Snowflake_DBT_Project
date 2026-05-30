with listings as (

    select * from {{ ref('int_airbnb__listing_enriched') }}

)

select
    host_id,
    any_value(host_name) as host_name,
    min(host_since_date) as host_since_date,
    max(host_tenure_days) as host_tenure_days,
    boolor_agg(is_superhost) as is_superhost,
    boolor_agg(host_identity_verified) as host_identity_verified,
    any_value(host_location) as host_location,
    any_value(host_response_time) as host_response_time,
    max(host_response_rate) as host_response_rate,
    max(host_acceptance_rate) as host_acceptance_rate,
    count(*) as listing_count,
    count_if(room_type = 'Entire home/apt') as entire_home_listing_count,
    count_if(room_type = 'Private room') as private_room_listing_count,
    avg(nightly_price) as avg_nightly_price,
    sum(number_of_reviews) as total_reviews

from listings
where host_id is not null
group by host_id
