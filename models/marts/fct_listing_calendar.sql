{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['listing_id', 'calendar_date'],
        on_schema_change='sync_all_columns',
        cluster_by=['calendar_date']
    )
}}

with calendar as (

    select * from {{ ref('int_airbnb__calendar_enriched') }}

    {% if is_incremental() %}
        -- Incremental runs process recent/new calendar dates. Use full-refresh for new Inside Airbnb snapshots.
        where calendar_date >= (
            select dateadd(day, -7, coalesce(max(calendar_date), '1900-01-01'::date))
            from {{ this }}
        )
    {% endif %}

)

select
    listing_id,
    calendar_date,
    calendar_month,
    is_available,
    calendar_price,
    adjusted_price,
    effective_nightly_price,
    minimum_nights,
    maximum_nights,
    host_id,
    reporting_neighbourhood,
    reporting_neighbourhood_group,
    room_type,
    property_type,
    accommodates,
    estimated_unavailable_night_revenue,
    current_timestamp() as transformed_at

from calendar
