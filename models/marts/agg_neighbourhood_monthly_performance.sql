with listing_monthly as (

    select * from {{ ref('agg_listing_monthly_performance') }}

)

select
    reporting_neighbourhood_group,
    reporting_neighbourhood,
    calendar_month,
    count(distinct listing_id) as active_listing_count,
    sum(calendar_days) as calendar_days,
    sum(available_days) as available_days,
    sum(unavailable_days) as unavailable_days,
    sum(available_days) / nullif(sum(calendar_days), 0) as availability_rate,
    avg(avg_effective_nightly_price) as avg_effective_nightly_price,
    sum(estimated_unavailable_revenue) as estimated_unavailable_revenue

from listing_monthly
group by
    reporting_neighbourhood_group,
    reporting_neighbourhood,
    calendar_month
