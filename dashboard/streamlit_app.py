"""Streamlit dashboard for the Airbnb Snowflake/dbt mart layer."""

from __future__ import annotations

import os
import json
from pathlib import Path

import altair as alt
import pandas as pd
import snowflake.connector
import streamlit as st


PROJECT_ROOT = Path(__file__).resolve().parents[1]
LOCAL_CONFIG_FILE = PROJECT_ROOT / "config" / "local_credentials.json"
MART_SCHEMA = "ANALYTICS"


def load_local_config() -> dict:
    if not LOCAL_CONFIG_FILE.exists():
        st.error(
            "Missing config/local_credentials.json. "
            "Copy config/local_credentials.example.json and fill in your local Snowflake values."
        )
        st.stop()
    return json.loads(LOCAL_CONFIG_FILE.read_text(encoding="utf-8"))


CONFIG = load_local_config()
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
    return snowflake.connector.connect(
        account=require_config("account"),
        user=require_config("user"),
        password=require_config("password"),
        role=ROLE,
        warehouse=WAREHOUSE,
        database=DATABASE,
        schema=MART_SCHEMA,
    )


@st.cache_data(ttl=600, show_spinner=False)
def run_query(sql: str) -> pd.DataFrame:
    with get_connection().cursor() as cursor:
        cursor.execute(sql)
        return cursor.fetch_pandas_all()


def table_name(model_name: str) -> str:
    return f"{DATABASE}.{MART_SCHEMA}.{model_name}"


st.set_page_config(page_title="Airbnb Analytics", layout="wide")
st.title("Airbnb Analytics")

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
    st.altair_chart(revenue_chart, use_container_width=True)

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
    st.altair_chart(availability_chart, use_container_width=True)

st.subheader("Top Hosts")
st.dataframe(
    hosts.sort_values("LISTING_COUNT", ascending=False).head(25),
    use_container_width=True,
    hide_index=True,
)

st.subheader("Listings")
st.dataframe(
    listings.sort_values(["REPORTING_NEIGHBOURHOOD", "NIGHTLY_PRICE"], ascending=[True, False]),
    use_container_width=True,
    hide_index=True,
)
