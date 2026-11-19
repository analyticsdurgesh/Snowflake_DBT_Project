#!/bin/bash
# ==============================================================================
# setup_mac.sh  -  one-time setup for Mac (also works on Linux)
# ==============================================================================
# HOW TO RUN IT
#     bash setup_mac.sh
#
# WHAT IT DOES (the manual steps of HOW_TO_RUN.md, done for you)
#     1. Finds a Python version this project supports (3.10 to 3.13).
#     2. Creates the virtual environment in the folder .venv and installs the
#        packages listed in requirements.txt into it.
#     3. Creates profiles.yml from the template, if you do not have one yet.
#
# It is safe to run again. It never overwrites an existing profiles.yml.
# ==============================================================================

# "set -e" stops the script at the first command that fails, so an error is
# never hidden by the steps that come after it.
set -e

# Go to the folder this script is in, so it works no matter where you call it
# from. "$0" is the path of this script and dirname gives its folder.
cd "$(dirname "$0")"

echo ""
echo "== Step 1 of 3: looking for Python 3.10 to 3.13 =="

# PY will hold the Python command we decide to use. It starts empty.
PY=""

# Try these commands in order and keep the first one that works.
# ${PYTHON:-} lets you choose one yourself:  PYTHON=python3.12 bash setup_mac.sh
for candidate in ${PYTHON:-} python3.13 python3.12 python3.11 python3.10 python3; do
    # "command -v" checks that the command exists on this computer.
    # The small Python program after -c exits with 0 (success) only when the
    # version is between 3.10 and 3.13.
    if command -v "$candidate" >/dev/null 2>&1 \
        && "$candidate" -c 'import sys; raise SystemExit(0 if (3, 10) <= sys.version_info[:2] <= (3, 13) else 1)' 2>/dev/null; then
        # Remember this command and stop looking.
        PY="$candidate"
        break
    fi
done

# -z is true when the text is empty: no suitable Python was found.
if [ -z "$PY" ]; then
    echo ""
    echo "No Python between 3.10 and 3.13 was found on this computer."
    echo "Install Python 3.13 from  https://www.python.org/downloads/macos/"
    echo "(choose a 3.13 release, then the 'macOS 64-bit universal2 installer')"
    echo "and run this script again."
    exit 1
fi

# Show which Python will be used.
echo "Using $PY  ($("$PY" --version))"

echo ""
echo "== Step 2 of 3: creating the environment and installing the packages =="
echo "   (this takes a few minutes)"

# Create the virtual environment only if it does not exist yet.
# -x is true when the file exists and can be run.
if [ ! -x .venv/bin/python ]; then
    "$PY" -m venv .venv
fi

# Install the packages into the virtual environment. Calling the environment's
# own Python means this works even though the environment is not "activated".
.venv/bin/python -m pip install -r requirements.txt

echo ""
echo "== Step 3 of 3: creating profiles.yml =="

# -f is true when the file exists. Copy the template only when it does not,
# so a profiles.yml you already filled in is never overwritten.
if [ ! -f profiles.yml ]; then
    cp profiles.yml.example profiles.yml
    echo "Created profiles.yml from the template."
else
    echo "profiles.yml already exists. It was left unchanged."
fi

echo ""
echo "=============================================================="
echo " SETUP FINISHED"
echo "=============================================================="
echo " Next, type these commands one at a time:"
echo ""
echo "   1.  open -e profiles.yml"
echo "       Put your Snowflake account, user and password between"
echo "       the quotes. Save and close."
echo ""
echo "   2.  source .venv/bin/activate"
echo ""
echo "   3.  python run_pipeline.py"
echo ""
echo "   4.  streamlit run dashboard/streamlit_app.py"
echo ""
