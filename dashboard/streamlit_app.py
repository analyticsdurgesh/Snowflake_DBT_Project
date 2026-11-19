"""
================================================================================
dashboard/streamlit_app.py  -  the dashboard (the last step of the pipeline)
================================================================================
WHAT THIS FILE DOES
    It reads the final dbt tables from the ANALYTICS schema in Snowflake and
    shows them as an interactive web page: filters, KPI numbers, charts, a map
    and tables.

    CSV files -> RAW -> STAGING -> INTERMEDIATE -> ANALYTICS -> this dashboard
                 (loader)        (dbt builds these)            (reads only)

    The dashboard never changes data. It only runs SELECT queries on the marts.

HOW TO RUN IT
    streamlit run dashboard/streamlit_app.py
    Your browser opens http://localhost:8501. Press Ctrl+C in the terminal to stop.

HOW STREAMLIT WORKS (important for reading this file)
    Streamlit runs this whole script from the first line to the last line and
    draws each "st." call on the page in that order. Every time the user
    changes a filter, Streamlit runs the WHOLE script again with the new
    values. There are no callbacks or page routes: the page is the script.
    Caching (see the two @st.cache decorators) keeps those re-runs fast.

STRUCTURE OF THIS FILE
    1. Imports and constants
    2. Snowflake connection and query helpers
    3. Small formatting helpers
    4. Load the four mart tables
    5. Sidebar filters
    6. Apply the filters
    7. KPI row
    8. Four tabs: Market Overview, Neighbourhoods, Listings, Hosts
================================================================================
"""

# ------------------------------------------------------------------------------
# 1. IMPORTS AND CONSTANTS
# ------------------------------------------------------------------------------

# Store type hints as text so modern hint syntax works on older Python versions.
from __future__ import annotations

# Path = an object for file paths that works on every operating system.
from pathlib import Path

# altair = the charting library. "as alt" gives it a short nickname.
import altair as alt

# pandas = the DataFrame library. A DataFrame is a table held in memory.
import pandas as pd

# The official Snowflake driver, used to log in and run SQL.
import snowflake.connector

# streamlit = the dashboard framework. Every "st." call below draws something.
import streamlit as st

# yaml = reads profiles.yml, the file holding the Snowflake login.
import yaml


# This file is in dashboard/, so parents[1] is the project root.
PROJECT_ROOT = Path(__file__).resolve().parents[1]

# The connection file. dbt and the loader read the very same file.
PROFILES_FILE = PROJECT_ROOT / "profiles.yml"

# The profile name. It must match "profile:" in dbt_project.yml.
PROFILE_NAME = "airbnb_snowflake"

# The schema dbt builds the mart tables in (see "+schema: analytics" in dbt_project.yml).
MART_SCHEMA = "ANALYTICS"

# set_page_config must be the FIRST Streamlit command of the script.
# page_title is the browser tab text. layout="wide" uses the full window width.
st.set_page_config(page_title="Airbnb Market Dashboard", layout="wide")


# ------------------------------------------------------------------------------
# 2. SNOWFLAKE CONNECTION AND QUERY HELPERS
# ------------------------------------------------------------------------------

def load_snowflake_settings() -> dict:
    """Read profiles.yml and return the connection settings of the active target."""

    # Without profiles.yml there is nothing to connect with.
    if not PROFILES_FILE.exists():
        # st.error shows a red message box on the page.
        st.error("Missing profiles.yml. Copy profiles.yml.example to profiles.yml and fill in your Snowflake values.")
        # st.stop ends this run of the script. Nothing below it is executed.
        st.stop()

    # Turn the YAML text into Python dictionaries.
    profiles = yaml.safe_load(PROFILES_FILE.read_text(encoding="utf-8"))

    # Take our profile, then the output named by its "target:" line (dev).
    profile = profiles[PROFILE_NAME]
    return profile["outputs"][profile["target"]]


# Read the settings once and keep them in a module-level variable.
SETTINGS = load_snowflake_settings()

# The database holding the marts. .get(key, default) falls back to the default.
DATABASE = str(SETTINGS.get("database", "AIRBNB_ANALYTICS"))


