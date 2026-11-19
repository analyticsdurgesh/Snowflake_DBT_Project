"""
================================================================================
scripts/load_inside_airbnb_to_snowflake.py  -  the "E" and "L" of ELT
================================================================================
WHAT THIS SCRIPT DOES
    It copies the four CSV files in data/raw/ into Snowflake tables in the RAW
    schema, completely unchanged. dbt then transforms those tables.

        Extract + Load  ->  this script       (files -> RAW tables)
        Transform       ->  dbt               (RAW -> STAGING -> ... -> ANALYTICS)

    dbt cannot load files from your laptop. It only transforms data that is
    already inside the warehouse. That is why this script has to exist.

THE STEPS
    1. Read the Snowflake login details from profiles.yml.
    2. Run setup/snowflake_setup.sql (database, warehouse, schemas, stage, format).
    3. For each file:
         a. PUT        upload the file into a Snowflake internal stage
         b. CREATE     build a RAW table whose columns match the file's header
         c. COPY INTO  load the staged file into that table

HOW TO RUN IT
    python scripts/load_inside_airbnb_to_snowflake.py
    (run_pipeline.py runs it for you as step 1.)
================================================================================
"""

# "from __future__ import annotations" makes Python store type hints as plain
# text instead of evaluating them. It lets modern hints such as "list[str]"
# work on older Python versions too. It must be the first import in the file.
from __future__ import annotations

# csv = Python's built-in CSV reader. It correctly handles commas and line
# breaks that appear INSIDE quoted values, which a simple split(",") would break.
import csv

# gzip = Python's built-in reader for .gz compressed files.
import gzip

# re = regular expressions, used to clean column names.
import re

# Path = an object for file paths that works the same on macOS, Linux and Windows.
from pathlib import Path

# snowflake.connector = the official Snowflake driver for Python. It opens a
# connection and sends SQL. Installed by "snowflake-connector-python".
import snowflake.connector

# yaml = the PyYAML library, used to read profiles.yml.
import yaml


# ------------------------------------------------------------------------------
# CONSTANTS - values that never change while the script runs.
# Python convention: constants are written in UPPER_CASE.
# ------------------------------------------------------------------------------

# __file__ is the path of THIS script. resolve() makes it absolute.
# parents[0] is the scripts/ folder, so parents[1] is the project root.
PROJECT_ROOT = Path(__file__).resolve().parents[1]

# The folder holding the four raw data files. "/" joins path parts.
RAW_DATA_DIR = PROJECT_ROOT / "data" / "raw"

# The file that stores the Snowflake login. dbt reads the same file.
PROFILES_FILE = PROJECT_ROOT / "profiles.yml"

# The SQL file that creates the Snowflake objects this project needs.
SETUP_SQL_FILE = PROJECT_ROOT / "setup" / "snowflake_setup.sql"

# The profile name. It must match "profile:" in dbt_project.yml.
PROFILE_NAME = "airbnb_snowflake"

# Which file goes into which RAW table. A dictionary maps a key to a value:
# key = Snowflake table name, value = path of the local file.
FILES_TO_LOAD = {
    "LISTINGS": RAW_DATA_DIR / "listings.csv.gz",
    "CALENDAR": RAW_DATA_DIR / "calendar.csv.gz",
    "REVIEWS": RAW_DATA_DIR / "reviews.csv.gz",
    "NEIGHBOURHOODS": RAW_DATA_DIR / "neighbourhoods.csv",
}

# The names of the stage and file format created by setup/snowflake_setup.sql.
STAGE_NAME = "@RAW.INSIDE_AIRBNB_STAGE"
FILE_FORMAT_NAME = "RAW.INSIDE_AIRBNB_CSV_FORMAT"


def load_snowflake_settings() -> dict:
    """Read profiles.yml and return the connection settings of the active target."""

    # Stop with a helpful message if the user has not created profiles.yml yet.
    if not PROFILES_FILE.exists():
        # SystemExit ends the script and prints the message, without a long traceback.
        raise SystemExit(
            "Missing profiles.yml\n"
            "Copy profiles.yml.example to profiles.yml and fill in your Snowflake values."
        )

    # read_text() returns the file as one string. safe_load() turns YAML text
    # into Python dictionaries and lists ("safe" = it will not run code hidden in the file).
    profiles = yaml.safe_load(PROFILES_FILE.read_text(encoding="utf-8"))

    # Pick our profile out of the file: the block under "airbnb_snowflake:".
    profile = profiles[PROFILE_NAME]

    # "target: dev" names the active connection. Look that name up under "outputs:".
    settings = profile["outputs"][profile["target"]]

    # Check the three values nobody can log in without.
    for key in ("account", "user", "password"):
        # str(...).strip() turns the value into text and removes surrounding spaces.
        value = str(settings.get(key, "")).strip()
        # An empty value, or one still starting with "your_", was never filled in.
        if not value or value.lower().startswith("your_"):
            raise SystemExit(f"Update profiles.yml: the value for '{key}' is missing.")

    # Hand the dictionary of settings back to the caller.
    return settings


def connect(settings: dict):
    """Open and return a connection to Snowflake."""

    # connect() logs in and returns a connection object.
    return snowflake.connector.connect(
        # The account identifier, for example ORGNAME-ACCOUNTNAME.
        account=settings["account"],
        # The Snowflake login name.
        user=settings["user"],
        # The password from profiles.yml.
        password=settings["password"],
        # The role decides what this session is allowed to do.
        role=settings.get("role", "ACCOUNTADMIN"),
        # database and warehouse are NOT passed here on purpose: on the very
        # first run they do not exist yet. The setup SQL creates them and then
        # selects them with USE DATABASE / USE WAREHOUSE.
    )


