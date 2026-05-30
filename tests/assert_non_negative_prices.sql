select listing_id, nightly_price as price_value, 'dim_listings.nightly_price' as failing_field
from {{ ref('dim_listings') }}
where nightly_price < 0

union all

select listing_id, effective_nightly_price as price_value, 'fct_listing_calendar.effective_nightly_price' as failing_field
from {{ ref('fct_listing_calendar') }}
where effective_nightly_price < 0