# A "decorator" (the line starting with @) wraps the function below it.
# @st.cache_resource runs the function ONCE and reuses the returned object on
# every later script re-run. Without it, each filter click would log in again.
# show_spinner=False hides the default "Running..." message.
@st.cache_resource(show_spinner=False)
def get_connection():
    """Open one Snowflake connection and reuse it for the whole session."""

    return snowflake.connector.connect(
        # Account, user and password come from profiles.yml.
        account=SETTINGS["account"],
        user=SETTINGS["user"],
        password=SETTINGS["password"],
        # The role decides what this session may read.
        role=SETTINGS.get("role", "ACCOUNTADMIN"),
        # The warehouse is the compute that runs the queries.
        warehouse=SETTINGS.get("warehouse", "COMPUTE_WH"),
        # Default database and schema for the session.
        database=DATABASE,
        schema=MART_SCHEMA,
    )


# @st.cache_data remembers the RESULT of a function for each distinct input.
# The same SQL text asked again returns the saved DataFrame without touching
# Snowflake. ttl=600 throws the saved copy away after 600 seconds (10 minutes),
# so new data appears at the latest ten minutes after a dbt run.
@st.cache_data(ttl=600, show_spinner=False)
def run_query(sql: str) -> pd.DataFrame:
    """Run one SQL query in Snowflake and return the result as a DataFrame."""

    # A cursor sends SQL and receives results. "with" closes it automatically.
    with get_connection().cursor() as cursor:
        # Send the query to Snowflake.
        cursor.execute(sql)
        # Download every result row as a pandas DataFrame.
        # Snowflake returns column names in UPPER CASE, which is why the rest
        # of this file writes names such as "CALENDAR_MONTH".
        return cursor.fetch_pandas_all()


def table_name(model_name: str) -> str:
    """Return the full three-part Snowflake name: DATABASE.SCHEMA.TABLE."""

    # An f-string puts the values of the variables into the text.
    return f"{DATABASE}.{MART_SCHEMA}.{model_name}"


# ------------------------------------------------------------------------------
# 3. SMALL FORMATTING HELPERS
# ------------------------------------------------------------------------------

def money(value: float | int | None) -> str:
    """Format a number as whole dollars, for example 1234.5 -> $1,234."""

    # pd.isna is true for missing values (None or NaN).
    if pd.isna(value):
        return "n/a"
    # ",.0f" = thousands separators and zero decimal places.
    return f"${value:,.0f}"


def pct(value: float | int | None) -> str:
    """Format a rate as a percentage, for example 0.256 -> 25.6%."""

    if pd.isna(value):
        return "n/a"
    # ".1%" multiplies by 100, keeps one decimal place and adds the % sign.
    return f"{value:.1%}"


def number(value: float | int | None) -> str:
    """Format a number with thousands separators, for example 12345 -> 12,345."""

    if pd.isna(value):
        return "n/a"
    return f"{value:,.0f}"


def prepare_dates(df: pd.DataFrame, columns: list[str]) -> pd.DataFrame:
    """Convert the named columns of a DataFrame into real datetime values."""

    # Work on a copy so the cached original is never modified.
    copy = df.copy()
    # Go through the requested column names one by one.
    for column in columns:
        # Skip a name that is not in this table.
        if column in copy.columns:
            # errors="coerce" turns unreadable values into NaT (missing date)
            # instead of raising an error.
            copy[column] = pd.to_datetime(copy[column], errors="coerce")
    return copy


def to_float(df: pd.DataFrame, columns: list[str]) -> pd.DataFrame:
    """Convert the named columns into ordinary floating-point numbers."""

    # Snowflake DECIMAL columns arrive as Python Decimal objects. pandas and
    # the charts work best with plain floats, so convert them once here.
    copy = df.copy()
    for column in columns:
        if column in copy.columns:
            copy[column] = pd.to_numeric(copy[column], errors="coerce").astype(float)
    return copy


def pick_columns(df: pd.DataFrame, columns: list[str]) -> pd.DataFrame:
    """Return a copy of the DataFrame with only the requested columns, in order."""

    # The list comprehension keeps a name only if the table really has it.
    return df[[column for column in columns if column in df.columns]].copy()


# ------------------------------------------------------------------------------
# 4. LOAD THE FOUR MART TABLES
# Each block sends one SELECT to Snowflake and cleans the result for pandas.
# The triple-quoted f-string holds the SQL text.
# ------------------------------------------------------------------------------

