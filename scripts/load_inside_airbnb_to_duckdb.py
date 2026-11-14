"""Load the four Inside Airbnb files into a local DuckDB file (the free path).

This is the DuckDB twin of load_inside_airbnb_to_snowflake.py and builds the
same thing: a RAW schema with four tables (LISTINGS, CALENDAR, REVIEWS,
NEIGHBOURHOODS), every column stored as text exactly as it appears in the file.
Cleaning and typing happen later, in the dbt staging models, never here.

What makes this "the same" as the Snowflake load:
  - every column is VARCHAR, named from the CSV header (Snowflake's raw tables are too)
  - empty fields and the strings NULL / null become SQL NULL
    (Snowflake's file format: NULL_IF = ('', 'NULL', 'null'), EMPTY_FIELD_AS_NULL)
  - a table is dropped and recreated on every run, so running it twice is safe

Run it from the project folder:

    python scripts/load_inside_airbnb_to_duckdb.py

It writes airbnb.duckdb next to dbt_project.yml (the path profiles.yml expects)
and prints one line per table with its row count.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import duckdb

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RAW_DATA_DIR = PROJECT_ROOT / "data" / "raw"
DEFAULT_DATABASE = PROJECT_ROOT / "airbnb.duckdb"

NULL_STRINGS = ["", "NULL", "null"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Load Inside Airbnb files into DuckDB RAW tables.")
    parser.add_argument("--listings", type=Path, default=DEFAULT_RAW_DATA_DIR / "listings.csv.gz")
    parser.add_argument("--calendar", type=Path, default=DEFAULT_RAW_DATA_DIR / "calendar.csv.gz")
    parser.add_argument("--reviews", type=Path, default=DEFAULT_RAW_DATA_DIR / "reviews.csv.gz")
    parser.add_argument("--neighbourhoods", type=Path, default=DEFAULT_RAW_DATA_DIR / "neighbourhoods.csv")
    parser.add_argument("--database", type=Path, default=DEFAULT_DATABASE, help="DuckDB file to create or update")
    return parser.parse_args()


def load_table(connection: duckdb.DuckDBPyConnection, table_name: str, local_file: Path) -> int:
    if not local_file.exists():
        raise SystemExit(f"Missing file: {local_file}\nThe four Inside Airbnb files live in data/raw/ in this repo.")
    connection.execute(f"drop table if exists raw.{table_name}")
    # all_varchar keeps every value as the original text; the staging models own all typing.
    connection.execute(
        f"""
        create table raw.{table_name} as
        select * from read_csv(
            ?,
            header = true,
            all_varchar = true,
            nullstr = ?,
            quote = '"',
            escape = '"',
            strict_mode = false
        )
        """,
        [str(local_file), NULL_STRINGS],
    )
    return connection.execute(f"select count(*) from raw.{table_name}").fetchone()[0]


def main() -> None:
    args = parse_args()
    files = {
        "LISTINGS": args.listings,
        "CALENDAR": args.calendar,
        "REVIEWS": args.reviews,
        "NEIGHBOURHOODS": args.neighbourhoods,
    }
    print(f"DuckDB file: {args.database}")
    with duckdb.connect(str(args.database)) as connection:
        connection.execute("create schema if not exists raw")
        for table_name, local_file in files.items():
            rows = load_table(connection, table_name, local_file)
            print(f"Loaded {local_file.name} into RAW.{table_name}: {rows:,} rows")
    print("DuckDB RAW load complete. Next: dbt build --target duckdb --profiles-dir .")


if __name__ == "__main__":
    try:
        main()
    except duckdb.IOException as error:
        # The usual cause: the dashboard or another program has airbnb.duckdb open.
        sys.exit(f"Could not open the DuckDB file: {error}\nClose the dashboard (Ctrl+C) or any program using airbnb.duckdb, then run this again.")
