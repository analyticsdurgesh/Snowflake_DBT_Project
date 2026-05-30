-- Which neighbourhoods have the highest estimated unavailable-night revenue?
select
    reporting_neighbourhood,
    sum(estimated_unavailable_revenue) as estimated_unavailable_revenue
from {{ ref('agg_neighbourhood_monthly_performance') }}
group by reporting_neighbourhood
order by estimated_unavailable_revenue desc;

-- Which room types have the highest average daily price?
select
    room_type,
    avg(effective_nightly_price) as avg_effective_nightly_price
from {{ ref('fct_listing_calendar') }}
group by room_type
order by avg_effective_nightly_price desc;

-- Which hosts manage the most listings?
select
    host_id,
    host_name,
    listing_count
from {{ ref('dim_hosts') }}
order by listing_count desc;