# Neighbourhood + month numbers, built by agg_neighbourhood_monthly_performance.sql.
monthly = run_query(
    f"""
    select
        reporting_neighbourhood_group,
        reporting_neighbourhood,
        calendar_month,
        active_listing_count,
        calendar_days,
        available_days,
        unavailable_days,
        availability_rate,
        avg_effective_nightly_price,
        estimated_unavailable_revenue
    from {table_name('AGG_NEIGHBOURHOOD_MONTHLY_PERFORMANCE')}
    """
)
# Turn the month column into real dates so it can be filtered and plotted.
monthly = prepare_dates(monthly, ["CALENDAR_MONTH"])
# Turn the decimal columns into floats.
monthly = to_float(monthly, ["AVAILABILITY_RATE", "AVG_EFFECTIVE_NIGHTLY_PRICE", "ESTIMATED_UNAVAILABLE_REVENUE"])

# Listing + month numbers, built by agg_listing_monthly_performance.sql.
listing_monthly = run_query(
    f"""
    select
        listing_id,
        host_id,
        calendar_month,
        reporting_neighbourhood,
        reporting_neighbourhood_group,
        room_type,
        calendar_days,
        available_days,
        unavailable_days,
        availability_rate,
        avg_effective_nightly_price,
        estimated_unavailable_revenue
    from {table_name('AGG_LISTING_MONTHLY_PERFORMANCE')}
    """
)
listing_monthly = prepare_dates(listing_monthly, ["CALENDAR_MONTH"])
listing_monthly = to_float(
    listing_monthly, ["AVAILABILITY_RATE", "AVG_EFFECTIVE_NIGHTLY_PRICE", "ESTIMATED_UNAVAILABLE_REVENUE"]
)

# One row per listing, built by dim_listings.sql.
listings = run_query(
    f"""
    select
        listing_id,
        listing_url,
        listing_name,
        host_id,
        host_name,
        is_superhost,
        reporting_neighbourhood,
        reporting_neighbourhood_group,
        latitude,
        longitude,
        property_type,
        room_type,
        accommodates,
        bedrooms,
        nightly_price,
        price_band,
        availability_30,
        number_of_reviews,
        review_scores_rating,
        is_instant_bookable
    from {table_name('DIM_LISTINGS')}
    """
)
listings = to_float(listings, ["LATITUDE", "LONGITUDE", "NIGHTLY_PRICE", "REVIEW_SCORES_RATING"])

# One row per host, built by dim_hosts.sql.
hosts = run_query(
    f"""
    select
        host_id,
        host_name,
        host_location,
        is_superhost,
        host_identity_verified,
        host_response_rate,
        host_acceptance_rate,
        listing_count,
        entire_home_listing_count,
        private_room_listing_count,
        avg_nightly_price,
        total_reviews
    from {table_name('DIM_HOSTS')}
    """
)
hosts = to_float(hosts, ["HOST_RESPONSE_RATE", "HOST_ACCEPTANCE_RATE", "AVG_NIGHTLY_PRICE"])

# .empty is True when a DataFrame has no rows. Empty marts mean the pipeline
# has not been run yet, so explain that instead of showing broken charts.
if monthly.empty or listings.empty:
    st.error("The mart tables are empty. Run  python run_pipeline.py  first.")
    st.stop()

# The big page heading.
st.title("Airbnb Market Dashboard")
# A smaller grey line under the heading.
st.caption("Snowflake + dbt analytics for listings, hosts, availability, prices, and neighbourhood performance.")


