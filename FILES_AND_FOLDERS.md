# Folders and Files Explained

This document explains every folder and every file in the project: what it is, what it does, and how it connects to the others.

Companion documents:

- `PROJECT_GUIDE.md` explains the data and how it flows from the CSV files to the dashboard.
- `HOW_TO_RUN.md` gives the commands to run the project on Mac and Windows.

## Contents

1. [The whole project on one page](#1-the-whole-project-on-one-page)
2. [Which file works at which step](#2-which-file-works-at-which-step)
3. [Files in the project root](#3-files-in-the-project-root)
4. [`data/raw/`: the input data](#4-dataraw-the-input-data)
5. [`setup/`: preparing Snowflake](#5-setup-preparing-snowflake)
6. [`scripts/`: loading the data](#6-scripts-loading-the-data)
7. [`macros/`: reusable SQL](#7-macros-reusable-sql)
8. [`models/`: the transformations](#8-models-the-transformations)
9. [`tests/`: custom data checks](#9-tests-custom-data-checks)
10. [`dashboard/`: the final screen](#10-dashboard-the-final-screen)
11. [Folders and files that appear by themselves](#11-folders-and-files-that-appear-by-themselves)
12. [How the files connect to each other](#12-how-the-files-connect-to-each-other)
13. [Which file do I change?](#13-which-file-do-i-change)
14. [A good order to read the files](#14-a-good-order-to-read-the-files)

---

## 1. The whole project on one page

```text
Snowflake-DBT-Project/
│
├── run_pipeline.py                  Runs the whole project with one command
├── setup_mac.sh                     One-time setup script for Mac
├── setup_windows.bat                One-time setup script for Windows
├── dbt_project.yml                  dbt settings: WHAT to build and how
├── profiles.yml.example             Template for the connection file (Snowflake and DuckDB)
├── profiles.yml                     Your real connection file (private, you create it)
├── requirements.txt                 The Python packages to install (both paths)
├── requirements-duckdb.txt          A smaller list for the free DuckDB path only
├── .gitignore                       Files git must never upload
├── README.md                        Short introduction to the project
├── PROJECT_GUIDE.md                 The data and the pipeline explained end to end
├── HOW_TO_RUN.md                    Commands for Mac and Windows
├── FILES_AND_FOLDERS.md             This document
├── docs/
│   └── INSIDE_AIRBNB_DATASET.md     Where the data comes from, its licence, what changed
│
├── .devcontainer/                   The setup GitHub Codespaces uses (run it in the browser)
├── .github/workflows/               Automatic checks GitHub runs on every change
│
├── data/
│   └── raw/                         The 4 input data files
│       ├── listings.csv.gz
│       ├── calendar.csv.gz
│       ├── reviews.csv.gz
│       └── neighbourhoods.csv
│
├── setup/
│   └── snowflake_setup.sql          Creates the database, warehouse, schemas
│
├── scripts/
│   ├── load_inside_airbnb_to_snowflake.py    Loads the data files into Snowflake
│   ├── load_inside_airbnb_to_duckdb.py       Loads them into DuckDB (the free path)
│   └── verify_duckdb_build.py                Checks a finished DuckDB build
│
├── macros/                          Reusable SQL (functions for dbt)
│   ├── cleaning.sql
│   ├── duckdb_compat.sql
│   └── generate_schema_name.sql
│
├── models/                          The dbt transformations (the heart of the project)
│   ├── staging/                     Layer 1: clean each raw table
│   ├── intermediate/                Layer 2: join and add business columns
│   └── marts/                       Layer 3: final tables for the dashboard
│
├── tests/                           Custom data quality checks
│   ├── assert_no_duplicate_listing_calendar.sql
│   └── assert_non_negative_prices.sql
│
└── dashboard/
    └── streamlit_app.py             The dashboard
```

There are three kinds of file in this project:

| Kind | Ending | Written in | Used by |
| --- | --- | --- | --- |
| Python scripts | `.py` | Python | You run them from the terminal |
| SQL files | `.sql` | SQL, mostly with Jinja | dbt (models, macros, tests) or Snowflake directly (setup) |
| Settings files | `.yml`, `.txt` | YAML or plain text | dbt and pip read them |

---

## 2. Which file works at which step

When you run `python run_pipeline.py`, the files are used in this order.

| Step | What happens | Files that do the work |
| --- | --- | --- |
| 0 | You start the pipeline | `run_pipeline.py` |
| 1 | Snowflake is prepared and the data is loaded | `scripts/load_inside_airbnb_to_snowflake.py`, `setup/snowflake_setup.sql`, `data/raw/*`, `profiles.yml` |
| 2 | dbt checks the connection | `dbt_project.yml`, `profiles.yml` |
| 3 | dbt builds the models | `dbt_project.yml`, everything in `models/` and `macros/` |
| 4 | dbt tests the data | The `.yml` files in `models/`, everything in `tests/` |
| 5 | dbt builds the documentation | The `.yml` files in `models/` (the descriptions) |
| After | You open the dashboard | `dashboard/streamlit_app.py`, `profiles.yml` |

With `python run_pipeline.py --duckdb` (the free path) the same files work, except that step 1 uses `scripts/load_inside_airbnb_to_duckdb.py` in place of the Snowflake loader and `setup/snowflake_setup.sql`, and every dbt command adds `--target duckdb`.

---

## 3. Files in the project root

### `run_pipeline.py`

**What it is:** a Python script. The single entry point of the project.

**What it does:** runs five commands one after another and stops immediately if one fails.

1. `python scripts/load_inside_airbnb_to_snowflake.py`
2. `dbt debug --connection`
3. `dbt run`
4. `dbt test`
5. `dbt docs generate`

**Options:** `--full-refresh` rebuilds the incremental table from zero. `--dashboard` opens the dashboard at the end. `--duckdb` runs everything on DuckDB, the free path, with no Snowflake account.

**Good to know:** it contains no data logic. It only starts other programs. You could type the five commands yourself and get the same result.

### `setup_mac.sh` and `setup_windows.bat`

**What they are:** one-time setup scripts, one per operating system. A `.sh` file is a list of Mac terminal commands. A `.bat` file is a list of Windows commands.

**What they do:** the same three things on both systems.

1. Find a Python version the project supports (3.10 to 3.13).
2. Create the virtual environment `.venv` and install the packages from `requirements.txt` into it.
3. Create `profiles.yml` by copying `profiles.yml.example`, unless you already have one.

**How to run them:** `bash setup_mac.sh` on a Mac. `setup_windows.bat` on Windows.

**Good to know:** you run the setup script once per computer. It is not part of the pipeline, and it never touches Snowflake. The packages it installs cover both paths, so right after setup you can run `python run_pipeline.py --duckdb` without filling in anything.

### `dbt_project.yml`

**What it is:** the main settings file of dbt. A folder is a dbt project because this file is in it.

**What it does:** tells dbt *what* to build and *how*.

| Setting | Value here | Meaning |
| --- | --- | --- |
| `name` | `airbnb_snowflake_dbt` | The project's name |
| `profile` | `airbnb_snowflake` | Which login to use from `profiles.yml` |
| `model-paths` | `models` | Where the models are |
| `macro-paths` | `macros` | Where the macros are |
| `test-paths` | `tests` | Where the custom tests are |
| `staging:` | view, schema `staging` | Staging models become views in `STAGING` |
| `intermediate:` | view, schema `intermediate` | Intermediate models become views in `INTERMEDIATE` |
| `marts:` | table, schema `analytics` | Mart models become tables in `ANALYTICS` |
| `persist_docs` | on | Descriptions are saved in Snowflake as comments |

**Created how:** written by hand. It is not generated.

### `profiles.yml.example`

**What it is:** a template. It has the same layout as `profiles.yml` but with placeholder text instead of real values.

**What it does:** nothing when the project runs. Each person copies it to `profiles.yml` and fills in their own login. It is safe to share because it holds no password.

It holds two targets. `dev` is Snowflake and is the default. `duckdb` is the free path and needs no changes: it points at the file `airbnb.duckdb` in the project folder.

### `profiles.yml`

**What it is:** your private connection file. It is not part of the shared project. You create it yourself.

**What it does:** tells dbt *where* to build: the Snowflake account, user, password, role, database and warehouse.

**Who reads it:** three programs read this one file, so the password is stored in exactly one place.

- dbt
- the loader script
- the dashboard

**Good to know:** it is listed in `.gitignore`, so git never uploads it. Never share it.

### `requirements.txt`

**What it is:** a list of the Python packages the project needs.

**What it does:** `pip install -r requirements.txt` reads it and installs everything. Each line names an exact version (`==`), so everyone gets the same tested setup.

| Package | Why it is needed |
| --- | --- |
| `dbt-core` | dbt itself: the program behind the `dbt` command |
| `dbt-snowflake` | The part that lets dbt talk to Snowflake |
| `snowflake-connector-python` | Lets Python scripts log in to Snowflake and run SQL |
| `dbt-duckdb` | The part that lets dbt talk to DuckDB (the free path) |
| `duckdb` | DuckDB itself, used by the DuckDB loader and the dashboard |
| `pyyaml` | Lets Python read `profiles.yml` |
| `streamlit` | Builds the dashboard |
| `pandas` | Handles tables of data inside the dashboard |
| `altair` | Draws the charts |

`requirements-duckdb.txt` is a shorter list for the free path only (no Snowflake packages). GitHub Codespaces and the automatic checks install that one.

### `.gitignore`

**What it is:** a list of files and folders that git must ignore.

**What it does:** keeps private and generated files out of the shared repository: `profiles.yml` (your password), `.venv/`, `target/`, `logs/`, `.user.yml`, `__pycache__/` and the DuckDB file `airbnb.duckdb`.

### The four documents

| File | What it is for |
| --- | --- |
| `README.md` | The front page: a short summary and links |
| `PROJECT_GUIDE.md` | The data and the pipeline, explained end to end |
| `HOW_TO_RUN.md` | The commands for Mac and Windows |
| `FILES_AND_FOLDERS.md` | This document |
| `docs/INSIDE_AIRBNB_DATASET.md` | Where the data comes from, its licence (CC BY 4.0) and what changed between snapshots |

None of them is used when the project runs. They are for people.

---

## 4. `data/raw/`: the input data

The four files downloaded from Inside Airbnb. They are the only input of the whole project. Nothing in the project changes them.

| File | Rows | Columns | One row is |
| --- | ---: | ---: | --- |
| `listings.csv.gz` | 500 | 90 | One place to stay |
| `calendar.csv.gz` | 182,500 | 5 | One listing on one date |
| `reviews.csv.gz` | 30,251 | 6 | One guest review |
| `neighbourhoods.csv` | 16 | 2 | One neighbourhood name |

`.csv` means comma-separated values: a table saved as text. `.gz` means the file is compressed to save space.

These are the Inside Airbnb files for Albany, New York, from the 14 September 2026 snapshot.

**Who uses them:** only the loader scripts.

---

## 5. `setup/`: preparing Snowflake

### `setup/snowflake_setup.sql`

**What it is:** plain Snowflake SQL. It is not a dbt file and dbt never reads it.

**What it does:** creates the empty containers the project needs.

| It creates | Name | What that is |
| --- | --- | --- |
| A database | `AIRBNB_ANALYTICS` | The container for all project data |
| A warehouse | `COMPUTE_WH` | The compute that runs queries (smallest size, switches itself off after 60 seconds) |
| Four schemas | `RAW`, `STAGING`, `INTERMEDIATE`, `ANALYTICS` | One folder per pipeline layer |
| A stage | `RAW.INSIDE_AIRBNB_STAGE` | A place inside Snowflake to upload files to |
| A file format | `RAW.INSIDE_AIRBNB_CSV_FORMAT` | A saved description of how to read the CSV files |

**Who runs it:** the loader script runs it automatically. You can also paste it into a Snowflake worksheet.

**Good to know:** it is safe to run many times. It never creates the raw tables. The loader does that.

---

## 6. `scripts/`: loading the data

### `scripts/load_inside_airbnb_to_snowflake.py`

**What it is:** a Python script. It is the "Extract and Load" part of the project.

**Why it exists:** dbt can only transform data that is already inside Snowflake. It cannot upload files from a laptop. This script does that part.

**What it does, in order:**

1. Reads the Snowflake login from `profiles.yml`.
2. Runs `setup/snowflake_setup.sql`.
3. For each of the four data files:
   - `PUT` uploads the file into the Snowflake stage.
   - `CREATE OR REPLACE TABLE` creates an empty table with one text column for each column in the file.
   - `COPY INTO` loads the file into that table.
   - It prints how many rows were loaded.

**What it creates in Snowflake:** `RAW.LISTINGS`, `RAW.CALENDAR`, `RAW.REVIEWS`, `RAW.NEIGHBOURHOODS`.

**Good to know:** every raw column is text. Turning text into numbers and dates is the job of the staging models.

### `scripts/load_inside_airbnb_to_duckdb.py`

**What it is:** the free-path version of the loader.

**What it does:** creates the file `airbnb.duckdb` (if it is not there yet) and loads the same four files into its `raw` schema, every column as text, exactly like the Snowflake loader. It needs no login.

### `scripts/verify_duckdb_build.py`

**What it is:** a checking script for the free path.

**What it does:** after a DuckDB build, it opens `airbnb.duckdb` read-only and checks every layer: each raw table has rows, each model exists, the calendar fact has one row per raw calendar row, no listing has a date twice, and the revenue estimate is not empty. Each line starts with `ok` or `FAIL`.

---

## 7. `macros/`: reusable SQL

A macro is a piece of SQL you write once and use in many models, like a function. A macro creates nothing in Snowflake by itself. dbt pastes its SQL into the models that call it.

### `macros/cleaning.sql`

Three macros used by the staging models.

| Macro | Turns this | Into this | Used in |
| --- | --- | --- | --- |
| `clean_price` | `$1,234.50` | `1234.50` | `stg_airbnb__listings`, `stg_airbnb__calendar` |
| `clean_percent` | `98%` | `0.98` | `stg_airbnb__listings` |
| `to_boolean` | `t` / `f` | `true` / `false` | `stg_airbnb__listings`, `stg_airbnb__calendar` |

A model calls a macro like this: `{{ to_boolean('available') }}`.

On DuckDB, `clean_price` adds one small flag to `regexp_replace` so it replaces every match, as Snowflake does. The comment in the file explains it.

This file also has the full explanation of Jinja, the language of the `{{ }}` and `{% %}` brackets.

### `macros/generate_schema_name.sql`

**What it does:** decides the name of the schema each model is built in.

**Why it exists:** by default dbt glues two names together, which would give `ANALYTICS_STAGING`. This macro replaces that rule so the schemas are simply `STAGING`, `INTERMEDIATE` and `ANALYTICS`.

**Good to know:** nobody calls this macro. dbt calls it by itself for every model, because it has this special name.

### `macros/duckdb_compat.sql`

**What it does:** lets the Snowflake SQL in the models run on DuckDB too. DuckDB lacks a few Snowflake functions, such as `try_to_number` and `try_to_date`. This macro creates DuckDB versions with the same names.

**Who calls it:** dbt, before every command, because `dbt_project.yml` names it under `on-run-start`. On Snowflake it produces no SQL at all, so Snowflake runs exactly what you read in the models.

---

## 8. `models/`: the transformations

This folder is the heart of the project. It has two kinds of file.

| Kind | Example | What it holds |
| --- | --- | --- |
| `.sql` | `dim_hosts.sql` | One `SELECT` statement. dbt turns it into a view or table with the same name as the file. |
| `.yml` | `_marts_models.yml` | Descriptions and tests for the `.sql` files in the same folder |

The folder has three subfolders, one per layer. Data moves through them in order.

```text
RAW tables  ->  staging/  ->  intermediate/  ->  marts/  ->  dashboard
```

### 8.1 `models/staging/` (layer 1: clean)

One model per raw table. Each one renames columns, converts text into real data types and turns blanks into NULL. No joins. Built as **views** in the `STAGING` schema.

| File | Reads | Creates | Its job |
| --- | --- | --- | --- |
| `stg_airbnb__listings.sql` | `RAW.LISTINGS` | `STAGING.STG_AIRBNB__LISTINGS` | Keeps 58 of the 90 columns, with clear names and real types |
| `stg_airbnb__calendar.sql` | `RAW.CALENDAR` | `STAGING.STG_AIRBNB__CALENDAR` | Turns `t`/`f` into true/false and text dates into real dates. Adds the two price columns as NULL when the file has none. |
| `stg_airbnb__reviews.sql` | `RAW.REVIEWS` | `STAGING.STG_AIRBNB__REVIEWS` | Cleans the review text and adds its length |
| `stg_airbnb__neighbourhoods.sql` | `RAW.NEIGHBOURHOODS` | `STAGING.STG_AIRBNB__NEIGHBOURHOODS` | Removes the blank row and duplicates |

| File | Its job |
| --- | --- |
| `_staging_sources.yml` | Tells dbt that the four `RAW` tables exist, so models can read them with `source()`. Has 8 tests on the raw data. One of them only warns, because the neighbourhoods file really has one blank row. |
| `_staging_models.yml` | Descriptions and 14 tests for the four staging models |

Staging models are the only ones that read raw tables. They use `source('airbnb_raw', 'listings')`.

`stg_airbnb__calendar.sql` is the best first model to read. Its comments explain what a model is, what `source()` does and how a macro is called.

### 8.2 `models/intermediate/` (layer 2: join and enrich)

These models join the staging models together and add business columns that more than one final table needs. Built as **views** in the `INTERMEDIATE` schema.

| File | Reads | Its job |
| --- | --- | --- |
| `int_airbnb__listing_enriched.sql` | staging listings + staging neighbourhoods | Adds `reporting_neighbourhood`, `host_tenure_days`, `price_band`, `bedroom_bucket` |
| `int_airbnb__calendar_enriched.sql` | staging calendar + enriched listings | Puts the listing's host, ward and room type on every calendar row. Adds `calendar_month` and the revenue estimate. |
| `int_airbnb__reviews_enriched.sql` | staging reviews + enriched listings | Puts the listing's host, ward and room type on every review. Adds `review_month`. |

| File | Its job |
| --- | --- |
| `_intermediate_models.yml` | Descriptions and 8 tests. The tests prove the joins did not duplicate rows. |

From this layer on, models read other models with `ref('model_name')`. `int_airbnb__listing_enriched.sql` has the full explanation of `ref()`.

### 8.3 `models/marts/` (layer 3: final tables)

The tables that people and the dashboard actually query. Built as **tables** in the `ANALYTICS` schema.

| File | Kind | One row is | Rows | Reads |
| --- | --- | --- | ---: | --- |
| `dim_listings.sql` | Dimension | One listing | 500 | `int_airbnb__listing_enriched` |
| `dim_hosts.sql` | Dimension | One host | 200 | `int_airbnb__listing_enriched` |
| `fct_listing_calendar.sql` | Fact (incremental) | One listing on one date | 182,500 | `int_airbnb__calendar_enriched` |
| `fct_reviews.sql` | Fact | One review | 30,251 | `int_airbnb__reviews_enriched` |
| `agg_listing_monthly_performance.sql` | Aggregate | One listing in one month | 6,500 | `fct_listing_calendar` |
| `agg_neighbourhood_monthly_performance.sql` | Aggregate | One ward in one month | 195 | `agg_listing_monthly_performance` |

| File | Its job |
| --- | --- |
| `_marts_models.yml` | Descriptions and 15 tests for the six mart models |

What the three prefixes mean:

- `dim_` is a dimension: it describes things (listings, hosts).
- `fct_` is a fact: it records events on dates (calendar days, reviews).
- `agg_` is an aggregate: a summary calculated in advance to keep the dashboard fast.

`fct_listing_calendar.sql` is the most advanced file in the project. It is the only incremental model, and its comments explain `config()`, `is_incremental()`, `this` and `--full-refresh`.

### 8.4 File naming rules in `models/`

| Pattern | Meaning | Example |
| --- | --- | --- |
| `stg_<source>__<table>.sql` | Staging model | `stg_airbnb__listings.sql` |
| `int_<source>__<what>.sql` | Intermediate model | `int_airbnb__listing_enriched.sql` |
| `dim_<thing>.sql` | Dimension | `dim_hosts.sql` |
| `fct_<event>.sql` | Fact | `fct_reviews.sql` |
| `agg_<summary>.sql` | Aggregate | `agg_listing_monthly_performance.sql` |
| `_<layer>_models.yml` | Descriptions and tests | `_marts_models.yml` |

The leading underscore on the `.yml` files only makes them sort to the top of the folder. dbt reads every `.yml` file whatever its name.

---

## 9. `tests/`: custom data checks

A test is a query that looks for bad rows. If it returns no rows, the test passes.

Most tests in this project (45 of 47) are written in the `.yml` files inside `models/`. They use ready-made checks such as `not_null` and `unique`. The `tests/` folder holds the 2 checks that need their own SQL.

| File | The rule it checks |
| --- | --- |
| `assert_no_duplicate_listing_calendar.sql` | No listing has two rows for the same date in `fct_listing_calendar` |
| `assert_non_negative_prices.sql` | No price is below zero in `dim_listings` or `fct_listing_calendar` |

`dbt test` runs all 47. 46 pass and 1 warns on purpose (the blank neighbourhood row).

---

## 10. `dashboard/`: the final screen

### `dashboard/streamlit_app.py`

**What it is:** a Python script that Streamlit turns into a web page.

**What it does:**

1. Reads `profiles.yml` and decides which database to read: Snowflake, or the DuckDB file on the free path (`-- --duckdb` after the command, or by itself when `profiles.yml` still holds the template's Snowflake values and `airbnb.duckdb` exists).
2. Reads four mart tables: `DIM_LISTINGS`, `DIM_HOSTS`, `AGG_LISTING_MONTHLY_PERFORMANCE`, `AGG_NEIGHBOURHOOD_MONTHLY_PERFORMANCE`.
3. Shows filters in a sidebar, six headline numbers, and four tabs with charts, a map and tables.

**Good to know:** it only reads data. It never changes anything in Snowflake or DuckDB. It is the only file that is not part of `run_pipeline.py` unless you add `--dashboard`.

Start it with `streamlit run dashboard/streamlit_app.py`, or `streamlit run dashboard/streamlit_app.py -- --duckdb` on the free path.

---

## 11. Folders and files that appear by themselves

These are not part of the project you download. They are created when you set up or run it. All of them are ignored by git, and all of them can be deleted and recreated.

| Name | Created by | What is inside | Safe to delete? |
| --- | --- | --- | --- |
| `.venv/` | `python -m venv .venv` | The installed Python packages (about 500 MB) | Yes, but you must install the packages again |
| `target/` | Every dbt command | The SQL that dbt actually sent to Snowflake, and the documentation site | Yes |
| `logs/` | Every dbt command | `dbt.log`, a detailed record of every dbt command | Yes |
| `.user.yml` | dbt, on its first run | An anonymous id for this computer | Yes |
| `__pycache__/` | Python | A faster, prepared copy of the Python scripts | Yes |
| `airbnb.duckdb` | The DuckDB loader (free path) | The whole DuckDB database: raw tables, views and mart tables | Yes. The next `python run_pipeline.py --duckdb` creates it again. |

`target/` is worth opening once. It has two useful subfolders:

- `target/compiled/` shows each model after dbt filled in the Jinja: `ref()` and `source()` are replaced by real table names and macros by real SQL.
- `target/run/` shows the full statement dbt ran, including the `create view` or `create table` part.

---

## 12. How the files connect to each other

Files find each other by **name**. Nothing else links them. If a name is misspelled, the link breaks.

| This | Must match this | What breaks if it does not |
| --- | --- | --- |
| `profile: airbnb_snowflake` in `dbt_project.yml` | The first line `airbnb_snowflake:` in `profiles.yml` | dbt cannot find the login |
| `staging:` / `intermediate:` / `marts:` in `dbt_project.yml` | The folder names inside `models/` | The folder's settings (view or table, schema) are not applied |
| `source('airbnb_raw', 'listings')` in a staging model | `name: airbnb_raw` and `name: listings` in `_staging_sources.yml` | dbt stops: source not found |
| `ref('stg_airbnb__listings')` in a model | The file name `stg_airbnb__listings.sql` | dbt stops: model not found |
| `- name: dim_hosts` in a `.yml` file | The file name `dim_hosts.sql` | The descriptions and tests are not attached to the model |
| `{{ clean_price('price') }}` in a model | `macro clean_price` in `macros/cleaning.sql` | dbt stops: macro not found |
| The table names in `FILES_TO_LOAD` in the loader | The table names in `_staging_sources.yml` | dbt cannot find the raw table in Snowflake |
| The table names in `dashboard/streamlit_app.py` | The model file names in `models/marts/` | The dashboard shows an error: object does not exist |

Who reads what:

```text
run_pipeline.py
   ├── starts  scripts/load_inside_airbnb_to_snowflake.py
   │              ├── reads  profiles.yml
   │              ├── reads  setup/snowflake_setup.sql
   │              └── reads  data/raw/*
   │
   └── starts  dbt  (debug, run, test, docs generate)
                  ├── reads  dbt_project.yml
                  ├── reads  profiles.yml
                  ├── reads  models/**/*.sql  and  models/**/*.yml
                  ├── reads  macros/*.sql
                  └── reads  tests/*.sql

dashboard/streamlit_app.py
   ├── reads  profiles.yml
   └── reads  the ANALYTICS tables in Snowflake (or in airbnb.duckdb on the free path)
```

On the free path, `run_pipeline.py --duckdb` starts `scripts/load_inside_airbnb_to_duckdb.py` (it reads only `data/raw/*`), and dbt also reads `macros/duckdb_compat.sql` through the `on-run-start` hook.

---

## 13. Which file do I change?

| I want to... | Change this file |
| --- | --- |
| Use a different Snowflake account or password | `profiles.yml` |
| Use a different DuckDB file | `path:` under `duckdb:` in `profiles.yml` |
| Build a layer as tables instead of views | `dbt_project.yml` |
| Change how prices or yes/no values are cleaned | `macros/cleaning.sql` |
| Change how a raw column is cleaned or renamed | The matching file in `models/staging/` |
| Change the price band limits or bedroom groups | `models/intermediate/int_airbnb__listing_enriched.sql` |
| Change how revenue is estimated | `models/intermediate/int_airbnb__calendar_enriched.sql` |
| Add or remove a column in a final table | The matching file in `models/marts/` |
| Change a description | The `.yml` file in the same folder as the model |
| Add a simple test (`not_null`, `unique`, ...) | The `.yml` file in the same folder as the model |
| Add a test with its own SQL | A new `.sql` file in `tests/` |
| Load a different city | Replace the files in `data/raw/`, then run `python run_pipeline.py --full-refresh` |
| Change a chart or filter | `dashboard/streamlit_app.py` |
| Add a Python package | `requirements.txt` |

After changing a model, run `dbt run` and `dbt test` again, or simply `python run_pipeline.py`.

---

## 14. A good order to read the files

Every file is commented line by line. This order follows the data and introduces one new idea at a time.

| Order | File | The idea it introduces |
| --- | --- | --- |
| 1 | `data/raw/neighbourhoods.csv` | What raw data looks like |
| 2 | `setup/snowflake_setup.sql` | Database, schema, warehouse, stage |
| 3 | `scripts/load_inside_airbnb_to_snowflake.py` | Loading files into Snowflake |
| 4 | `dbt_project.yml` | What dbt is. Views, tables, layers. |
| 5 | `profiles.yml.example` | How dbt connects to Snowflake |
| 6 | `models/staging/_staging_sources.yml` | Sources and the first tests |
| 7 | `models/staging/stg_airbnb__calendar.sql` | What a model is. `source()`. |
| 8 | `macros/cleaning.sql` | Jinja and macros |
| 9 | `models/intermediate/int_airbnb__listing_enriched.sql` | `ref()` and the build order |
| 10 | `models/marts/dim_hosts.sql` | Dimensions and grouping |
| 11 | `models/marts/fct_listing_calendar.sql` | Facts and incremental models |
| 12 | `models/marts/_marts_models.yml` | Tests and descriptions |
| 13 | `tests/assert_no_duplicate_listing_calendar.sql` | Custom tests |
| 14 | `run_pipeline.py` | The dbt commands |
| 15 | `dashboard/streamlit_app.py` | Using the final tables |
