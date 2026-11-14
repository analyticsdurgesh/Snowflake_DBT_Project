"""Check a finished DuckDB build: did every layer produce what it should?

Run it after `dbt build --target duckdb --profiles-dir .`:

    python scripts/verify_duckdb_build.py

It reads airbnb.duckdb (read-only) and checks the things a reviewer would ask
about, printing one line per check and exiting non-zero if any fails:

  - every RAW table has rows, and every model the project defines exists
  - fct_listing_calendar has exactly one row per raw calendar row
    (more rows means an incremental run kept an old snapshot: run --full-refresh)
  - no calendar day appears twice for a listing
  - most listings carry a nightly price, so the revenue estimate is not empty
  - estimated revenue is positive, and every monthly total is non-negative
"""

from __future__ import annotations

import sys
from pathlib import Path

import duckdb

DATABASE = Path(__file__).resolve().parents[1] / "airbnb.duckdb"

MODELS = {
    "staging": ["stg_airbnb__listings", "stg_airbnb__calendar", "stg_airbnb__reviews", "stg_airbnb__neighbourhoods"],
    "intermediate": ["int_airbnb__listing_enriched", "int_airbnb__calendar_enriched", "int_airbnb__reviews_enriched"],
    "analytics": [
        "dim_listings",
        "dim_hosts",
        "fct_listing_calendar",
        "fct_reviews",
        "agg_listing_monthly_performance",
        "agg_neighbourhood_monthly_performance",
    ],
}


def main() -> int:
    if not DATABASE.exists():
        print(f"FAIL  {DATABASE.name} not found. Run: python scripts/load_inside_airbnb_to_duckdb.py")
        return 1
    failures = 0
    with duckdb.connect(str(DATABASE), read_only=True) as connection:
        def scalar(sql: str):
            return connection.execute(sql).fetchone()[0]

        def check(ok: bool, message: str) -> None:
            nonlocal failures
            print(f"{'ok  ' if ok else 'FAIL'}  {message}")
            failures += 0 if ok else 1

        existing = {
            (row[0].lower(), row[1].lower())
            for row in connection.execute("select schema_name, table_name from duckdb_tables() union all select schema_name, view_name from duckdb_views()").fetchall()
        }
        for table in ("listings", "calendar", "reviews", "neighbourhoods"):
            rows = scalar(f"select count(*) from raw.{table}") if ("raw", table) in existing else 0
            check(rows > 0, f"raw.{table}: {rows:,} rows")
        for schema, names in MODELS.items():
            missing = [name for name in names if (schema, name) not in existing]
            check(not missing, f"{schema}: {len(names) - len(missing)} of {len(names)} models built" + (f", missing {missing}" if missing else ""))
        if failures:
            return 1

        raw_calendar = scalar("select count(*) from raw.calendar")
        fact_calendar = scalar("select count(*) from analytics.fct_listing_calendar")
        check(
            fact_calendar == raw_calendar,
            f"fct_listing_calendar: {fact_calendar:,} rows for {raw_calendar:,} raw calendar rows"
            + ("" if fact_calendar == raw_calendar else " (an incremental run kept an old snapshot: dbt build --full-refresh)"),
        )
        duplicates = scalar(
            "select count(*) from (select listing_id, calendar_date from analytics.fct_listing_calendar group by 1, 2 having count(*) > 1)"
        )
        check(duplicates == 0, f"fct_listing_calendar: {duplicates} duplicate (listing, day) pairs")
        listings, priced = connection.execute("select count(*), count(nightly_price) from analytics.dim_listings").fetchone()
        check(listings > 0 and priced / listings >= 0.5, f"dim_listings: {priced} of {listings} listings have a nightly price")
        revenue = scalar("select coalesce(sum(estimated_unavailable_revenue), 0) from analytics.agg_neighbourhood_monthly_performance")
        check(revenue > 0, f"estimated unavailable-night revenue: ${revenue:,.0f}")
        negative = scalar("select count(*) from analytics.agg_neighbourhood_monthly_performance where estimated_unavailable_revenue < 0")
        check(negative == 0, f"agg_neighbourhood_monthly_performance: {negative} negative monthly totals")

    print("BUILD OK" if failures == 0 else f"{failures} check(s) failed")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
