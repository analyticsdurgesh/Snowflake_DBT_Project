# Project Guide: From CSV Files to Dashboard

This guide explains the whole project in one place: what it does, what the data is, and what happens to the data at every step. It assumes no knowledge of Snowflake or dbt.

For the commands to run it on Mac or Windows, see [HOW_TO_RUN.md](HOW_TO_RUN.md). For line-by-line explanations, open any file in the project: each one is fully commented.

## Contents

1. [The project in one minute](#1-the-project-in-one-minute)
2. [The tools and what each one does](#2-the-tools-and-what-each-one-does)
3. [The data](#3-the-data)
4. [The journey of the data, step by step](#4-the-journey-of-the-data-step-by-step)
5. [Follow one row through the pipeline](#5-follow-one-row-through-the-pipeline)
6. [The final tables](#6-the-final-tables)
7. [The data quality tests](#7-the-data-quality-tests)
8. [What the data shows](#8-what-the-data-shows)
9. [Limits to keep in mind](#9-limits-to-keep-in-mind)
10. [Glossary](#10-glossary)

---

## 1. The project in one minute

The project takes four raw data files about Airbnb listings in one city and turns them into clean tables and a dashboard that answer questions such as:

- How many listings and hosts are there, and where are they?
- Which neighbourhoods have the least availability?
- Who are the largest hosts?
- How do reviews grow over time?

The data moves through five stops. Each stop has one job.

```text
 data/raw/*.csv        4 files on your laptop
       |
       |   Python loader (scripts/load_inside_airbnb_to_snowflake.py)
       v
 RAW schema            4 tables, an exact copy of the files, every column is text
       |
       |   dbt staging models
       v
 STAGING schema        4 views, same rows, clean names and real data types
       |
       |   dbt intermediate models
       v
 INTERMEDIATE schema   3 views, tables joined together, business columns added
       |
       |   dbt mart models
       v
 ANALYTICS schema      6 tables, final and tested, ready to query
       |
       |   Streamlit (dashboard/streamlit_app.py)
       v
 Dashboard             filters, headline numbers, charts, map, tables
```

One command runs all of it: `python run_pipeline.py`. It takes a minute or two.

No Snowflake account? `python run_pipeline.py --duckdb` runs the same models on DuckDB, a free database that lives in one file on your computer. Everything in this guide applies to both. Where Snowflake says `AIRBNB_ANALYTICS.ANALYTICS.DIM_LISTINGS`, DuckDB says `analytics.dim_listings`.

---

## 2. The tools and what each one does

| Tool | What it is | Its job in this project |
| --- | --- | --- |
| **Snowflake** | A cloud data warehouse: a database built for analysis | Stores every table and runs every query. All the heavy work happens here. |
| **Python loader** | One Python script | Uploads the four files and copies them into Snowflake tables |
| **dbt** | A tool that turns SELECT statements into tables and views | Cleans, joins, summarises, tests and documents the data inside Snowflake |
| **Streamlit** | A Python library for building web dashboards | Reads the final tables and draws the dashboard |

This design is called **ELT**: Extract, Load, Transform. The data is loaded into the warehouse first, unchanged, and transformed afterwards inside the warehouse. The loader does Extract and Load. dbt does Transform.

An important point about dbt: it never moves data. It only sends SQL to Snowflake. You write a `SELECT`, and dbt wraps it in the right `CREATE VIEW`, `CREATE TABLE` or `MERGE` statement and runs the models in the correct order.

Inside Snowflake, objects are nested like folders:

```text
Account
└── Database    AIRBNB_ANALYTICS
    ├── Schema  RAW            <- loaded by Python
    ├── Schema  STAGING        <- built by dbt
    ├── Schema  INTERMEDIATE   <- built by dbt
    └── Schema  ANALYTICS      <- built by dbt, read by the dashboard
```

A full table name has three parts: `AIRBNB_ANALYTICS.ANALYTICS.DIM_LISTINGS`.

---

## 3. The data

### 3.1 Where it comes from

The data comes from [Inside Airbnb](https://insideairbnb.com/get-the-data/), an independent project that collects the listing information anyone can see on the Airbnb website and publishes it as open data, one snapshot per city.

The files in `data/raw/` are one snapshot of **Albany, New York**, published by Inside Airbnb as the **14 September 2026** snapshot. The listings were scraped on 16 September 2026. The files do not name the city. The map coordinates, the fifteen ward names and the most common host location all point to Albany.

A snapshot is a photograph of one moment. It shows what the Airbnb website showed on that day. It is not a record of bookings or payments.

### 3.2 The four files

| File | Rows | Columns | One row is | Identified by |
| --- | ---: | ---: | --- | --- |
| `listings.csv.gz` | 500 | 90 | One place to stay | `id` |
| `calendar.csv.gz` | 182,500 | 5 | One listing on one future date | `listing_id` + `date` |
| `reviews.csv.gz` | 30,251 | 6 | One review written by a guest | `id` |
| `neighbourhoods.csv` | 16 | 2 | One neighbourhood name | `neighbourhood` |

The `.gz` ending means the file is compressed. The loader and Snowflake read compressed files directly.

### 3.3 How the files connect

`listings` is the centre. The other files point at it.

```text
  calendar  ---- listing_id ---->  listings  <---- listing_id ----  reviews
                                      |
                           neighbourhood_cleansed
                                      |
                                      v
                                neighbourhoods
```

| From | Column | Points at | Meaning |
| --- | --- | --- | --- |
| `calendar` | `listing_id` | `listings.id` | Which listing the night belongs to |
| `reviews` | `listing_id` | `listings.id` | Which listing was reviewed |
| `listings` | `neighbourhood_cleansed` | `neighbourhoods.neighbourhood` | Which ward the listing is in |

- Every calendar row and every review row belongs to a listing that exists in the listings file. There are no orphan rows.
- There is no separate file for hosts. Host details are repeated on each listing row. The project builds a host table itself (see `dim_hosts` in section 4).

### 3.4 `listings`: the places to stay

The 90 columns fall into eight groups:

| Group | Example columns | What they tell you |
| --- | --- | --- |
| Identity | `id`, `listing_url`, `name`, `description` | Which listing this is |
| Host | `host_id`, `host_name`, `host_is_superhost`, `host_identity_verified` | Who runs it |
| Location | `neighbourhood_cleansed`, `latitude`, `longitude` | Where it is |
| Property | `property_type`, `room_type`, `accommodates`, `bedrooms`, `beds`, `bathrooms` | What kind of place it is |
| Price | `price`, plus five `price_quote_*` columns | The nightly price, and the price Airbnb quoted for one sample stay |
| Booking rules | `minimum_nights`, `maximum_nights` | How long a guest may stay |
| Availability | `availability_30`, `availability_60`, `availability_90`, `availability_365` | Free nights in the coming days |
| Reviews | `number_of_reviews`, `first_review`, `last_review`, `review_scores_rating` and six detailed scores | How guests rated it |

Facts about this snapshot:

- **500 listings** run by **200 hosts**.
- **Room type:** 352 entire homes or apartments (70.4%), 147 private rooms (29.4%) and 1 shared room. There are no hotel rooms.
- **Size:** the typical listing has 1 bedroom and sleeps 2. The largest sleeps 16.
- **Minimum stay:** 249 listings accept a one-night stay. 49 require 28 nights or more.
- **Price:** 467 listings have a nightly price. The other 33 have none.
- **Ratings:** 449 listings have a rating. The average is 4.74 out of 5. The other 51 listings have no reviews yet, so their rating is empty.

### 3.5 `calendar`: availability for the next year

The calendar looks **forward**. On the day of the scrape, Inside Airbnb recorded the next 365 days for every listing: 16 September 2026 to 15 September 2027.

500 listings x 365 days = 182,500 rows.

| Column | Example | Meaning |
| --- | --- | --- |
| `listing_id` | `2992450` | Which listing |
| `date` | `2026-09-16` | Which night |
| `available` | `t` or `f` | `t` = the night can be booked, `f` = it cannot |
| `minimum_nights`, `maximum_nights` | `28`, `1125` | Stay limits for that date |

Older snapshots also had `price` and `adjusted_price` columns in this file. From this snapshot on, Inside Airbnb no longer publishes them. The staging model notices that the two columns are missing and fills them with NULL, so the rest of the project works the same either way. The price of a night then comes from the listing (see section 3.8).

The single most important thing to understand about this file: **`f` does not mean "booked".** It means "not bookable". A guest may have booked the night, or the host may have blocked it. The data cannot tell the two apart.

Across the year, 126,152 nights are available (69.1%) and 56,348 are not (30.9%).

### 3.6 `reviews`: what guests wrote

Reviews look **backward**. They run from 1 July 2014 to 14 September 2026, just before the scrape.

| Column | Meaning |
| --- | --- |
| `listing_id` | The listing that was reviewed |
| `id` | The review's own id |
| `date` | The day the review was written |
| `reviewer_id`, `reviewer_name` | The guest |
| `comments` | The review text |

A review row has text but **no score**. The scores exist only as averages on the listing (`review_scores_rating`).

The 30,251 reviews were written by 24,877 different guests about 449 listings. Every review has text. The typical review is about 137 characters long.

### 3.7 `neighbourhoods`: the lookup list

A short list of the neighbourhood names used in the city. For Albany these are wards: `FIRST WARD` to `FIFTEENTH WARD`. The file has 16 rows: 15 wards and one blank row. The `neighbourhood_group` column, used in larger cities for boroughs or districts, is empty.

### 3.8 What is missing from this snapshot

Fourteen of the 90 listing columns are completely empty. This is how the snapshot was published. It is not a loading error. The ones that matter:

| Empty in the raw data | Effect in the final tables |
| --- | --- |
| `price` and `adjusted_price` (calendar): the columns are not in the file at all | `calendar_price` and `adjusted_price` are empty, so `effective_nightly_price` falls back to the listing's own `nightly_price` |
| `price` (listings) for 33 of the 500 listings | Those 33 have no `nightly_price`, their `price_band` is `Unknown` and their estimated revenue is 0 |
| `host_since` | `host_since_date` and `host_tenure_days` are empty |
| `host_response_time`, `host_response_rate`, `host_acceptance_rate` | The matching columns are empty |
| `neighbourhood_group_cleansed` | `reporting_neighbourhood_group` is `Unknown` for every listing |
| `instant_bookable`, `license` | `is_instant_bookable` and `license` are empty |

The models keep these columns on purpose. A snapshot of another city, or a later Albany snapshot, may include them, and then the same code fills them in with no changes.

467 listings have a price, so the dashboard shows estimated revenue. If you load a snapshot with no prices at all, it notices and shows unavailable nights instead.

### 3.9 Why the raw data needs cleaning

| Problem in the raw files | Example | Where it is fixed |
| --- | --- | --- |
| Every value arrives as text | `'28'` instead of the number 28 | Staging models cast each column to a real type |
| Yes/no values are letters | `t`, `f` | `to_boolean` macro turns them into true/false |
| Prices and rates are formatted text | `$1,234.00`, `98%` | `clean_price` and `clean_percent` macros |
| Empty text instead of "no value" | `''` | `nullif(trim(x), '')` turns it into NULL |
| Unclear or reserved column names | `id`, `date`, `source` | Renamed to `listing_id`, `calendar_date`, `scrape_source` |
| A blank row in the neighbourhood list | row 16 | Filtered out in `stg_airbnb__neighbourhoods` |
| A listing title ending in a backslash | `...Hideout\` | The file format setting `escape_unenclosed_field = NONE` in `setup/snowflake_setup.sql`. Without it, that row's columns shift by one. |

---

## 4. The journey of the data, step by step

### Step 1: Configuration

Two files tell dbt what to do and where to do it.

- `dbt_project.yml` says **what** to build: where the models are, which schema each folder goes to, and whether a folder is built as views or tables.
- `profiles.yml` says **where** to build: the Snowflake account, user and password. It is private and never committed to git. The loader and the dashboard read the same file, so the password lives in one place.

### Step 2: Load the files into RAW

Script: `scripts/load_inside_airbnb_to_snowflake.py`

First it runs `setup/snowflake_setup.sql`, which creates what the project needs: the database `AIRBNB_ANALYTICS`, the warehouse `COMPUTE_WH` (the compute that runs queries), the four schemas, a stage (a file storage area inside Snowflake) and a file format (a saved description of how to read the CSV files).

Then, for each file, it does three things:

1. `PUT` uploads the file from your laptop into the stage.
2. `CREATE OR REPLACE TABLE` builds an empty table whose columns match the file's header row. Every column is text.
3. `COPY INTO` reads the staged file into the table.

Result: `RAW.LISTINGS`, `RAW.CALENDAR`, `RAW.REVIEWS`, `RAW.NEIGHBOURHOODS`.

Why load everything as text? A load that converts types can fail on one bad value. Loading text never fails, and the raw tables stay an exact copy of the files. Type conversion happens in the next step, where it is visible and tested.

### Step 3: Staging (clean)

Folder: `models/staging/`. Built as: views in the `STAGING` schema.

One staging model per raw table. Each one does the same simple job: rename columns, convert text into numbers, dates and booleans, and turn blanks into NULL. No joins. No business rules. The number of rows does not change (except the one blank neighbourhood row).

| Model | Reads | Rows | What it does |
| --- | --- | ---: | --- |
| `stg_airbnb__listings` | `RAW.LISTINGS` | 500 | Keeps 58 of the 90 columns, renamed and typed |
| `stg_airbnb__calendar` | `RAW.CALENDAR` | 182,500 | `available` becomes `is_available`, `date` becomes `calendar_date`, and the two price columns are added as NULL when the file has none |
| `stg_airbnb__reviews` | `RAW.REVIEWS` | 30,251 | Adds `review_comment_length` and `has_review_comment` |
| `stg_airbnb__neighbourhoods` | `RAW.NEIGHBOURHOODS` | 15 | Removes the blank row and duplicates |

Staging models read raw tables with `source()`. The reusable cleaning logic lives in `macros/cleaning.sql`.

### Step 4: Intermediate (join and enrich)

Folder: `models/intermediate/`. Built as: views in the `INTERMEDIATE` schema.

These models combine staging models and add columns that several final tables need, so each rule is written once.

| Model | Combines | What it adds |
| --- | --- | --- |
| `int_airbnb__listing_enriched` | listings + neighbourhoods | `reporting_neighbourhood` (never empty), `host_tenure_days`, `price_band`, `bedroom_bucket` |
| `int_airbnb__calendar_enriched` | calendar + enriched listings | The listing's host, ward and room type on every calendar row, plus `calendar_month`, `effective_nightly_price`, `estimated_unavailable_night_revenue` |
| `int_airbnb__reviews_enriched` | reviews + enriched listings | The listing's host, ward and room type on every review, plus `review_month` |

From this step on, models read each other with `ref()`. That is how dbt learns the order to build things in.

### Step 5: Marts (final tables)

Folder: `models/marts/`. Built as: tables in the `ANALYTICS` schema.

These are the tables people actually query. There are three kinds, shown by the prefix.

| Model | Kind | One row is | Rows |
| --- | --- | --- | ---: |
| `dim_listings` | Dimension | One listing | 500 |
| `dim_hosts` | Dimension | One host | 200 |
| `fct_listing_calendar` | Fact | One listing on one date | 182,500 |
| `fct_reviews` | Fact | One review | 30,251 |
| `agg_listing_monthly_performance` | Aggregate | One listing in one month | 6,500 |
| `agg_neighbourhood_monthly_performance` | Aggregate | One ward in one month | 195 |

- A **dimension** describes a thing: who, what, where.
- A **fact** records events or measurements: something that happened on a date.
- An **aggregate** is a summary calculated in advance so the dashboard stays fast.

Four details worth knowing:

- `dim_hosts` does not exist in the raw data. It is created by grouping the 500 listing rows by `host_id`, which gives 200 rows.
- On Snowflake, dbt creates these as *transient* tables, a Snowflake table type without the extra backup period. That is the dbt default, because dbt can rebuild any table from its model. DuckDB has no such type and creates ordinary tables.
- `fct_listing_calendar` is the only **incremental** model. The first run loads every row. Later runs process only recent dates and merge them in, instead of rebuilding the whole table. Its file explains this in detail.
- The row counts of the aggregates can be checked by hand. The calendar covers 13 calendar months (September 2026 to September 2027). 500 listings x 13 months = 6,500. 15 wards x 13 months = 195.

The complete list of what is built from what. dbt works out the build order from this by itself, using the `source()` and `ref()` calls in each file. Read each line as "the model on the left is built from what is on the right".

```text
stg_airbnb__listings                    <- RAW.LISTINGS
stg_airbnb__calendar                    <- RAW.CALENDAR
stg_airbnb__reviews                     <- RAW.REVIEWS
stg_airbnb__neighbourhoods              <- RAW.NEIGHBOURHOODS

int_airbnb__listing_enriched            <- stg_airbnb__listings + stg_airbnb__neighbourhoods
int_airbnb__calendar_enriched           <- stg_airbnb__calendar + int_airbnb__listing_enriched
int_airbnb__reviews_enriched            <- stg_airbnb__reviews  + int_airbnb__listing_enriched

dim_listings                            <- int_airbnb__listing_enriched
dim_hosts                               <- int_airbnb__listing_enriched
fct_listing_calendar                    <- int_airbnb__calendar_enriched
fct_reviews                             <- int_airbnb__reviews_enriched
agg_listing_monthly_performance         <- fct_listing_calendar
agg_neighbourhood_monthly_performance   <- agg_listing_monthly_performance
```

The README shows the same thing as a graph.

### Step 6: Test

Command: `dbt test`. It runs 47 checks against the data that was just built. Section 7 lists them.

### Step 7: Document

Command: `dbt docs generate`. It builds a small website with every model, column description and the lineage graph. Open it with `dbt docs serve --profiles-dir .`. The descriptions are also saved in Snowflake as comments on the tables and columns.

### Step 8: Dashboard

File: `dashboard/streamlit_app.py`. Command: `streamlit run dashboard/streamlit_app.py`, or `streamlit run dashboard/streamlit_app.py -- --duckdb` on the free path.

The dashboard reads four of the six mart tables: both aggregates and both dimensions. It only runs `SELECT` queries. It never changes data.

| Part | What it shows |
| --- | --- |
| Sidebar | Filters: start and end month, neighbourhoods, room types, price bands, minimum reviews, superhosts only, available in the next 30 days |
| Headline row | Listings, hosts, average price, average rating, availability, and estimated revenue (or unavailable nights when a snapshot has no prices) |
| Market Overview tab | Trend by month, listings by room type, price against reviews, map of listings |
| Neighbourhoods tab | Ward comparison charts and table |
| Listings tab | A searchable table of listings with links to Airbnb |
| Hosts tab | The largest hosts and a host table |

---

## 5. Follow one row through the pipeline

Take one real line from `calendar.csv.gz`:

```text
2992450,2026-09-16,f,28,1125
```

It says: listing 2992450, on the night of 16 September 2026, is not available. The minimum stay is 28 nights and the maximum is 1,125. The line has no price, because this snapshot's calendar has no price columns.

**Stop 1: `RAW.CALENDAR`.** An exact copy. Every value is text.

| LISTING_ID | DATE | AVAILABLE | MINIMUM_NIGHTS | MAXIMUM_NIGHTS |
| --- | --- | --- | --- | --- |
| `'2992450'` | `'2026-09-16'` | `'f'` | `'28'` | `'1125'` |

**Stop 2: `STAGING.STG_AIRBNB__CALENDAR`.** The same row with real types and clearer names. The two price columns are added, empty, so every later model can rely on them.

| LISTING_ID | CALENDAR_DATE | IS_AVAILABLE | CALENDAR_PRICE | ADJUSTED_PRICE | MINIMUM_NIGHTS | MAXIMUM_NIGHTS |
| --- | --- | --- | --- | --- | --- | --- |
| 2992450 (number) | 2026-09-16 (date) | false (boolean) | NULL | NULL | 28 (number) | 1125 (number) |

**Stop 3: `INTERMEDIATE.INT_AIRBNB__CALENDAR_ENRICHED`.** The row is joined to its listing, so it now knows where the listing is and who runs it. New columns are calculated.

| Column | Value | Where it came from |
| --- | --- | --- |
| `calendar_month` | 2026-09-01 | The date moved back to the first day of its month |
| `host_id` | 4621559 | The listing |
| `reporting_neighbourhood` | THIRD WARD | The listing |
| `room_type` | Entire home/apt | The listing |
| `property_type` | Entire rental unit | The listing |
| `accommodates` | 4 | The listing |
| `effective_nightly_price` | 65.73 | The calendar has no price, so the listing's own price ($65.73) is used |
| `estimated_unavailable_night_revenue` | 65.73 | The night is unavailable, so the model counts it as booked at that price |

**Stop 4: `ANALYTICS.FCT_LISTING_CALENDAR`.** The same row, now stored in a real table, with one extra column `transformed_at` recording when dbt wrote it.

**Stop 5: `ANALYTICS.AGG_LISTING_MONTHLY_PERFORMANCE`.** The row is no longer visible on its own. It has been counted into its month, together with the listing's other September rows.

| LISTING_ID | CALENDAR_MONTH | CALENDAR_DAYS | AVAILABLE_DAYS | UNAVAILABLE_DAYS | AVAILABILITY_RATE | ESTIMATED_UNAVAILABLE_REVENUE |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 2992450 | 2026-09-01 | 15 | 0 | 15 | 0.00 | 985.95 |

September has only 15 days here because the calendar starts on the 16th. Our row is one of the 15 unavailable days: 15 x $65.73 = $985.95.

**Stop 6: `ANALYTICS.AGG_NEIGHBOURHOOD_MONTHLY_PERFORMANCE`.** The listing's month is added to the months of the other 30 listings in the Third Ward.

| REPORTING_NEIGHBOURHOOD | CALENDAR_MONTH | ACTIVE_LISTING_COUNT | CALENDAR_DAYS | AVAILABLE_DAYS | UNAVAILABLE_DAYS | AVAILABILITY_RATE |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| THIRD WARD | 2026-09-01 | 31 | 465 | 243 | 222 | 0.523 |

31 listings x 15 days = 465 calendar days. Our row is one of the 222 unavailable ones.

**Stop 7: the dashboard.** That row is now part of the Third Ward's bar on the Neighbourhoods tab and part of the "Est. Revenue" headline number.

The same listing also appears elsewhere: as one row in `dim_listings` (2-3 bedrooms, rating 3.56, 9 reviews), as the only listing of its host in `dim_hosts`, and as 9 rows in `fct_reviews`.

---

## 6. The final tables

These six tables in `AIRBNB_ANALYTICS.ANALYTICS` (on DuckDB: the `analytics` schema of `airbnb.duckdb`) are the product of the project.

| Table | One row is | Rows | Columns | Key | Use it for |
| --- | --- | ---: | ---: | --- | --- |
| `DIM_LISTINGS` | A listing | 500 | 48 | `listing_id` | Describing, filtering and mapping listings |
| `DIM_HOSTS` | A host | 200 | 15 | `host_id` | Host size, superhost status, total reviews |
| `FCT_LISTING_CALENDAR` | A listing on a date | 182,500 | 17 | `listing_id` + `calendar_date` | Day-level availability |
| `FCT_REVIEWS` | A review | 30,251 | 13 | `review_id` | Review counts over time, review text |
| `AGG_LISTING_MONTHLY_PERFORMANCE` | A listing in a month | 6,500 | 12 | `listing_id` + `calendar_month` | Monthly availability per listing |
| `AGG_NEIGHBOURHOOD_MONTHLY_PERFORMANCE` | A ward in a month | 195 | 10 | `reporting_neighbourhood` + `calendar_month` | Comparing wards over time |

How they connect:

```text
   DIM_HOSTS  <---- host_id ----  DIM_LISTINGS
                                       ^
                                       |  listing_id
                   +-------------------+-------------------+
                   |                                       |
          FCT_LISTING_CALENDAR                        FCT_REVIEWS
                   |
                   |  summarised by month
                   v
       AGG_LISTING_MONTHLY_PERFORMANCE
                   |
                   |  summarised by ward
                   v
     AGG_NEIGHBOURHOOD_MONTHLY_PERFORMANCE
```

Both fact tables also carry `host_id`, the ward and the room type of each listing, so most questions need no join.

Queries to try in a Snowflake worksheet. On DuckDB, leave out `AIRBNB_ANALYTICS.` and write the lower-case name, for example `analytics.agg_listing_monthly_performance`. [HOW_TO_RUN.md](HOW_TO_RUN.md) Part 5 shows where to type them.

```sql
-- Which wards have the most listings, and how available are they?
select
    reporting_neighbourhood,
    count(distinct listing_id)                            as listings,
    sum(unavailable_days)                                 as unavailable_nights,
    round(sum(available_days) / sum(calendar_days), 3)    as availability_rate
from AIRBNB_ANALYTICS.ANALYTICS.AGG_LISTING_MONTHLY_PERFORMANCE
group by reporting_neighbourhood
order by listings desc;

-- How many reviews were written each year?
select
    year(review_date) as review_year,
    count(*)          as reviews
from AIRBNB_ANALYTICS.ANALYTICS.FCT_REVIEWS
group by review_year
order by review_year;

-- Who are the ten largest hosts?
select host_id, listing_count, total_reviews, is_superhost
from AIRBNB_ANALYTICS.ANALYTICS.DIM_HOSTS
order by listing_count desc
limit 10;
```

---

## 7. The data quality tests

`dbt test` runs 47 checks. Each check is a query that looks for bad rows. If it finds none, the test passes. On this data 46 pass and 1 gives a warning on purpose: the blank row in `neighbourhoods.csv` (see 3.7). A warning is reported but does not stop the run.

| Layer | Tests | Examples of what is proven |
| --- | ---: | --- |
| Raw sources | 8 | Listing ids and review ids are never empty and never repeated. Neighbourhood names are never empty: this one is set to warn, because the file really does have one blank row. |
| Staging | 14 | `room_type` holds only the four allowed values. Every calendar row and every review points at a listing that exists. |
| Intermediate | 8 | The joins did not duplicate any listing or review. `reporting_neighbourhood` is never empty. |
| Marts | 15 | One row per listing in `dim_listings`, one row per host in `dim_hosts`, one row per review in `fct_reviews` |
| Custom SQL tests | 2 | No listing has two rows for the same date. No price is negative. |

There are two kinds of test:

- **Generic tests** are named in the `.yml` files next to the models: `not_null`, `unique`, `accepted_values`, `relationships`. dbt writes the SQL.
- **Singular tests** are `.sql` files in the `tests/` folder, written by hand for rules the generic tests cannot express.

Why test the same thing at several layers? Because each layer can break it. A join in the intermediate layer can duplicate rows even when staging was perfect. Testing after each step shows exactly where a problem started.

---

## 8. What the data shows

All numbers come from the final tables for this snapshot.

**Listings and hosts**

- 500 listings are run by 200 hosts.
- 118 hosts (59%) have a single listing. 23 hosts have five or more. The largest host has 31.
- 227 listings (45%) are run by a superhost.
- Seven in ten listings are entire homes or apartments. Almost three in ten are private rooms. There is one shared room.

**Where the listings are**

- The Sixth Ward has 116 listings, almost a quarter of the city's total. The Tenth Ward (57), then the Second and Ninth Wards (45 each) follow.
- The Twelfth Ward has only 4.

**Prices**

- 467 of the 500 listings have a nightly price. The median is $144: $170 for an entire home and $75 for a private room.
- Price bands: 72 Budget (under $75), 265 Mid-range ($75 to $199), 116 Premium ($200 to $499), 14 Luxury ($500 or more) and 33 Unknown (no price).
- Five listings ask $11,680 a night. They lift the average price to $293, far above the median, but they add only 0.4% of the estimated revenue.

**Availability over the next year**

- 69.1% of all listing-nights can still be booked. 30.9% cannot.
- Private rooms are a little less available (66.6%) than entire homes (70.3%).
- The least available wards are the Fourth (52.5%), Thirteenth (55.7%) and Eighth (55.9%). The most available is the Eleventh (91.1%).
- The nearest weeks are the least available: 49.0% for the second half of September 2026 and 64.5% in October. From November to May availability is 72% to 77%, and it falls to about 62% to 66% in summer 2027.
- 50 listings are available on every one of the 365 days. 18 are unavailable on all of them.

**Reviews**

- 30,251 reviews from 24,877 guests, starting in July 2014.
- The number of reviews has grown in every full year except 2020: 1,653 in 2019, 1,186 in 2020, 5,841 in 2025.
- Rated listings average 4.74 out of 5. Half of them score 4.87 or higher.
- 51 listings have no reviews at all.

---

## 9. Limits to keep in mind

- **A night's price is the listing's price.** The calendar in this snapshot has no prices, so every night of a listing gets the same price, whatever the season. 33 listings have no price at all and count as $0. Treat every money figure as a rough estimate.
- **Unavailable does not mean booked.** A host can block nights for any reason. The "estimated revenue" logic assumes every unavailable night was booked, so even with prices it would be an upper estimate, not a measurement.
- **It is one moment in time.** The snapshot shows the website on 16 September 2026. It cannot show how a listing changed, or which listings existed before and were removed.
- **The calendar and the reviews do not overlap.** The calendar covers the year after the scrape. The reviews cover the years before it. They cannot be joined by date to compare stays with reviews.
- **Reviews are not bookings.** Not every guest writes a review, so review counts undercount stays.
- **Several host columns are empty**, including the date each host joined and their response rates.
- **Loading a new snapshot needs a full refresh.** `fct_listing_calendar` is incremental and keeps rows from earlier runs. After replacing the files in `data/raw/`, run `python run_pipeline.py --full-refresh` so rows from the old snapshot do not survive.

---

## 10. Glossary

| Term | Meaning |
| --- | --- |
| **Aggregate** | A table that summarises a more detailed table, for example days summed into months |
| **CTE** | Common Table Expression. A named step inside a query, written `with name as ( select ... )` |
| **DAG** | Directed Acyclic Graph. The map of which model depends on which. dbt uses it to decide the build order. |
| **Data warehouse** | A database designed for analysing large amounts of data |
| **Dimension** | A table that describes things (listings, hosts). Prefix `dim_`. |
| **ELT** | Extract, Load, Transform. Load raw data first, transform it inside the warehouse. |
| **Fact** | A table that records events or measurements (calendar days, reviews). Prefix `fct_`. |
| **Grain** | What one row of a table represents |
| **Incremental model** | A table that dbt updates with new rows only, instead of rebuilding it |
| **Jinja** | The templating language inside dbt SQL files, written with `{{ }}` and `{% %}` |
| **Macro** | A reusable piece of SQL, like a function |
| **Mart** | A final, business-ready table |
| **Materialization** | How dbt stores a model: view, table, incremental or ephemeral |
| **Model** | One `.sql` file containing one `SELECT`. dbt turns it into a view or table. |
| **NULL** | SQL's marker for "no value" |
| **Primary key** | The column, or columns, that identify one row |
| **`ref()`** | How one dbt model points at another dbt model |
| **Schema** | A folder for tables and views inside a database |
| **Snapshot** | In this guide: one dated copy of the Inside Airbnb data for a city |
| **`source()`** | How a dbt model points at a raw table that dbt did not build |
| **Stage** | A file storage area inside Snowflake, used when loading files |
| **View** | A saved query. It stores no data and runs each time it is read. |
| **Warehouse (Snowflake)** | The compute that runs queries. It stores no data. |
