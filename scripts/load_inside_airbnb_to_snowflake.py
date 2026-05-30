"""Create Snowflake raw objects and load local Inside Airbnb CSV files."""

from __future__ import annotations

import argparse
import csv
import gzip
import json
import os
import re
from pathlib import Path

import snowflake.connector


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RAW_DATA_DIR = PROJECT_ROOT / "data" / "raw"
LOCAL_CONFIG_FILE = PROJECT_ROOT / "config" / "local_credentials.json"


def load_local_config() -> dict:
    if not LOCAL_CONFIG_FILE.exists():
        raise SystemExit(
            "Missing config/local_credentials.json\n"
            "Copy config/local_credentials.example.json to config/local_credentials.json "
            "and fill in your local Snowflake values."
        )
    config = json.loads(LOCAL_CONFIG_FILE.read_text(encoding="utf-8"))
    snowflake = config.get("snowflake", {})
    required = ["account", "user", "password"]
    missing = [key for key in required if not str(snowflake.get(key, "")).strip()]
    placeholders = [
        key
        for key in required
        if str(snowflake.get(key, "")).strip().lower().startswith("your_")
    ]
    if missing or placeholders:
        raise SystemExit(
            "Update config/local_credentials.json: "
            + ", ".join(sorted(set(missing + placeholders)))
        )
    return config


def snowflake_value(config: dict, key: str, default: str) -> str:
    return str(config.get("snowflake", {}).get(key, default)).strip()


def connect(config: dict):
    return snowflake.connector.connect(
        account=snowflake_value(config, "account", ""),
        user=snowflake_value(config, "user", ""),
        password=snowflake_value(config, "password", ""),
        role=snowflake_value(config, "role", "ACCOUNTADMIN"),
        warehouse=snowflake_value(config, "warehouse", "COMPUTE_WH"),
        database=snowflake_value(config, "database", "AIRBNB_ANALYTICS"),
        schema="RAW",
    )


def run_setup_sql(cursor) -> None:
    setup_sql = (PROJECT_ROOT / "setup" / "snowflake_setup.sql").read_text(encoding="utf-8")
    statements = [statement.strip() for statement in setup_sql.split(";") if statement.strip()]
    for statement in statements:
        cursor.execute(statement)


def read_header(local_file: Path) -> list[str]:
    opener = gzip.open if local_file.suffix == ".gz" else open
    with opener(local_file, "rt", encoding="utf-8", newline="") as file:
        return next(csv.reader(file))


def snowflake_identifier(column_name: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9_]", "_", column_name.strip()).upper()
    cleaned = re.sub(r"_+", "_", cleaned).strip("_")
    if not cleaned:
        raise ValueError(f"Cannot create an identifier from column name: {column_name!r}")
    return f'"{cleaned}"'


def recreate_raw_table(cursor, table_name: str, local_file: Path) -> None:
    columns = ",\n    ".join(f"{snowflake_identifier(column)} varchar" for column in read_header(local_file))
    cursor.execute(f"CREATE OR REPLACE TABLE RAW.{table_name} (\n    {columns}\n)")


def put_and_copy(cursor, local_file: Path, table_name: str) -> None:
    if not local_file.exists():
        raise SystemExit(f"Missing file: {local_file}")

    stage_name = "@RAW.INSIDE_AIRBNB_STAGE"
    staged_file = local_file.name

    # PUT uploads from your computer to the Snowflake internal stage.
    cursor.execute(
        f"PUT file://{local_file} {stage_name} AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
    )

    # COPY loads columns by file order; raw table definitions match the CSV headers.
    recreate_raw_table(cursor, table_name, local_file)
    cursor.execute(
        f"""
        COPY INTO RAW.{table_name}
        FROM {stage_name}/{staged_file}
        FILE_FORMAT = (FORMAT_NAME = RAW.INSIDE_AIRBNB_CSV_FORMAT)
        ON_ERROR = 'ABORT_STATEMENT'
        """
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Load Inside Airbnb files into Snowflake RAW tables.")
    parser.add_argument("--listings", type=Path, default=DEFAULT_RAW_DATA_DIR / "listings.csv.gz")
    parser.add_argument("--calendar", type=Path, default=DEFAULT_RAW_DATA_DIR / "calendar.csv.gz")
    parser.add_argument("--reviews", type=Path, default=DEFAULT_RAW_DATA_DIR / "reviews.csv.gz")
    parser.add_argument("--neighbourhoods", type=Path, default=DEFAULT_RAW_DATA_DIR / "neighbourhoods.csv")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    config = load_local_config()
    files = {
        "LISTINGS": args.listings,
        "CALENDAR": args.calendar,
        "REVIEWS": args.reviews,
        "NEIGHBOURHOODS": args.neighbourhoods,
    }

    with connect(config) as connection:
        with connection.cursor() as cursor:
            run_setup_sql(cursor)
            for table_name, local_file in files.items():
                print(f"Loading {local_file} into RAW.{table_name}...")
                put_and_copy(cursor, local_file, table_name)
            print("Snowflake RAW load complete.")


if __name__ == "__main__":
    main()
