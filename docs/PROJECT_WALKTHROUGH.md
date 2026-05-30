# Project Walkthrough

## 1. Raw Layer

The raw layer stores the Inside Airbnb CSV files in Snowflake exactly as loaded. All columns are text so the load is simple and repeatable.

## 2. Staging Layer

Staging models clean and standardize raw fields:

- `stg_airbnb__listings`
- `stg_airbnb__calendar`
- `stg_airbnb__reviews`
- `stg_airbnb__neighbourhoods`

This layer parses dates, prices, percentages, booleans, and numeric fields.

## 3. Intermediate Layer

Intermediate models add reusable business logic:

- `int_airbnb__listing_enriched`
- `int_airbnb__calendar_enriched`
- `int_airbnb__reviews_enriched`

This layer adds reporting neighbourhoods, host tenure, price buckets, calendar months, and unavailable-night revenue estimates.

## 4. Mart Layer

Mart models are analytics-ready:

- `dim_listings`
- `dim_hosts`
- `fct_listing_calendar`
- `fct_reviews`
- `agg_listing_monthly_performance`
- `agg_neighbourhood_monthly_performance`

The fact and aggregate models are designed for dashboarding and business questions.

## 5. Tests and Documentation

dbt tests validate:

- Required keys are not null
- Expected unique identifiers are unique
- Relationships between calendar/reviews and listings exist
- Boolean values are valid
- Calendar fact rows are not duplicated
- Prices are not negative

dbt documentation is generated from model and column descriptions in YAML files.