# ------------------------------------------------------------------------------
# 5. SIDEBAR FILTERS
# Everything inside "with st.sidebar:" is drawn in the panel on the left.
# Each widget returns the value the user currently has selected.
# ------------------------------------------------------------------------------
with st.sidebar:
    # A heading inside the sidebar.
    st.header("Filters")

    # Build the list of months present in the data.
    #   dropna()          remove missing dates
    #   dt.to_period("M") turn 2026-02-01 into the month "2026-02"
    #   unique()          keep each month once
    #   sorted()          oldest first
    month_options = sorted(monthly["CALENDAR_MONTH"].dropna().dt.to_period("M").unique())

    # A dropdown for the first month to include.
    start_period = st.selectbox(
        # The label shown above the dropdown.
        "Start month",
        # The choices.
        month_options,
        # index=0 preselects the first (oldest) month.
        index=0,
        # format_func controls how each choice is displayed, for example "Feb 2026".
        # A lambda is a small one-line function without a name.
        format_func=lambda value: value.strftime("%b %Y"),
    )

    # A dropdown for the last month to include, preselecting the newest month.
    end_period = st.selectbox(
        "End month",
        month_options,
        index=len(month_options) - 1,
        format_func=lambda value: value.strftime("%b %Y"),
    )

    # Guard against an impossible range (start after end).
    if start_period > end_period:
        # st.warning shows a yellow message box.
        st.warning("Start month is after end month, so the full period is used.")
        # Fall back to the first and last available months.
        start_period, end_period = month_options[0], month_options[-1]

    # Turn the chosen months into exact dates: the first day of the start month...
    start_date = start_period.to_timestamp().date()
    # ...and the last day of the end month.
    end_date = end_period.to_timestamp(how="end").date()

    # Every neighbourhood name in the data, sorted alphabetically.
    neighbourhood_options = sorted(monthly["REPORTING_NEIGHBOURHOOD"].dropna().unique())

    # A multiselect lets the user pick several values. It returns a list.
    selected_neighbourhoods = st.multiselect(
        "Neighbourhoods",
        neighbourhood_options,
        # The grey hint text shown while nothing is selected.
        placeholder="All neighbourhoods",
    )

    # The room types present in the data.
    room_type_options = sorted(listings["ROOM_TYPE"].dropna().unique())
    selected_room_types = st.multiselect("Room types", room_type_options, placeholder="All room types")

    # The price bands, in a meaningful order rather than alphabetical order.
    band_order = ["Budget", "Mid-range", "Premium", "Luxury", "Unknown"]
    # Keep only the bands that actually occur in the data.
    band_options = [band for band in band_order if band in set(listings["PRICE_BAND"].dropna())]
    selected_price_bands = st.multiselect("Price bands", band_options, placeholder="All price bands")

    # A slider for the minimum number of reviews a listing must have.
    min_reviews = st.slider(
        "Minimum reviews",
        # The slider runs from 0...
        min_value=0,
        # ...to the largest review count in the data. fillna(0) treats missing as 0.
        max_value=int(listings["NUMBER_OF_REVIEWS"].fillna(0).max()),
        # The starting position.
        value=0,
        # Move in steps of 5.
        step=5,
    )

    # A toggle is an on/off switch. It returns True or False.
    only_superhosts = st.toggle("Superhosts only", value=False)
    only_available = st.toggle("Available in next 30 days", value=False)

    # A small explanation under the filters.
    st.caption("Leave a list empty to include everything.")


# ------------------------------------------------------------------------------
# 6. APPLY THE FILTERS
# A "mask" is a column of True/False values, one per row.
# df.loc[mask] keeps only the rows where the mask is True.
# "&" means AND: both conditions must be true for a row to be kept.
# ------------------------------------------------------------------------------

# An empty selection means "no filter". In Python an empty list counts as false,
# so "selected or all_options" falls back to the full list.
active_neighbourhoods = selected_neighbourhoods or neighbourhood_options

# Mask for the neighbourhood-month table: inside the date range AND a chosen neighbourhood.
monthly_mask = (
    # between() is true when the month lies from start_date to end_date.
    monthly["CALENDAR_MONTH"].dt.date.between(start_date, end_date)
    # isin() is true when the value is in the given list.
    & monthly["REPORTING_NEIGHBOURHOOD"].isin(active_neighbourhoods)
)
# Keep the matching rows. copy() gives an independent table.
filtered_monthly = monthly.loc[monthly_mask].copy()

# The same two conditions for the listing-month table.
listing_monthly_mask = (
    listing_monthly["CALENDAR_MONTH"].dt.date.between(start_date, end_date)
    & listing_monthly["REPORTING_NEIGHBOURHOOD"].isin(active_neighbourhoods)
)
# Add the room type condition only when the user picked room types.
# "&=" means: combine the existing mask with one more condition.
if selected_room_types:
    listing_monthly_mask &= listing_monthly["ROOM_TYPE"].isin(selected_room_types)
filtered_listing_monthly = listing_monthly.loc[listing_monthly_mask].copy()

# Mask for the listings table: chosen neighbourhood AND enough reviews.
listings_mask = (
    listings["REPORTING_NEIGHBOURHOOD"].isin(active_neighbourhoods)
    # ge() means "greater than or equal to".
    & listings["NUMBER_OF_REVIEWS"].fillna(0).ge(min_reviews)
)
# Each optional filter is added only when the user switched it on.
if selected_room_types:
    listings_mask &= listings["ROOM_TYPE"].isin(selected_room_types)
if selected_price_bands:
    listings_mask &= listings["PRICE_BAND"].isin(selected_price_bands)
if only_superhosts:
    # eq(True) keeps rows that are exactly True. Missing values count as not True.
    listings_mask &= listings["IS_SUPERHOST"].eq(True)
