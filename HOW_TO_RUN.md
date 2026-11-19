# How to Run This Project (Mac and Windows)

Follow these steps in order to run the whole project: load the data into Snowflake, build the dbt models, run the tests and open the dashboard.

- The first time takes about 10 minutes. Most of that is installing packages.
- After that, one command runs everything in about a minute.
- Where Mac and Windows need different commands, both are shown. Where only one block is shown, the command is the same on both.
- **No Snowflake account?** Use the free path: the same project on DuckDB, a database that lives in one file on your computer. Follow the same steps, skip everything about Snowflake, and add `--duckdb` where this file says so. See [The free path](#the-free-path-no-snowflake-account).

To understand what the project does, read [PROJECT_GUIDE.md](PROJECT_GUIDE.md).

## Contents

- [Before you start](#before-you-start)
- [Fast setup with one script](#fast-setup-with-one-script)
- [Part 1: One-time setup](#part-1-one-time-setup)
- [Part 2: Run the whole pipeline](#part-2-run-the-whole-pipeline)
- [The free path: no Snowflake account](#the-free-path-no-snowflake-account)
- [Part 3: Open the dashboard and the docs](#part-3-open-the-dashboard-and-the-docs)
- [Part 4: Run one step at a time](#part-4-run-one-step-at-a-time)
- [Part 5: Check the result in Snowflake](#part-5-check-the-result-in-snowflake)
- [Every time you come back](#every-time-you-come-back)
- [Start again from zero](#start-again-from-zero)
- [If something goes wrong](#if-something-goes-wrong)
- [Command cheat sheet](#command-cheat-sheet)

---

## Before you start

You need three things. On the free path you need only two: skip "A Snowflake account".

### 1. Python 3.10, 3.11, 3.12 or 3.13

Check which version you have.

**Mac**

```bash
python3 --version
```

**Windows**

```powershell
python --version
```

If the command is not found, or the version is older than 3.10, install Python 3.13.

A newer Python (3.14 or later) does not work with the package versions this project uses. If that is what you have, install Python 3.13 as well. Several Python versions can live side by side on one computer.

How to get Python 3.13:

| | How |
| --- | --- |
| **Mac** | Go to [python.org/downloads/macos](https://www.python.org/downloads/macos/), choose a 3.13 release and download the "macOS 64-bit universal2 installer" |
| **Windows** | Open Command Prompt and type `winget install Python.Python.3.13`. Or go to [python.org/downloads/windows](https://www.python.org/downloads/windows/), choose a 3.13 release, download the "Windows installer (64-bit)" and tick **Add python.exe to PATH** on its first screen. |

After installing, close the terminal and open a new one.

### 2. A Snowflake account

Skip this on the free path.

A free trial account works. Your user must be allowed to use the `ACCOUNTADMIN` role, because the project creates a database and a warehouse. The user of a trial account has this role.

You need three values from Snowflake:

| Value | Where to find it | Looks like |
| --- | --- | --- |
| Account identifier | In Snowflake, click your name at the bottom left, then **Account**, then **View account details**. Copy **Account identifier**. | `ORGNAME-ACCOUNTNAME` |
| Login name | The same screen. Copy **Login name**. | `YOUR_LOGIN_NAME` |
| Password | The password of that user | |

If you sign in to Snowflake without a password (for example with Google), set a password first. Open a SQL worksheet in Snowflake and run:

```sql
USE ROLE ACCOUNTADMIN;

-- Shows your user name. Copy it exactly, including upper and lower case.
SELECT CURRENT_USER();

-- Put your user name between the double quotes and choose your own strong password.
ALTER USER "your_user_name" SET PASSWORD = 'ChooseYourOwnStrongPassword';
```

### 3. The project folder

Have the project folder on your computer, unzipped if you downloaded it as a ZIP file. You do not need Git to run the project.

### Which terminal to use

| | Open it like this |
| --- | --- |
| **Mac** | Press `Cmd` + `Space`, type `Terminal`, press `Enter` |
| **Windows** | Open the Start menu, type `PowerShell`, press `Enter` |

The Windows commands in this file work in both PowerShell and Command Prompt.

---

## Fast setup with one script

The project includes a setup script for each system. It finds a suitable Python, creates the virtual environment, installs the packages and creates `profiles.yml`. That replaces steps 2 to 5 of Part 1.

**Mac**: open Terminal in the project folder (see Step 1 below) and type:

```bash
bash setup_mac.sh
```

**Windows**: open the project folder in File Explorer, click the address bar, type `cmd` and press `Enter`. In the window that opens, type:

```bat
setup_windows.bat
```

You can also double-click `setup_windows.bat`. If Windows shows "Windows protected your PC", click **More info** and then **Run anyway**.

When the script says `SETUP FINISHED`, continue with [Step 6](#step-6-put-your-snowflake-values-in-the-connection-file). On the free path there is nothing to fill in: go straight to [The free path](#the-free-path-no-snowflake-account). On a Mac, also do Step 3 (activate) before you run the pipeline. On Windows, the script leaves you in a window where the environment is already active.

---

## Part 1: One-time setup

Do these six steps once per computer. If you used the setup script above, you only need Step 6.

### Step 1: Go to the project folder

Replace the path with the place where your project folder is.

**Mac**

```bash
cd ~/Downloads/Snowflake-DBT-Project
```

**Windows**

```powershell
cd C:\Users\YourName\Downloads\Snowflake-DBT-Project
```

Tip for Windows: open the project folder in File Explorer, click the address bar, type `powershell` and press `Enter`. PowerShell opens already inside the folder.

Check that you are in the right place. This command lists the files, and you should see `run_pipeline.py` in the list.

**Mac**

```bash
ls
```

**Windows**

```powershell
dir
```

### Step 2: Create a virtual environment

A virtual environment is a private folder (`.venv`) that holds the Python packages for this project only, so they do not mix with anything else on your computer.

**Mac**

```bash
python3 -m venv .venv
```

**Windows**

```powershell
python -m venv .venv
```

If Windows says `python` is not recognized, try `py -m venv .venv`.

If you have several Python versions installed, name the one to use: `python3.13 -m venv .venv` on a Mac, `py -3.13 -m venv .venv` on Windows.

### Step 3: Activate the virtual environment

**Mac**

```bash
source .venv/bin/activate
```

**Windows**

```powershell
.venv\Scripts\activate
```

It worked if your prompt now starts with `(.venv)`.

If PowerShell says `running scripts is disabled on this system`, run the line below and then the activate command again. It changes the setting for this PowerShell window only.

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### Step 4: Install the packages

The same command on Mac and Windows. It takes a few minutes.

```bash
pip install -r requirements.txt
```

Check that dbt was installed:

```bash
dbt --version
```

You should see a version for `Core` and for the `duckdb` and `snowflake` plugins. `requirements.txt` installs both, so the same environment runs the Snowflake path and the free path.

### Step 5: Create your connection file

`profiles.yml` holds your Snowflake login. Create it by copying the template.

**Mac**

```bash
cp profiles.yml.example profiles.yml
```

**Windows**

```powershell
copy profiles.yml.example profiles.yml
```

### Step 6: Put your Snowflake values in the connection file

Skip this step on the free path. The `duckdb` part of `profiles.yml` needs no changes.

Open the file in a text editor.

**Mac**

```bash
open -e profiles.yml
```

**Windows**

```powershell
notepad profiles.yml
```

Find these three lines and replace only the text between the quotes with your own values from "Before you start":

```yaml
      account: "your_snowflake_account"
      user: "your_snowflake_username"
      password: "your_snowflake_password"
```

For example:

```yaml
      account: "ORGNAME-ACCOUNTNAME"
      user: "YOUR_LOGIN_NAME"
      password: "the password you chose"
```

Rules for this file:

- Keep the quotes. Keep the spaces at the start of each line exactly as they are.
- The account is only the identifier. Do not add `https://` or `.snowflakecomputing.com`.
- Leave every other line unchanged.
- Save the file and close the editor.

`profiles.yml` contains your password. It is ignored by git. Never share it or commit it.

---

## Part 2: Run the whole pipeline

One command, the same on Mac and Windows:

```bash
python run_pipeline.py
```

It runs five steps in order and stops at once if a step fails.

| Step | What happens | It worked if you see |
| --- | --- | --- |
| 1 | Creates the Snowflake database, warehouse and schemas, then loads the four data files into the `RAW` schema | `Snowflake RAW load complete.` |
| 2 | Checks that dbt can log in to Snowflake | `All checks passed!` |
| 3 | Builds the 13 dbt models | `Done. PASS=14 WARN=0 ERROR=0` |
| 4 | Runs the 47 data quality tests | `Done. PASS=47 WARN=1 ERROR=0` |

Why the counts are one higher than you might expect: before the models, dbt runs the start-up hook written under `on-run-start` in `dbt_project.yml`, and it counts as one more `PASS`. So step 3 shows 13 models + 1 = 14, and step 4 shows 46 passing tests + 1 = 47. `WARN=1` is on purpose: `neighbourhoods.csv` really does end with one blank row, and the test that spots it is set to warn instead of fail.
| 5 | Builds the documentation site | `Catalog written to ...` |

At the end you should see this. The number of seconds will differ.

```text
==============================================================================
PIPELINE COMPLETED SUCCESSFULLY in 66 seconds
==============================================================================
```

Two options:

```bash
python run_pipeline.py --full-refresh
```

Rebuilds the incremental table from zero. Use it after you replace the files in `data/raw/` with a different dataset.

```bash
python run_pipeline.py --dashboard
```

Runs the pipeline and then opens the dashboard.

It is safe to run the pipeline as many times as you like. Each run replaces the previous result.

---

## The free path: no Snowflake account

The project also runs on **DuckDB**, a free database that lives in one file (`airbnb.duckdb`) in the project folder. There is no account, no password and no trial that runs out. The dbt models are the same files. `macros/duckdb_compat.sql` gives DuckDB the few Snowflake functions it lacks, and does nothing on Snowflake.

Do Part 1 without Step 6 (or run the setup script), then type:

```bash
python run_pipeline.py --duckdb
```

The same five steps run, on DuckDB:

| Step | What happens | It worked if you see |
| --- | --- | --- |
| 1 | Creates `airbnb.duckdb` and loads the four data files into its `raw` schema | `DuckDB RAW load complete.` |
| 2 | Checks that dbt can open the DuckDB file | `All checks passed!` |
| 3 | Builds the 13 dbt models | `Done. PASS=14 WARN=0 ERROR=0` |
| 4 | Runs the 47 data quality tests | `Done. PASS=47 WARN=1 ERROR=0` |
| 5 | Builds the documentation site | `Catalog written to ...` |

`--full-refresh` and `--dashboard` work here too, for example `python run_pipeline.py --duckdb --dashboard`.

Afterwards you can check every layer in one command:

```bash
python scripts/verify_duckdb_build.py
```

Each line starts with `ok` or `FAIL`.

---

## Part 3: Open the dashboard and the docs

Both commands are the same on Mac and Windows. Each one keeps running until you stop it with `Ctrl` + `C`.

### The dashboard

```bash
streamlit run dashboard/streamlit_app.py
```

Your browser opens `http://localhost:8501`.

On the free path:

```bash
streamlit run dashboard/streamlit_app.py -- --duckdb
```

The two dashes mean "the rest is for the dashboard, not for Streamlit". If `profiles.yml` still holds the template's Snowflake values and `airbnb.duckdb` exists, the dashboard picks DuckDB by itself even without the flag. The caption under the title says which database it is reading.

- The first time, Streamlit asks for an email address in the terminal. Press `Enter` to skip it.
- Windows may ask whether to allow Python through the firewall. Either answer works, because the dashboard is used only on your own computer.

### The dbt documentation site

```bash
dbt docs serve --profiles-dir .
```

On the free path, add `--target duckdb`: `dbt docs serve --target duckdb --profiles-dir .`

Your browser opens `http://localhost:8080`. Click the blue circle at the bottom right of the page to see the lineage graph: a picture of how every model is built from the others.

Run the pipeline before this command. It needs the files that step 5 creates.

---

## Part 4: Run one step at a time

`run_pipeline.py` only runs the commands below, one after another. You can run them yourself to see each step on its own. All of them are the same on Mac and Windows. Run them from the project folder with the virtual environment active.

| Order | Command | What it does |
| --- | --- | --- |
| 1 | `python scripts/load_inside_airbnb_to_snowflake.py` | Loads the data files into the `RAW` schema |
| 2 | `dbt debug --connection --profiles-dir .` | Tests the connection to Snowflake |
| 3 | `dbt run --profiles-dir .` | Builds all models |
| 4 | `dbt test --profiles-dir .` | Runs all tests |
| 5 | `dbt docs generate --profiles-dir .` | Builds the documentation files |

On the free path, step 1 is `python scripts/load_inside_airbnb_to_duckdb.py` and every dbt command also gets `--target duckdb`, for example `dbt run --target duckdb --profiles-dir .`. A target is one of the named connections in `profiles.yml`. Without `--target`, dbt uses the default one, `dev`, which is Snowflake.

Every dbt command ends with `--profiles-dir .` (a space and a dot). The dot means "this folder". It tells dbt to use the `profiles.yml` in the project folder. dbt also finds that file by itself when you run the command from the project folder, so the flag is a safety habit, not a requirement.

Useful variations once the full pipeline has run at least once:

| Command | What it does |
| --- | --- |
| `dbt run --select staging --profiles-dir .` | Builds only the 4 models in the `staging` folder |
| `dbt run --select dim_hosts --profiles-dir .` | Builds one model |
| `dbt test --select dim_hosts --profiles-dir .` | Runs only the tests of one model |
| `dbt run --full-refresh --select fct_listing_calendar --profiles-dir .` | Rebuilds the incremental table from zero |
| `dbt ls --resource-type model --profiles-dir .` | Lists every model in the project |

---

## Part 5: Check the result in Snowflake

Open a SQL worksheet in Snowflake and run:

```sql
select table_schema, table_name, table_type, row_count
from AIRBNB_ANALYTICS.INFORMATION_SCHEMA.TABLES
where table_schema in ('RAW', 'STAGING', 'INTERMEDIATE', 'ANALYTICS')
order by table_schema, table_name;
```

You should get 17 rows: 10 tables and 7 views. Views show no row count because they store no data.

| Schema | Table | Rows |
| --- | --- | ---: |
| `RAW` | `LISTINGS` | 500 |
| `RAW` | `CALENDAR` | 182,500 |
| `RAW` | `REVIEWS` | 30,251 |
| `RAW` | `NEIGHBOURHOODS` | 16 |
| `ANALYTICS` | `DIM_LISTINGS` | 500 |
| `ANALYTICS` | `DIM_HOSTS` | 200 |
| `ANALYTICS` | `FCT_LISTING_CALENDAR` | 182,500 |
| `ANALYTICS` | `FCT_REVIEWS` | 30,251 |
| `ANALYTICS` | `AGG_LISTING_MONTHLY_PERFORMANCE` | 6,500 |
| `ANALYTICS` | `AGG_NEIGHBOURHOOD_MONTHLY_PERFORMANCE` | 195 |

**On the free path** there is no worksheet. Ask DuckDB from Python instead, with the virtual environment active and the dashboard stopped. The same command on Mac and Windows:

```bash
python -c "import duckdb; print(duckdb.connect('airbnb.duckdb', read_only=True).sql('select table_schema, table_name, table_type from information_schema.tables order by 1, 2'))"
```

It prints the same 17 tables and views, with lower-case names. To count rows, put a query such as `select count(*) from analytics.dim_listings` between the single quotes instead.

---

## Every time you come back

The setup is already done. In a new terminal you need only three commands.

**Mac**

```bash
cd ~/Downloads/Snowflake-DBT-Project
source .venv/bin/activate
python run_pipeline.py
```

**Windows**

```powershell
cd C:\Users\YourName\Downloads\Snowflake-DBT-Project
.venv\Scripts\activate
python run_pipeline.py
```

On the free path, the last command is `python run_pipeline.py --duckdb`.

To leave the virtual environment when you are finished (both systems):

```bash
deactivate
```

---

## Start again from zero

**Delete everything the project created in Snowflake.** Run this in a Snowflake worksheet. It permanently removes the database and all its tables. The next pipeline run creates it again.

```sql
drop database if exists AIRBNB_ANALYTICS;
```

**On the free path**, delete the file `airbnb.duckdb` in the project folder instead. The next `python run_pipeline.py --duckdb` creates it again.

**Delete the files dbt generated on your computer** (the `target` folder). The same command on Mac and Windows:

```bash
dbt clean --profiles-dir .
```

**Rebuild the Python environment.** Delete the `.venv` folder, then repeat steps 2 to 4 of Part 1.

Mac

```bash
deactivate
rm -rf .venv
```

Windows (PowerShell)

```powershell
deactivate
Remove-Item -Recurse -Force .venv
```

The folders `target` and `logs` and the file `.user.yml` are created by dbt on every run. They are safe to delete at any time.

---

## If something goes wrong

First, scroll up to the first line that says `ERROR` or `FAILED`. The real cause is usually there, not at the bottom.

| What you see | Why | What to do |
| --- | --- | --- |
| Windows: `'python' is not recognized`, or the Microsoft Store opens | Python is not installed, or not on the PATH | Install Python from python.org with **Add python.exe to PATH** ticked. Open a new terminal. Or use `py` instead of `python`. |
| Mac: `command not found: python` | On a Mac the command is `python3` until the virtual environment is active | Use `python3` in step 2. After step 3, `python` works. |
| PowerShell: `running scripts is disabled on this system` | Windows blocks the activation script | Run `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`, then activate again |
| `dbt: command not found` or `'dbt' is not recognized` | The virtual environment is not active in this terminal window | Do step 3 again. The prompt must start with `(.venv)`. |
| `The package 'dbt' is not installed in this Python` | The same, or the packages are not installed | Do steps 3 and 4 |
| Windows refuses to start `dbt` or `streamlit`, although the prompt starts with `(.venv)` | Some Windows computers block the small starter programs `dbt.exe` and `streamlit.exe`. Security software can do this. | `python run_pipeline.py` does not use them, so it still works. For a single command, type `python -m dbt.cli.main` in place of `dbt`, and `python -m streamlit` in place of `streamlit`. Example: `python -m dbt.cli.main run --profiles-dir .` A `RuntimeWarning` line at the top is harmless. |
| `pip install` fails with `No matching distribution found` | Your Python is older than 3.10 | Install Python 3.13 (see "Before you start"), delete the `.venv` folder and start again from step 2 |
| Every `dbt` command ends in a long error that mentions `mashumaro` or `UnserializableField` | Your Python is 3.14 or newer. The packages install, but dbt cannot start. | The same fix: install Python 3.13, delete the `.venv` folder and start again from step 2 |
| `Missing profiles.yml` | The connection file was not created | Do step 5 |
| `Update profiles.yml: the value for 'account' is missing.` | A line still has the placeholder text | Do step 6 |
| An error that names `profiles.yml` and a line number | A quote or the spacing was changed by accident | Do step 5 again to get a fresh copy, then change only the text between the quotes |
| `404 Not Found` with a `snowflakecomputing.com` address | The account identifier is wrong | Copy it again from **View account details**. It has the form `ORGNAME-ACCOUNTNAME` with a hyphen. |
| `Incorrect username or password was specified` | The login name or password is wrong | Check both by signing in on the Snowflake website with the same values |
| `1 check failed: Error from git --help` | You ran `dbt debug` without `--connection` on a computer without Git | Use `dbt debug --connection --profiles-dir .` |
| The dashboard shows an error that an object does not exist | The pipeline has not been run yet | Run `python run_pipeline.py` first (`python run_pipeline.py --duckdb` on the free path) |
| `IO Error: Could not set lock on file ... airbnb.duckdb` | Another program has the DuckDB file open for writing, for example a second pipeline run or a Python window | Close that program (`Ctrl` + `C` in its terminal) and run the command again |
| The dashboard caption says Snowflake, but you want DuckDB | `profiles.yml` holds real Snowflake values, so the dashboard uses them | Start it with `streamlit run dashboard/streamlit_app.py -- --duckdb` |
| `FAILED: STEP ...` at the end of the pipeline | One step stopped | Read the lines above the message, fix the cause, and run the pipeline again |

---

## Command cheat sheet

| Task | Mac | Windows |
| --- | --- | --- |
| Check Python | `python3 --version` | `python --version` |
| Create the environment | `python3 -m venv .venv` | `python -m venv .venv` |
| Activate it | `source .venv/bin/activate` | `.venv\Scripts\activate` |
| Install packages | `pip install -r requirements.txt` | same |
| Create the connection file | `cp profiles.yml.example profiles.yml` | `copy profiles.yml.example profiles.yml` |
| Edit the connection file | `open -e profiles.yml` | `notepad profiles.yml` |
| Run everything | `python run_pipeline.py` | same |
| Run everything, free path | `python run_pipeline.py --duckdb` | same |
| Open the dashboard | `streamlit run dashboard/streamlit_app.py` | same |
| Open the dashboard, free path | `streamlit run dashboard/streamlit_app.py -- --duckdb` | same |
| Open the docs | `dbt docs serve --profiles-dir .` | same |
| Open the docs, free path | `dbt docs serve --target duckdb --profiles-dir .` | same |
| Stop the dashboard or docs | `Ctrl` + `C` | same |
| Leave the environment | `deactivate` | same |
