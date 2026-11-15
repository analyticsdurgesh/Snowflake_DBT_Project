"""Streamlit dashboard for the Airbnb dbt mart layer, on Snowflake or on DuckDB.

Which database it reads:
  - Snowflake: the default, using config/local_credentials.json (as before).
  - DuckDB (the free path): pass --duckdb, or simply have no
    config/local_credentials.json and an airbnb.duckdb file in the project folder.

    streamlit run dashboard/streamlit_app.py                       # auto
    streamlit run dashboard/streamlit_app.py -- --duckdb           # force DuckDB
    streamlit run dashboard/streamlit_app.py -- --duckdb other.duckdb
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import altair as alt
import pandas as pd
import streamlit as st


PROJECT_ROOT = Path(__file__).resolve().parents[1]
LOCAL_CONFIG_FILE = PROJECT_ROOT / "config" / "local_credentials.json"
DEFAULT_DUCKDB_FILE = PROJECT_ROOT / "airbnb.duckdb"
MART_SCHEMA = "ANALYTICS"


def duckdb_file_from_args() -> Path | None:
    """The DuckDB file to read, or None for Snowflake."""
    args = sys.argv[1:]
    if "--duckdb" in args:
        position = args.index("--duckdb")
        if position + 1 < len(args) and not args[position + 1].startswith("--"):
            return Path(args[position + 1]).resolve()
        return DEFAULT_DUCKDB_FILE
    if not LOCAL_CONFIG_FILE.exists() and DEFAULT_DUCKDB_FILE.exists():
        return DEFAULT_DUCKDB_FILE
    return None


DUCKDB_FILE = duckdb_file_from_args()


def load_local_config() -> dict:
    if not LOCAL_CONFIG_FILE.exists():
        st.error(
            "Missing config/local_credentials.json. "
            "Copy config/local_credentials.example.json and fill in your local Snowflake values. "
            "On the free DuckDB path, build first (dbt build --target duckdb --profiles-dir .) "
            "and the dashboard finds airbnb.duckdb by itself."
        )
        st.stop()
    return json.loads(LOCAL_CONFIG_FILE.read_text(encoding="utf-8"))


CONFIG = {} if DUCKDB_FILE else load_local_config()
SNOWFLAKE_CONFIG = CONFIG.get("snowflake", {})
DATABASE = str(SNOWFLAKE_CONFIG.get("database", "AIRBNB_ANALYTICS"))
WAREHOUSE = str(SNOWFLAKE_CONFIG.get("warehouse", "COMPUTE_WH"))
ROLE = str(SNOWFLAKE_CONFIG.get("role", "ACCOUNTADMIN"))


def require_config(name: str) -> str:
    value = str(SNOWFLAKE_CONFIG.get(name, "")).strip()
    if not value:
        st.error(f"Missing Snowflake config value: {name}")
        st.stop()
    return value


@st.cache_resource(show_spinner=False)
def get_connection():
    import snowflake.connector  # only the Snowflake path needs the connector installed

    return snowflake.connector.connect(
        account=require_config("account"),
        user=require_config("user"),
        password=require_config("password"),
        role=ROLE,
        warehouse=WAREHOUSE,
        database=DATABASE,
        schema=MART_SCHEMA,
    )


def run_duckdb_query(sql: str) -> pd.DataFrame:
    import duckdb

    if not DUCKDB_FILE.exists():
        st.error(f"{DUCKDB_FILE.name} not found. Run: python scripts/load_inside_airbnb_to_duckdb.py, then dbt build --target duckdb --profiles-dir .")
        st.stop()
    # Open read-only and close straight away: DuckDB lets only one program write
    # to a file, so holding it open here would block your next dbt build.
    with duckdb.connect(str(DUCKDB_FILE), read_only=True) as connection:
        frame = connection.execute(sql).fetchdf()
    # Snowflake returns UPPERCASE column names; match it so the charts below work on both.
    frame.columns = [column.upper() for column in frame.columns]
    return frame


@st.cache_data(ttl=600, show_spinner=False)
def run_query(sql: str) -> pd.DataFrame:
    if DUCKDB_FILE:
        return run_duckdb_query(sql)
    with get_connection().cursor() as cursor:
        cursor.execute(sql)
        return cursor.fetch_pandas_all()


def table_name(model_name: str) -> str:
    if DUCKDB_FILE:
        return f"{MART_SCHEMA.lower()}.{model_name.lower()}"
    return f"{DATABASE}.{MART_SCHEMA}.{model_name}"


st.set_page_config(page_title="Airbnb Analytics", layout="wide")
st.title("Airbnb Analytics")
if DUCKDB_FILE:
    st.caption(f"Reading the local DuckDB file {DUCKDB_FILE.name} (the free path).")

monthly = run_query(
    f"""
    select
        reporting_neighbourhood,
        calendar_month,
        active_listing_count,
        availability_rate,
        avg_effective_nightly_price,
        estimated_unavailable_revenue
    from {table_name('AGG_NEIGHBOURHOOD_MONTHLY_PERFORMANCE')}
    """
)

listings = run_query(
    f"""
    select
        listing_id,
        host_id,
        host_name,
        reporting_neighbourhood,
        room_type,
        nightly_price,
        review_scores_rating,
        number_of_reviews
    from {table_name('DIM_LISTINGS')}
    """
)

hosts = run_query(
    f"""
    select
        host_id,
        host_name,
        listing_count,
        avg_nightly_price,
        total_reviews
    from {table_name('DIM_HOSTS')}
    """
)

neighbourhoods = sorted(monthly["REPORTING_NEIGHBOURHOOD"].dropna().unique())
selected_neighbourhoods = st.sidebar.multiselect(
    "Neighbourhoods",
    neighbourhoods,
    default=neighbourhoods[: min(8, len(neighbourhoods))],
)

filtered_monthly = monthly[monthly["REPORTING_NEIGHBOURHOOD"].isin(selected_neighbourhoods)]

total_revenue = filtered_monthly["ESTIMATED_UNAVAILABLE_REVENUE"].sum()
avg_price = listings["NIGHTLY_PRICE"].mean()
avg_availability = filtered_monthly["AVAILABILITY_RATE"].mean()
listing_count = listings["LISTING_ID"].nunique()

metric_cols = st.columns(4)
metric_cols[0].metric("Listings", f"{listing_count:,.0f}")
metric_cols[1].metric("Avg Nightly Price", f"${avg_price:,.0f}" if pd.notna(avg_price) else "n/a")
metric_cols[2].metric("Avg Availability", f"{avg_availability:.1%}" if pd.notna(avg_availability) else "n/a")
metric_cols[3].metric("Estimated Revenue", f"${total_revenue:,.0f}")

left, right = st.columns(2)

with left:
    revenue_chart = (
        alt.Chart(filtered_monthly)
        .mark_bar()
        .encode(
            x=alt.X("ESTIMATED_UNAVAILABLE_REVENUE:Q", title="Estimated unavailable-night revenue"),
            y=alt.Y("REPORTING_NEIGHBOURHOOD:N", sort="-x", title="Neighbourhood"),
            tooltip=[
                "REPORTING_NEIGHBOURHOOD",
                alt.Tooltip("ESTIMATED_UNAVAILABLE_REVENUE:Q", format="$,.0f"),
            ],
        )
        .properties(height=360)
    )
    st.altair_chart(revenue_chart, width="stretch")

with right:
    availability_chart = (
        alt.Chart(filtered_monthly)
        .mark_line(point=True)
        .encode(
            x=alt.X("CALENDAR_MONTH:T", title="Month"),
            y=alt.Y("AVAILABILITY_RATE:Q", title="Availability rate", axis=alt.Axis(format="%")),
            color=alt.Color("REPORTING_NEIGHBOURHOOD:N", title="Neighbourhood"),
            tooltip=[
                "REPORTING_NEIGHBOURHOOD",
                "CALENDAR_MONTH:T",
                alt.Tooltip("AVAILABILITY_RATE:Q", format=".1%"),
            ],
        )
        .properties(height=360)
    )
    st.altair_chart(availability_chart, width="stretch")

st.subheader("Top Hosts")
st.dataframe(
    hosts.sort_values("LISTING_COUNT", ascending=False).head(25),
    width="stretch",
    hide_index=True,
)

st.subheader("Listings")
st.dataframe(
    listings.sort_values(["REPORTING_NEIGHBOURHOOD", "NIGHTLY_PRICE"], ascending=[True, False]),
    width="stretch",
    hide_index=True,
)