if only_available:
    # gt(0) means "greater than 0": at least one free night in the next 30 days.
    listings_mask &= listings["AVAILABILITY_30"].fillna(0).gt(0)
filtered_listings = listings.loc[listings_mask].copy()

# Keep only the hosts that own at least one of the remaining listings.
filtered_hosts = hosts[hosts["HOST_ID"].isin(set(filtered_listings["HOST_ID"].dropna()))].copy()

# If the filters removed everything, say so instead of drawing empty charts.
if filtered_listings.empty or filtered_monthly.empty:
    st.warning("No data matches the current filters. Widen the filters to continue.")
    st.stop()


# ------------------------------------------------------------------------------
# 7. KPI ROW
# KPI = Key Performance Indicator: one headline number.
# ------------------------------------------------------------------------------

# nunique() counts the distinct values: how many different listings and hosts.
active_listings = filtered_listings["LISTING_ID"].nunique()
active_hosts = filtered_listings["HOST_ID"].nunique()

# mean() is the average. It ignores missing values.
avg_price = filtered_listing_monthly["AVG_EFFECTIVE_NIGHTLY_PRICE"].mean()
avg_rating = filtered_listings["REVIEW_SCORES_RATING"].mean()

# Availability = all available days divided by all calendar days.
total_days = filtered_listing_monthly["CALENDAR_DAYS"].sum()
# The "if" avoids dividing by zero when there are no days at all.
avg_availability = filtered_listing_monthly["AVAILABLE_DAYS"].sum() / total_days if total_days else None

# sum() adds up the estimated revenue of every listing-month row.
total_revenue = filtered_listing_monthly["ESTIMATED_UNAVAILABLE_REVENUE"].sum()

# Nights that could not be booked any more. We read them as "probably booked".
unavailable_nights = filtered_listing_monthly["UNAVAILABLE_DAYS"].sum()

# Some Inside Airbnb snapshots are published WITHOUT prices. notna().any() is
# True when at least one price exists. Without prices, revenue cannot be
# estimated, so the dashboard switches its headline measure to unavailable nights.
has_prices = bool(filtered_listing_monthly["AVG_EFFECTIVE_NIGHTLY_PRICE"].notna().any())

# Choose the column, label and number format used by the charts below.
if has_prices:
    measure, measure_title, measure_format = "ESTIMATED_REVENUE", "Estimated revenue ($)", "$,.0f"
else:
    measure, measure_title, measure_format = "UNAVAILABLE_DAYS", "Unavailable nights", ",.0f"
    # Tell the reader why price and revenue are empty instead of showing zeros.
    st.info(
        "This Inside Airbnb snapshot contains no prices, so price and revenue figures are empty. "
        "Unavailable nights (a proxy for booked nights) are shown instead."
    )

# st.columns(6) creates six equal columns next to each other and returns them as a list.
kpi = st.columns(6)
# metric(label, value) draws one KPI card in a column.
kpi[0].metric("Listings", number(active_listings))
kpi[1].metric("Hosts", number(active_hosts))
kpi[2].metric("Avg Price", money(avg_price))
# The rating gets two decimal places, or "n/a" when no rating exists.
kpi[3].metric("Avg Rating", f"{avg_rating:.2f}" if pd.notna(avg_rating) else "n/a")
kpi[4].metric("Availability", pct(avg_availability))
# The last card shows revenue when prices exist, otherwise unavailable nights.
if has_prices:
    kpi[5].metric("Est. Revenue", money(total_revenue))
else:
    kpi[5].metric("Unavailable Nights", number(unavailable_nights))


# ------------------------------------------------------------------------------
# 8. TABS
# st.tabs returns one container per tab. Whatever is drawn inside
# "with some_tab:" appears on that tab.
# ------------------------------------------------------------------------------
overview_tab, market_tab, listings_tab, hosts_tab = st.tabs(
    ["Market Overview", "Neighbourhoods", "Listings", "Hosts"]
)

