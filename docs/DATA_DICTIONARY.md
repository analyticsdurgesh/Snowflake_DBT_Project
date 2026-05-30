# Data Dictionary

## Raw Tables

### `RAW.LISTINGS`

Listing-level source data from `listings.csv.gz`. Important fields include listing ID, host details, neighbourhood, room type, property type, price, availability counts, and review scores.

### `RAW.CALENDAR`

Listing-date records from `calendar.csv.gz`. Important fields include listing ID, date, availability, price, adjusted price, minimum nights, and maximum nights.

### `RAW.REVIEWS`

Review records from `reviews.csv.gz`. Important fields include review ID, listing ID, review date, reviewer ID, reviewer name, and comments.

### `RAW.NEIGHBOURHOODS`

Neighbourhood reference values from `neighbourhoods.csv`.

## Final Models

### `DIM_LISTINGS`

One row per listing.

Key fields:

- `listing_id`: unique Airbnb listing identifier
- `host_id`: host identifier
- `reporting_neighbourhood`: neighbourhood used for reporting
- `room_type`: room type classification
- `nightly_price`: cleaned listing base price
- `price_band`: classroom-friendly price bucket
- `review_scores_rating`: listing rating score

### `DIM_HOSTS`

One row per host.

Key fields:

- `host_id`: unique Airbnb host identifier
- `host_name`: host display name
- `listing_count`: number of listings managed by the host
- `avg_nightly_price`: average listing price across the host portfolio
- `total_reviews`: total reviews across host listings

### `FCT_LISTING_CALENDAR`

One row per listing per calendar date.

Key fields:

- `listing_id`: Airbnb listing identifier
- `calendar_date`: availability date
- `is_available`: true when the listing was available
- `effective_nightly_price`: adjusted price, calendar price, or listing base price
- `estimated_unavailable_night_revenue`: estimated revenue proxy for unavailable nights

### `FCT_REVIEWS`

One row per review.

Key fields:

- `review_id`: unique Airbnb review identifier
- `listing_id`: Airbnb listing identifier
- `review_date`: review date
- `review_comments`: review text
- `review_comment_length`: length of review text

### `AGG_LISTING_MONTHLY_PERFORMANCE`

Monthly listing-level performance metrics.

Key fields:

- `calendar_month`: reporting month
- `available_days`: available calendar days
- `unavailable_days`: unavailable calendar days
- `availability_rate`: available days divided by total calendar days
- `estimated_unavailable_revenue`: monthly revenue proxy

### `AGG_NEIGHBOURHOOD_MONTHLY_PERFORMANCE`

Monthly neighbourhood-level performance metrics.

Key fields:

- `reporting_neighbourhood`: neighbourhood used for reporting
- `active_listing_count`: count of listings in the month
- `availability_rate`: neighbourhood availability rate
- `avg_effective_nightly_price`: average effective nightly price
- `estimated_unavailable_revenue`: monthly neighbourhood revenue proxy
