-- ==============================================================================
-- setup/snowflake_setup.sql  -  create the Snowflake objects the project needs
-- ==============================================================================
-- WHO RUNS THIS?
--   scripts/load_inside_airbnb_to_snowflake.py runs it automatically.
--   You can also paste it into a Snowflake worksheet and run it by hand.
--
-- IS IT SAFE TO RUN TWICE?
--   Yes. Every statement is "idempotent", meaning running it again gives the
--   same end result. "IF NOT EXISTS" skips objects that already exist, and
--   "OR REPLACE" rebuilds objects that are cheap to rebuild.
--
-- SNOWFLAKE OBJECT HIERARCHY (biggest to smallest)
--   ACCOUNT -> DATABASE -> SCHEMA -> TABLE / VIEW / STAGE / FILE FORMAT
--   A full table name therefore has three parts: DATABASE.SCHEMA.TABLE
--
-- NOTE: this is plain Snowflake SQL, not a dbt model. dbt never reads this file.
-- ==============================================================================

-- CREATE DATABASE makes the top-level container for all project data.
-- IF NOT EXISTS: do nothing (and raise no error) when it is already there.
create database if not exists AIRBNB_ANALYTICS;

-- CREATE WAREHOUSE makes a "virtual warehouse", which is Snowflake's name for
-- a compute cluster (the CPUs that run queries). It stores NO data.
-- You pay for a warehouse only while it is running.
create warehouse if not exists COMPUTE_WH
    -- XSMALL is the smallest and cheapest size. Plenty for this dataset.
    warehouse_size = XSMALL
    -- auto_suspend = 60: switch itself off after 60 seconds without queries,
    -- so an idle warehouse costs nothing.
    auto_suspend = 60
    -- auto_resume = true: switch itself back on the moment a query arrives.
    auto_resume = true
    -- initially_suspended = true: create it switched off (no cost until used).
    initially_suspended = true;

-- USE DATABASE sets the "current database" of this session, so the statements
-- below can say RAW.something instead of AIRBNB_ANALYTICS.RAW.something.
use database AIRBNB_ANALYTICS;

-- USE WAREHOUSE picks which compute cluster runs the statements that follow.
use warehouse COMPUTE_WH;

-- A SCHEMA is a folder inside a database. We create one per pipeline layer.

-- RAW: the untouched copy of the CSV files. Loaded by Python, never by dbt.
create schema if not exists RAW;

-- STAGING: dbt's cleaned and typed views, one per raw table.
create schema if not exists STAGING;

-- INTERMEDIATE: dbt's joined and enriched views (building blocks).
create schema if not exists INTERMEDIATE;

-- ANALYTICS: dbt's final dimension, fact and aggregate tables for dashboards.
create schema if not exists ANALYTICS;

-- WHERE ARE THE RAW TABLES?
--   They are not created here. The Python loader creates RAW.LISTINGS,
--   RAW.CALENDAR, RAW.REVIEWS and RAW.NEIGHBOURHOODS by reading the header
--   row of each CSV file, so the table columns always match the file exactly.
--   Every raw column is VARCHAR (text). Converting text into dates, numbers
--   and booleans is the job of the dbt staging models.

-- A STAGE is a file storage area inside Snowflake, like a cloud folder.
-- Loading a local file is always two steps:
--   1) PUT       uploads the file from your laptop into the stage
--   2) COPY INTO reads the staged file and inserts its rows into a table
-- This is an "internal" stage (Snowflake stores the files). An "external"
-- stage would point at your own S3 / Azure / GCS bucket instead.
-- OR REPLACE empties it on every run, so old uploads never pile up.
create or replace stage RAW.INSIDE_AIRBNB_STAGE;

-- A FILE FORMAT is a saved, named description of how to read a file.
-- COPY INTO refers to it by name instead of repeating all these options.
create or replace file format RAW.INSIDE_AIRBNB_CSV_FORMAT
    -- The files are CSV (comma separated values).
    type = CSV
    -- A comma separates one column from the next.
    field_delimiter = ','
    -- Values may be wrapped in double quotes. This is what lets a review
    -- comment contain commas and line breaks without breaking the columns.
    field_optionally_enclosed_by = '"'
    -- By default Snowflake treats a backslash as an "escape" character, which
    -- makes the character after it lose its meaning. One listing title in this
    -- data ends with a backslash, so the comma after it would stop being a
    -- separator and every later column of that row would shift by one.
    -- NONE switches that behaviour off: a backslash is just a backslash.
    escape_unenclosed_field = NONE
    -- The first line holds column names, not data, so skip it.
    skip_header = 1
    -- Ignore completely empty lines.
    skip_blank_lines = true
    -- Treat these exact texts as SQL NULL (meaning "no value").
    null_if = ('', 'NULL', 'null')
    -- An empty field (two commas in a row) also becomes NULL.
    empty_field_as_null = true
    -- AUTO: detect gzip compression from the file itself, so both
    -- .csv and .csv.gz files load with the same format.
    compression = AUTO
    -- false: do not fail when a row has a different number of columns than
    -- the table. Extra columns are ignored and missing ones become NULL.
    error_on_column_count_mismatch = false;
