"""
================================================================================
run_pipeline.py  -  run the WHOLE project with one command
================================================================================
USAGE
    python run_pipeline.py                  run everything
    python run_pipeline.py --full-refresh   also rebuild incremental tables from zero
    python run_pipeline.py --dashboard      run everything, then open the dashboard
    python run_pipeline.py --duckdb         the free path: run on DuckDB, a database
                                            in one local file, with no Snowflake account

WHAT IT RUNS, IN ORDER
    Step 1  python scripts/load_inside_airbnb_to_snowflake.py
                Create the Snowflake objects and load the CSV files into RAW.
    Step 2  dbt debug --connection
                Check that dbt can read its config files and log in to Snowflake.
    Step 3  dbt run
                Build every model: staging views, intermediate views, mart tables.
    Step 4  dbt test
                Run every data quality test against what was just built.
    Step 5  dbt docs generate
                Build the documentation website files in target/.
    Step 6  streamlit run dashboard/streamlit_app.py     (only with --dashboard)

    If any step fails, the script stops immediately, so a broken load can never
    be followed by a "successful" dbt run on bad data.

THE dbt COMMANDS EXPLAINED
    dbt debug           A health check. Verifies dbt_project.yml, profiles.yml
                        and the connection. Always the first thing to try when
                        something does not work.
                        Plain "dbt debug" also checks that Git is installed and
                        reports an error when it is not, even though this
                        project never uses Git. Adding --connection skips that
                        one check, so the pipeline also runs on a computer
                        without Git (common on a new Windows machine).
    dbt run             Compiles every model (fills in the Jinja) and executes
                        it in Snowflake in dependency order. Creates the views
                        and tables.
    dbt test            Runs all generic tests (from the .yml files) and all
                        singular tests (from the tests/ folder).
    dbt docs generate   Writes manifest.json and catalog.json into target/.
                        View the site afterwards with:  dbt docs serve
    dbt build           (not used here) run + test together, model by model.
                        The steps are kept separate in this script so each one
                        is easy to see while learning.

    --profiles-dir .    Tells dbt to use the profiles.yml in the current folder
                        ("."). Without the flag dbt looks in the current folder
                        first and then in ~/.dbt/ in your home folder. The flag
                        makes the choice explicit.

WORKS ON MAC, LINUX AND WINDOWS
    Typing "dbt" in a terminal starts a small starter program: the file "dbt"
    in the folder ".venv/bin" on Mac, the file "dbt.exe" in the folder
    ".venv/Scripts" on Windows. Some Windows computers refuse to start that
    starter program, for example because security software blocks it.
    So this script does not use the starter programs. It starts dbt and
    Streamlit through the Python that is already running, which is the same
    Python the starter programs would call. See DBT and STREAMLIT below.
================================================================================
"""

# Store type hints as text so modern hint syntax works on older Python versions.
from __future__ import annotations

# argparse reads options such as --full-refresh from the command line.
import argparse

# importlib.util can check whether a Python package is installed.
import importlib.util

# subprocess starts other programs (dbt, python, streamlit) from this script.
import subprocess

# sys gives access to the Python interpreter that is running this script.
import sys

# time is used to measure how long each step takes.
import time

# Path is an object for file paths that works on every operating system.
from pathlib import Path


# The folder this file is in, which is the project root.
PROJECT_ROOT = Path(__file__).resolve().parent

# How this script starts dbt.
# Typing "dbt run" in a terminal starts a small starter program (dbt.exe on
# Windows) whose only job is to run the two Python instructions written below.
# We run those instructions ourselves with the Python that is already running:
#     sys.executable    the full path of that Python (the one inside .venv)
#     -c "..."          means "run this text as Python code"
#     prog_name='dbt'   the name dbt uses for itself in its help messages
# The result is exactly the same dbt, and it also works on a Windows computer
# that refuses to start dbt.exe.
DBT = [sys.executable, "-c", "from dbt.cli.main import cli; cli(prog_name='dbt')"]