def run_setup_sql(connection) -> None:
    """Run every statement in setup/snowflake_setup.sql."""

    # Read the whole SQL file into one string.
    setup_sql = SETUP_SQL_FILE.read_text(encoding="utf-8")

    # execute_string() splits the text into single statements (it understands
    # comments and quotes) and runs them one after another, in order.
    connection.execute_string(setup_sql)


def read_header(local_file: Path) -> list[str]:
    """Return the column names found in the first line of a CSV or CSV.GZ file."""

    # Choose the right "open" function: gzip.open for .gz files, plain open otherwise.
    opener = gzip.open if local_file.suffix == ".gz" else open

    # "rt" = read as text. newline="" lets the csv module handle line endings itself.
    # "with" closes the file automatically, even if an error happens.
    with opener(local_file, "rt", encoding="utf-8", newline="") as file:
        # csv.reader yields one list per row. next() takes the first one: the header.
        return next(csv.reader(file))


def to_column_name(csv_column: str) -> str:
    """Turn a CSV header such as 'host id' into a safe Snowflake column name."""

    # Replace every character that is not a letter, digit or underscore with "_",
    # then make it upper-case, which is Snowflake's default for names.
    cleaned = re.sub(r"[^A-Za-z0-9_]", "_", csv_column.strip()).upper()

    # Squash several underscores in a row into one and remove them at both ends.
    cleaned = re.sub(r"_+", "_", cleaned).strip("_")

    # A header that is empty after cleaning cannot become a column.
    if not cleaned:
        raise ValueError(f"Cannot create a column name from: {csv_column!r}")

    # Wrap the name in double quotes. Quoting makes reserved words such as DATE
    # legal as column names. Because the name is upper-case, dbt models can still
    # refer to it without quotes (unquoted names are read as upper-case).
    return f'"{cleaned}"'


def load_file(cursor, table_name: str, local_file: Path) -> int:
    """Upload one file, rebuild its RAW table, load it, and return the row count."""

    # Stop clearly if the data file is not where we expect it.
    if not local_file.exists():
        raise SystemExit(f"Missing data file: {local_file}")

    # STEP a - PUT uploads a local file into a Snowflake stage.
    #   file://...           where the file is on this computer.
    #                        as_posix() writes the path with forward slashes.
    #                        Mac and Linux paths already look like that. On
    #                        Windows it turns C:\Users\me\file into
    #                        C:/Users/me/file, the form Snowflake needs inside
    #                        quotes. The quotes allow spaces in folder names.
    #   AUTO_COMPRESS=FALSE  upload as is (our big files are already gzipped)
    #   OVERWRITE=TRUE       replace a file of the same name left by an earlier run
    cursor.execute(f"PUT 'file://{local_file.as_posix()}' {STAGE_NAME} AUTO_COMPRESS=FALSE OVERWRITE=TRUE")

    # STEP b - build the column list from the file's own header.
    # Every column is VARCHAR (text). Loading raw data as text can never fail on a
    # bad date or number. dbt's staging models do the type conversion later.
    columns = ",\n    ".join(f"{to_column_name(name)} varchar" for name in read_header(local_file))

    # CREATE OR REPLACE drops the old table (if any) and creates an empty new one,
    # so running this script twice never doubles the data.
    cursor.execute(f"CREATE OR REPLACE TABLE RAW.{table_name} (\n    {columns}\n)")

    # STEP c - COPY INTO reads the staged file and inserts its rows into the table.
    cursor.execute(
        f"""
        COPY INTO RAW.{table_name}
        -- Which staged file to read.
        FROM {STAGE_NAME}/{local_file.name}
        -- How to read it: the named CSV format from the setup SQL.
        FILE_FORMAT = (FORMAT_NAME = {FILE_FORMAT_NAME})
        -- Stop and load nothing if any row is broken. Better no data than partial data.
        ON_ERROR = 'ABORT_STATEMENT'
        """
    )

    # Ask Snowflake how many rows the table now holds, so we can report it.
    cursor.execute(f"SELECT COUNT(*) FROM RAW.{table_name}")

    # fetchone() returns the single result row as a tuple. [0] is its first value.
    return cursor.fetchone()[0]


def main() -> None:
    """Run the whole load: settings, connection, setup, then every file."""

    # Step 1: read the login details from profiles.yml.
    settings = load_snowflake_settings()

    # Step 2: log in. "with" closes the connection automatically at the end.
    with connect(settings) as connection:

        # Create the database, warehouse, schemas, stage and file format.
        print("Creating Snowflake objects from setup/snowflake_setup.sql ...")
        run_setup_sql(connection)

        # A cursor is the object that sends SQL and receives results.
        with connection.cursor() as cursor:

            # Step 3: load the files one by one. items() gives (key, value) pairs.
            for table_name, local_file in FILES_TO_LOAD.items():
                # Tell the user what is happening. flush=True prints it immediately.
                print(f"Loading {local_file.name} into RAW.{table_name} ...", flush=True)
                # Do the PUT, CREATE and COPY for this file.
                row_count = load_file(cursor, table_name, local_file)
                # "{row_count:,}" prints the number with thousands separators.
                print(f"  loaded {row_count:,} rows")

    # Only reached when every step above succeeded.
    print("Snowflake RAW load complete.")


# This block runs only when the file is started directly ("python this_file.py").
# It does not run when another script imports this file.
if __name__ == "__main__":
    main()
