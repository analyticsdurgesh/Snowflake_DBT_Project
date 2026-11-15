# Inside Airbnb Dataset

## Source

Inside Airbnb publishes open Airbnb data snapshots at:

<https://insideairbnb.com/get-the-data/>

## Recommended Classroom Files

Use one city snapshot. The project includes this one in `data/raw/`:
**Albany, New York, United States, snapshot of 14 September 2026**
(500 listings, 182,500 calendar rows, 30,251 reviews, 15 neighbourhoods):

- `data/raw/listings.csv.gz`
- `data/raw/calendar.csv.gz`
- `data/raw/reviews.csv.gz`
- `data/raw/neighbourhoods.csv`

The project also works with other cities that use the same Inside Airbnb column layout.

## License and attribution

Inside Airbnb data is published under the Creative Commons Attribution 4.0 International
License (CC BY 4.0). Source: Inside Airbnb, <https://insideairbnb.com>, Albany NY snapshot
2026-09-14. The files are unchanged copies of the published files.

## What changed in the source (and how the models cope)

- **Calendar prices are gone.** In early-2026 snapshots `calendar.csv` still had `price` and
  `adjusted_price` columns, but every value was empty. From the 2026-09-14 snapshot the two
  columns no longer exist. `stg_airbnb__calendar` reads them only if RAW.CALENDAR has them,
  and the revenue estimate falls back to the listing's nightly price (`listings.price`, set
  for 467 of the 500 listings).
- **Listings gained five `price_quote_*` columns.** Staging selects columns by name, so new
  columns are ignored until a model needs them.
- **`neighbourhoods.csv` ends with an empty row (`,`).** The raw source test warns about it;
  `stg_airbnb__neighbourhoods` drops it.

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