# ---------------- Tab 1: Market Overview ----------------
with overview_tab:

    # Build one row per month for the trend chart.
    trend = (
        # groupby puts all rows of the same month together.
        # as_index=False keeps CALENDAR_MONTH as a normal column.
        filtered_listing_monthly.groupby("CALENDAR_MONTH", as_index=False)
        # agg calculates one value per group. NEW_NAME=("source column", "function").
        .agg(
            ESTIMATED_REVENUE=("ESTIMATED_UNAVAILABLE_REVENUE", "sum"),
            UNAVAILABLE_DAYS=("UNAVAILABLE_DAYS", "sum"),
            AVAILABLE_DAYS=("AVAILABLE_DAYS", "sum"),
            CALENDAR_DAYS=("CALENDAR_DAYS", "sum"),
            AVG_PRICE=("AVG_EFFECTIVE_NIGHTLY_PRICE", "mean"),
        )
    )
    # Add the availability rate as a new column: available days / all days.
    trend["AVAILABILITY_RATE"] = trend["AVAILABLE_DAYS"] / trend["CALENDAR_DAYS"]

    # Two columns of unequal width: the left one is 1.4 times as wide as the right one.
    left, right = st.columns([1.4, 1])

    with left:
        # A section heading.
        # The heading follows the measure chosen in the KPI section.
        st.subheader("Estimated Revenue by Month" if has_prices else "Unavailable Nights by Month")
        # Build an Altair chart. Altair is "declarative": you describe WHAT to
        # show (which column on which axis), not how to draw it.
        revenue_chart = (
            # Start a chart from the trend table.
            alt.Chart(trend)
            # Draw a line, with a dot on every data point.
            .mark_line(point=True)
            # encode() maps columns to visual properties.
            # The letter after the colon is the data type:
            #   :T = time, :Q = quantity (a number), :N = name (a category)
            .encode(
                # Month on the horizontal axis.
                x=alt.X("CALENDAR_MONTH:T", title="Month"),
                # The chosen measure on the vertical axis. f"{measure}:Q" builds the
                # text "ESTIMATED_REVENUE:Q" or "UNAVAILABLE_DAYS:Q".
                y=alt.Y(f"{measure}:Q", title=measure_title),
                # The box shown when the mouse hovers over a point.
                tooltip=[
                    alt.Tooltip("CALENDAR_MONTH:T", title="Month", format="%b %Y"),
                    alt.Tooltip(f"{measure}:Q", title=measure_title, format=measure_format),
                    alt.Tooltip("AVAILABILITY_RATE:Q", title="Availability", format=".1%"),
                ],
            )
            # The chart height in pixels.
            .properties(height=340)
        )
        # Draw the chart. width="stretch" makes it fill its column.
        st.altair_chart(revenue_chart, width="stretch")

    with right:
        st.subheader("Listings by Room Type")
        # Count the listings of each room type.
        room_mix = (
            filtered_listings.groupby("ROOM_TYPE", as_index=False)
            .agg(LISTINGS=("LISTING_ID", "nunique"))
        )
        room_chart = (
            alt.Chart(room_mix)
            # Draw horizontal bars.
            .mark_bar()
            .encode(
                # Bar length = number of listings.
                x=alt.X("LISTINGS:Q", title="Listings"),
                # One bar per room type. sort="-x" puts the longest bar on top.
                y=alt.Y("ROOM_TYPE:N", sort="-x", title=None),
                tooltip=["ROOM_TYPE:N", alt.Tooltip("LISTINGS:Q", format=",.0f")],
            )
            .properties(height=340)
        )
        st.altair_chart(room_chart, width="stretch")

    # A second row with two equal columns.
    left, right = st.columns(2)

    with left:
        st.subheader("Price vs Reviews")
        # Keep only listings that have both a price and a review count.
        scatter_data = filtered_listings.dropna(subset=["NIGHTLY_PRICE", "NUMBER_OF_REVIEWS"])
        if scatter_data.empty:
            # st.info shows a blue message box.
            st.info("No listing prices are available for the current filters.")
        else:
            scatter = (
                alt.Chart(scatter_data)
                # One semi-transparent circle per listing.
                .mark_circle(opacity=0.6, size=60)
                .encode(
                    x=alt.X("NIGHTLY_PRICE:Q", title="Nightly price ($)"),
                    y=alt.Y("NUMBER_OF_REVIEWS:Q", title="Reviews"),
                    # Colour the circles by room type. Altair adds the legend itself.
                    color=alt.Color("ROOM_TYPE:N", title="Room type"),
                    tooltip=[
                        "LISTING_NAME:N",
                        "REPORTING_NEIGHBOURHOOD:N",
                        "ROOM_TYPE:N",
                        alt.Tooltip("NIGHTLY_PRICE:Q", title="Price", format="$,.0f"),
                        alt.Tooltip("NUMBER_OF_REVIEWS:Q", title="Reviews", format=",.0f"),
                    ],
                )
                .properties(height=340)
            )
            st.altair_chart(scatter, width="stretch")

    with right:
        st.subheader("Listing Map")
        # Keep the listings that have coordinates.
        map_data = filtered_listings[["LATITUDE", "LONGITUDE"]].dropna()
        if map_data.empty:
            st.info("No coordinates are available for the current filters.")
        else:
            # st.map draws one dot per row. It expects columns named lat and lon.
            st.map(map_data.rename(columns={"LATITUDE": "lat", "LONGITUDE": "lon"}), height=340)

