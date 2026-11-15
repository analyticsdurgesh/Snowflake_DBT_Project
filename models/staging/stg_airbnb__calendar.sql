{#-
  Schema drift, handled on purpose. Inside Airbnb stopped publishing calendar
  prices: `price` and `adjusted_price` were empty in early-2026 files and are
  gone from calendar.csv altogether in the 2026-09-14 snapshot. So this model
  asks the warehouse which columns RAW.CALENDAR really has and reads the price
  columns only when they exist. Either way the downstream models work:
  int_airbnb__calendar_enriched falls back to the listing's nightly price.
  (`execute` is false while dbt only parses the project, when it must not query.)
-#}
{%- set calendar_columns = [] -%}
{%- if execute -%}
    {%- set calendar_columns = adapter.get_columns_in_relation(source('airbnb_raw', 'calendar')) | map(attribute='name') | map('lower') | list -%}
{%- endif -%}

with source as (

    select * from {{ source('airbnb_raw', 'calendar') }}

),

cleaned as (

    select
        listing_id::number as listing_id,
        try_to_date(date) as calendar_date,
        {{ to_boolean('available') }} as is_available,
        {% if 'price' in calendar_columns -%} {{ clean_price('price') }} {%- else -%} cast(null as decimal(18, 2)) {%- endif %} as calendar_price,
        {% if 'adjusted_price' in calendar_columns -%} {{ clean_price('adjusted_price') }} {%- else -%} cast(null as decimal(18, 2)) {%- endif %} as adjusted_price,
        try_to_number(minimum_nights) as minimum_nights,
        try_to_number(maximum_nights) as maximum_nights

    from source

)

select * from cleaned
