# Inside Airbnb Dataset

## Source

Inside Airbnb publishes open Airbnb data snapshots at:

<https://insideairbnb.com/get-the-data/>

## Recommended Classroom Files

Use one city snapshot. The project currently includes these files in `data/raw/`:

- `data/raw/listings.csv.gz`
- `data/raw/calendar.csv.gz`
- `data/raw/reviews.csv.gz`
- `data/raw/neighbourhoods.csv`

The classroom recommendation is New York City, New York, United States, but the project also works with other cities that use the same Inside Airbnb column layout.

## Loading Notes

The raw Snowflake tables store text values. dbt handles:

- Date parsing
- Numeric casting
- Currency cleanup
- Percent cleanup
- Boolean `t`/`f` conversion
- Business metrics

## Revenue Note

Inside Airbnb does not include real booking transactions. The project estimates revenue by treating unavailable calendar nights as likely booked nights and multiplying those nights by the best available nightly price.
