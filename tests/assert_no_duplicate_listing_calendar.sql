select
    listing_id,
    calendar_date,
    count(*) as row_count
from {{ ref('fct_listing_calendar') }}
group by listing_id, calendar_date
having count(*) > 1
