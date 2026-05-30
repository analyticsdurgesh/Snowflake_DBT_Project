-- ============================================================
-- Airbnb Open Data Snowflake Setup
-- ============================================================
-- Run this script with a role that can create databases, schemas,
-- warehouses, stages, file formats, and tables.

create database if not exists AIRBNB_ANALYTICS;

create warehouse if not exists COMPUTE_WH
    warehouse_size = XSMALL
    auto_suspend = 60
    auto_resume = true
    initially_suspended = true;

use database AIRBNB_ANALYTICS;
use warehouse COMPUTE_WH;

create schema if not exists RAW;
create schema if not exists STAGING;
create schema if not exists INTERMEDIATE;
create schema if not exists ANALYTICS;

-- One reusable stage and CSV format for all Inside Airbnb files.
create or replace stage RAW.INSIDE_AIRBNB_STAGE;

create or replace file format RAW.INSIDE_AIRBNB_CSV_FORMAT
    type = CSV
    field_delimiter = ','
    field_optionally_enclosed_by = '"'
    skip_header = 1
    null_if = ('', 'NULL', 'null')
    empty_field_as_null = true
    compression = AUTO
    error_on_column_count_mismatch = false;

-- Raw tables intentionally store text values. dbt owns casting,
-- cleaning, and business definitions in the transformation layer.
create or replace table RAW.LISTINGS (
    id varchar,
    listing_url varchar,
    scrape_id varchar,
    last_scraped varchar,
    source varchar,
    name varchar,
    description varchar,
    neighborhood_overview varchar,
    picture_url varchar,
    host_id varchar,
    host_url varchar,
    host_profile_id varchar,
    host_profile_url varchar,
    host_name varchar,
    host_since varchar,
    hosts_time_as_user_years varchar,
    hosts_time_as_user_months varchar,
    hosts_time_as_host_years varchar,
    hosts_time_as_host_months varchar,
    host_location varchar,
    host_about varchar,
    host_response_time varchar,
    host_response_rate varchar,
    host_acceptance_rate varchar,
    host_is_superhost varchar,
    host_thumbnail_url varchar,
    host_picture_url varchar,
    host_neighbourhood varchar,
    host_listings_count varchar,
    host_total_listings_count varchar,
    host_verifications varchar,
    host_has_profile_pic varchar,
    host_identity_verified varchar,
    neighbourhood varchar,
    neighbourhood_cleansed varchar,
    neighbourhood_group_cleansed varchar,
    latitude varchar,
    longitude varchar,
    property_type varchar,
    room_type varchar,
    accommodates varchar,
    bathrooms varchar,
    bathrooms_text varchar,
    bedrooms varchar,
    beds varchar,
    amenities varchar,
    price varchar,
    minimum_nights varchar,
    maximum_nights varchar,
    minimum_minimum_nights varchar,
    maximum_minimum_nights varchar,
    minimum_maximum_nights varchar,
    maximum_maximum_nights varchar,
    minimum_nights_avg_ntm varchar,
    maximum_nights_avg_ntm varchar,
    calendar_updated varchar,
    has_availability varchar,
    availability_30 varchar,
    availability_60 varchar,
    availability_90 varchar,
    availability_365 varchar,
    calendar_last_scraped varchar,
    number_of_reviews varchar,
    number_of_reviews_ltm varchar,
    number_of_reviews_l30d varchar,
    availability_eoy varchar,
    number_of_reviews_ly varchar,
    estimated_occupancy_l365d varchar,
    estimated_revenue_l365d varchar,
    first_review varchar,
    last_review varchar,
    review_scores_rating varchar,
    review_scores_accuracy varchar,
    review_scores_cleanliness varchar,
    review_scores_checkin varchar,
    review_scores_communication varchar,
    review_scores_location varchar,
    review_scores_value varchar,
    license varchar,
    instant_bookable varchar,
    calculated_host_listings_count varchar,
    calculated_host_listings_count_entire_homes varchar,
    calculated_host_listings_count_private_rooms varchar,
    calculated_host_listings_count_shared_rooms varchar,
    reviews_per_month varchar
);

create or replace table RAW.CALENDAR (
    listing_id varchar,
    date varchar,
    available varchar,
    price varchar,
    adjusted_price varchar,
    minimum_nights varchar,
    maximum_nights varchar
);

create or replace table RAW.REVIEWS (
    listing_id varchar,
    id varchar,
    date varchar,
    reviewer_id varchar,
    reviewer_name varchar,
    comments varchar
);

create or replace table RAW.NEIGHBOURHOODS (
    neighbourhood_group varchar,
    neighbourhood varchar
);