# ---------------- Tab 2: Neighbourhoods ----------------
with market_tab:
    st.subheader("Neighbourhood Performance")

    # One row per neighbourhood over the whole selected period.
    neighbourhood_summary = (
        filtered_listing_monthly.groupby("REPORTING_NEIGHBOURHOOD", as_index=False)
        .agg(
            LISTINGS=("LISTING_ID", "nunique"),
            ESTIMATED_REVENUE=("ESTIMATED_UNAVAILABLE_REVENUE", "sum"),
            UNAVAILABLE_DAYS=("UNAVAILABLE_DAYS", "sum"),
            AVG_PRICE=("AVG_EFFECTIVE_NIGHTLY_PRICE", "mean"),
            AVAILABLE_DAYS=("AVAILABLE_DAYS", "sum"),
            CALENDAR_DAYS=("CALENDAR_DAYS", "sum"),
        )
    )
    # Availability rate per neighbourhood.
    neighbourhood_summary["AVAILABILITY_RATE"] = (
        neighbourhood_summary["AVAILABLE_DAYS"] / neighbourhood_summary["CALENDAR_DAYS"]
    )
    # Largest value of the chosen measure first.
    neighbourhood_summary = neighbourhood_summary.sort_values(measure, ascending=False)

    left, right = st.columns(2)

    with left:
        st.caption(f"{measure_title} by neighbourhood")
        revenue_bars = (
            alt.Chart(neighbourhood_summary)
            .mark_bar()
            .encode(
                x=alt.X(f"{measure}:Q", title=measure_title),
                y=alt.Y("REPORTING_NEIGHBOURHOOD:N", sort="-x", title=None),
                tooltip=[
                    "REPORTING_NEIGHBOURHOOD:N",
                    alt.Tooltip("LISTINGS:Q", format=",.0f"),
                    alt.Tooltip(f"{measure}:Q", title=measure_title, format=measure_format),
                ],
            )
            .properties(height=440)
        )
        st.altair_chart(revenue_bars, width="stretch")

    with right:
        st.caption("Share of days available, by neighbourhood")
        availability_bars = (
            alt.Chart(neighbourhood_summary)
            .mark_bar()
            .encode(
                # axis format="%" shows 0.25 as 25%.
                x=alt.X("AVAILABILITY_RATE:Q", title="Availability", axis=alt.Axis(format="%")),
                y=alt.Y("REPORTING_NEIGHBOURHOOD:N", sort="-x", title=None),
                tooltip=[
                    "REPORTING_NEIGHBOURHOOD:N",
                    alt.Tooltip("AVAILABILITY_RATE:Q", title="Availability", format=".1%"),
                    alt.Tooltip("LISTINGS:Q", format=",.0f"),
                ],
            )
            .properties(height=440)
        )
        st.altair_chart(availability_bars, width="stretch")

    # st.dataframe draws an interactive table (sortable, scrollable).
    st.dataframe(
        # Show these columns, in this order.
        pick_columns(
            neighbourhood_summary,
            ["REPORTING_NEIGHBOURHOOD", "LISTINGS", "UNAVAILABLE_DAYS", "ESTIMATED_REVENUE", "AVG_PRICE", "AVAILABILITY_RATE"],
        ),
        # Fill the page width.
        width="stretch",
        # Hide the pandas row numbers.
        hide_index=True,
        # column_config sets a friendly title and a number format per column.
        column_config={
            "REPORTING_NEIGHBOURHOOD": "Neighbourhood",
            "LISTINGS": "Listings",
            "UNAVAILABLE_DAYS": "Unavailable Nights",
            "ESTIMATED_REVENUE": st.column_config.NumberColumn("Estimated Revenue", format="$%.0f"),
            "AVG_PRICE": st.column_config.NumberColumn("Avg Price", format="$%.0f"),
            "AVAILABILITY_RATE": st.column_config.NumberColumn("Availability", format="percent"),
        },
    )

