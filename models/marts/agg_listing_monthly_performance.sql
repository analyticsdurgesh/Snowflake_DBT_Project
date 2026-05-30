with calendar as (

    select * from {{ ref('fct_listing_calendar') }}

)

select
    listing_id,
    host_id,
    calendar_month,
    reporting_neighbourhood,
    reporting_neighbourhood_group,
    room_type,
    count(*) as calendar_days,
    count_if(is_available) as available_days,
    count_if(not is_available) as unavailable_days,
    count_if(is_available) / nullif(count(*), 0) as availability_rate,
    avg(effective_nightly_price) as avg_effective_nightly_price,
    sum(estimated_unavailable_night_revenue) as estimated_unavailable_revenue

from calendar
group by
    listing_id,
    host_id,
    calendar_month,
    reporting_neighbourhood,
    reporting_neighbourhood_group,
    room_type