# How this script starts Streamlit, for the same reason.
#     -m streamlit      means "run the installed package called streamlit"
STREAMLIT = [sys.executable, "-m", "streamlit"]

# The flag every dbt command needs so it finds profiles.yml in this folder.
PROFILES_FLAG = ["--profiles-dir", "."]


def check_installed(package: str) -> None:
    """Stop with clear instructions when a needed package is not installed."""

    # find_spec returns None when Python cannot find the package. That happens
    # when the virtual environment is not active or the install step was skipped.
    if importlib.util.find_spec(package) is None:
        raise SystemExit(
            f"The package '{package}' is not installed in this Python.\n"
            "Activate the virtual environment and install the requirements first:\n"
            "    Mac:      source .venv/bin/activate\n"
            "    Windows:  .venv\\Scripts\\activate\n"
            "    Both:     pip install -r requirements.txt"
        )


def as_typed(command: list[str]) -> str:
    """Return a command the way a person would type it in the terminal."""

    # A dbt command: show the short word "dbt" in place of the long start-up part.
    if command[: len(DBT)] == DBT:
        words = ["dbt", *command[len(DBT) :]]

    # A Streamlit command: the same idea.
    elif command[: len(STREAMLIT)] == STREAMLIT:
        words = ["streamlit", *command[len(STREAMLIT) :]]

    # Anything else is a Python script: show "python" in place of the full path.
    else:
        words = ["python", *command[1:]]

    # Join the words with spaces to make one line of text.
    return " ".join(words)


def run_step(title: str, command: list[str]) -> None:
    """Print a header, run one command, and stop the pipeline if it fails."""

    # A line of 78 "=" characters, used as a visual separator.
    line = "=" * 78

    # Print the header. flush=True shows it before the command's own output.
    print(f"\n{line}\n{title}\n{line}", flush=True)

    # Show the command the way you would type it yourself, so a learner can
    # copy it and run it by hand.
    print("$ " + as_typed(command), flush=True)

    # Remember the start time.
    started = time.time()

    # Run the command and wait for it to finish.
    #   cwd=PROJECT_ROOT  run it from the project root, wherever the user is
    #   the output streams straight to the terminal while it runs
    # "try" lets us catch two problems and explain them in one clear line,
    # where Python would otherwise print a long red error report.
    try:
        result = subprocess.run(command, cwd=PROJECT_ROOT)

    # Ctrl+C was pressed while the command was running.
    except KeyboardInterrupt:
        raise SystemExit(f"\nSTOPPED: Ctrl+C was pressed during: {title}")

    # The computer refused to start the command at all.
    except OSError as error:
        raise SystemExit(f"\nFAILED: {title}\nThis computer could not start the command: {error}")

    # Every program returns an exit code. 0 means success, anything else is an error.
    if result.returncode != 0:
        # Stop the whole pipeline and pass the same error code on.
        raise SystemExit(f"\nFAILED: {title} (exit code {result.returncode}). Pipeline stopped.")

    # Report how long the step took, rounded to whole seconds.
    print(f"Finished in {time.time() - started:.0f} seconds.", flush=True)


def parse_args() -> argparse.Namespace:
    """Define and read the command-line options."""

    # The parser also builds the help text shown by:  python run_pipeline.py --help
    parser = argparse.ArgumentParser(description="Run the Airbnb Snowflake + dbt pipeline end to end.")

    # action="store_true" makes it an on/off switch: False unless the flag is given.
    parser.add_argument(
        "--full-refresh",
        action="store_true",
        help="Drop and rebuild incremental models from zero (dbt run --full-refresh).",
    )

    # A second switch for starting the dashboard at the end.
    parser.add_argument(
        "--dashboard",
        action="store_true",
        help="Start the Streamlit dashboard after the pipeline succeeds.",
    )

    # A third switch: the free path. DuckDB is a small database that lives in one
    # file on this computer, so no Snowflake account is needed.
    parser.add_argument(
        "--duckdb",
        action="store_true",
        help="Run on DuckDB (free, one local file) instead of Snowflake.",
    )

    # Read the options the user typed and return them.
    return parser.parse_args()