# ---------------- Tab 3: Listings ----------------
with listings_tab:
    st.subheader("Listing Explorer")

    # Choose the columns worth showing and sort by review count, highest first.
    listing_table = pick_columns(
        filtered_listings,
        [
            "LISTING_NAME",
            "HOST_NAME",
            "REPORTING_NEIGHBOURHOOD",
            "ROOM_TYPE",
            "PROPERTY_TYPE",
            "ACCOMMODATES",
            "BEDROOMS",
            "NIGHTLY_PRICE",
            "PRICE_BAND",
            "AVAILABILITY_30",
            "NUMBER_OF_REVIEWS",
            "REVIEW_SCORES_RATING",
            "IS_SUPERHOST",
            "LISTING_URL",
        ],
    ).sort_values("NUMBER_OF_REVIEWS", ascending=False)

    st.dataframe(
        listing_table,
        width="stretch",
        hide_index=True,
        column_config={
            "LISTING_NAME": "Listing",
            "HOST_NAME": "Host",
            "REPORTING_NEIGHBOURHOOD": "Neighbourhood",
            "ROOM_TYPE": "Room Type",
            "PROPERTY_TYPE": "Property Type",
            "ACCOMMODATES": "Guests",
            "BEDROOMS": "Bedrooms",
            "NIGHTLY_PRICE": st.column_config.NumberColumn("Nightly Price", format="$%.0f"),
            "PRICE_BAND": "Price Band",
            "AVAILABILITY_30": "Free Nights (30d)",
            "NUMBER_OF_REVIEWS": "Reviews",
            "REVIEW_SCORES_RATING": st.column_config.NumberColumn("Rating", format="%.2f"),
            "IS_SUPERHOST": "Superhost",
            # LinkColumn makes the URL clickable.
            "LISTING_URL": st.column_config.LinkColumn("Airbnb Link", display_text="Open"),
        },
    )

# ---------------- Tab 4: Hosts ----------------
with hosts_tab:
    st.subheader("Host Performance")

    # Hosts with the most listings first. Ties are ordered by total reviews.
    host_table = filtered_hosts.sort_values(["LISTING_COUNT", "TOTAL_REVIEWS"], ascending=[False, False])

    # The 15 biggest hosts for the chart.
    top_hosts = host_table.head(15)
    host_chart = (
        alt.Chart(top_hosts)
        .mark_bar()
        .encode(
            x=alt.X("LISTING_COUNT:Q", title="Listings"),
            y=alt.Y("HOST_NAME:N", sort="-x", title=None),
            tooltip=[
                "HOST_NAME:N",
                alt.Tooltip("LISTING_COUNT:Q", title="Listings", format=",.0f"),
                alt.Tooltip("TOTAL_REVIEWS:Q", title="Reviews", format=",.0f"),
                alt.Tooltip("AVG_NIGHTLY_PRICE:Q", title="Avg price", format="$,.0f"),
            ],
        )
        .properties(height=420)
    )
    st.caption("Top 15 hosts by number of listings")
    st.altair_chart(host_chart, width="stretch")

    st.dataframe(
        pick_columns(
            host_table,
            [
                "HOST_NAME",
                "HOST_LOCATION",
                "LISTING_COUNT",
                "ENTIRE_HOME_LISTING_COUNT",
                "PRIVATE_ROOM_LISTING_COUNT",
                "AVG_NIGHTLY_PRICE",
                "TOTAL_REVIEWS",
                "IS_SUPERHOST",
                "HOST_IDENTITY_VERIFIED",
                "HOST_RESPONSE_RATE",
                "HOST_ACCEPTANCE_RATE",
            ],
        ),
        width="stretch",
        hide_index=True,
        column_config={
            "HOST_NAME": "Host",
            "HOST_LOCATION": "Location",
            "LISTING_COUNT": "Listings",
            "ENTIRE_HOME_LISTING_COUNT": "Entire Homes",
            "PRIVATE_ROOM_LISTING_COUNT": "Private Rooms",
            "AVG_NIGHTLY_PRICE": st.column_config.NumberColumn("Avg Nightly Price", format="$%.0f"),
            "TOTAL_REVIEWS": "Reviews",
            "IS_SUPERHOST": "Superhost",
            "HOST_IDENTITY_VERIFIED": "Verified",
            "HOST_RESPONSE_RATE": st.column_config.NumberColumn("Response Rate", format="percent"),
            "HOST_ACCEPTANCE_RATE": st.column_config.NumberColumn("Acceptance Rate", format="percent"),
        },
    )