def main() -> None:
    """Run every step of the pipeline in order."""

    # Read the command-line options.
    args = parse_args()

    # sys.executable is the Python running this script.
    python = sys.executable

    # Stop right away, with instructions, if dbt is not installed.
    check_installed("dbt")

    # Which database? Snowflake unless --duckdb was given.
    # profiles.yml holds two targets: "dev" (Snowflake, the default) and "duckdb".
    # target_flag is added to every dbt command below: it is empty for Snowflake
    # and ["--target", "duckdb"] for DuckDB.
    if args.duckdb:
        database_name = "DuckDB"
        loader = "scripts/load_inside_airbnb_to_duckdb.py"
        target_flag = ["--target", "duckdb"]
    else:
        database_name = "Snowflake"
        loader = "scripts/load_inside_airbnb_to_snowflake.py"
        target_flag = []

    # Remember when the whole pipeline started.
    pipeline_started = time.time()

    # Step 1: load the raw files. This also creates the database on a first run,
    # which is why it comes before the dbt connection check.
    run_step(
        f"STEP 1 of 5  Load raw CSV files into {database_name} (RAW schema)",
        [python, loader],
    )

    # Step 2: check the dbt configuration and the database connection.
    # --connection skips the "is Git installed?" check, which this project does
    # not need and which would stop the pipeline on a computer without Git.
    run_step(
        "STEP 2 of 5  dbt debug  (check configuration and connection)",
        [*DBT, "debug", "--connection", *target_flag, *PROFILES_FLAG],
    )

    # Step 3: build the models. Start with the basic command...
    # The star in *DBT unpacks the list, so its items become part of this list.
    dbt_run = [*DBT, "run", *target_flag, *PROFILES_FLAG]

    # ...and add --full-refresh when the user asked for it.
    if args.full_refresh:
        dbt_run.append("--full-refresh")

    run_step("STEP 3 of 5  dbt run  (build staging, intermediate and mart models)", dbt_run)

    # Step 4: run the data quality tests.
    run_step(
        "STEP 4 of 5  dbt test  (run data quality tests)",
        [*DBT, "test", *target_flag, *PROFILES_FLAG],
    )

    # Step 5: generate the documentation files.
    run_step(
        "STEP 5 of 5  dbt docs generate  (build the documentation site)",
        [*DBT, "docs", "generate", *target_flag, *PROFILES_FLAG],
    )

    # Every step succeeded if we get here.
    print("\n" + "=" * 78)
    print(f"PIPELINE COMPLETED SUCCESSFULLY in {time.time() - pipeline_started:.0f} seconds")
    print("=" * 78)

    # Optional step 6: start the dashboard. It keeps running until Ctrl+C.
    if args.dashboard:
        # Stop with instructions if Streamlit is not installed.
        check_installed("streamlit")

        # Everything after "--" is passed to the dashboard itself, not to
        # Streamlit: that is how the dashboard is told to read the DuckDB file.
        dashboard_flag = ["--", "--duckdb"] if args.duckdb else []

        run_step(
            "STEP 6  Streamlit dashboard  (press Ctrl+C to stop)",
            [*STREAMLIT, "run", "dashboard/streamlit_app.py", *dashboard_flag],
        )
    else:
        # Otherwise tell the user what they can do next.
        print("Next steps:")
        if args.duckdb:
            print("  streamlit run dashboard/streamlit_app.py -- --duckdb    open the dashboard")
            print("  dbt docs serve --target duckdb --profiles-dir .         browse the docs and lineage graph")
        else:
            print("  streamlit run dashboard/streamlit_app.py     open the dashboard")
            print("  dbt docs serve --profiles-dir .              browse the docs and lineage graph")


# Run main() only when this file is started directly, not when it is imported.
if __name__ == "__main__":
    main()
