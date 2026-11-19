@echo off
rem ============================================================================
rem  setup_windows.bat  -  one-time setup for Windows
rem ============================================================================
rem  HOW TO RUN IT
rem      Double-click this file, or type  setup_windows.bat  in Command Prompt.
rem      Extract the ZIP file first. Do not run it from inside the ZIP.
rem
rem  WHAT IT DOES (the manual steps of HOW_TO_RUN.md, done for you)
rem      1. Finds a Python version this project supports (3.10 to 3.13).
rem      2. Creates the virtual environment in the folder .venv and installs
rem         the packages listed in requirements.txt into it.
rem      3. Creates profiles.yml from the template, if you do not have one yet.
rem      4. Leaves you in a window where the environment is already active.
rem
rem  It is safe to run again. It never overwrites an existing profiles.yml.
rem
rem  HOW TO READ A .bat FILE
rem      rem           a comment line, ignored by Windows
rem      @echo off     do not print each command before running it
rem      echo text     print text on the screen
rem      goto :name    jump to the line that says  :name
rem      errorlevel    the result of the last command (0 means it worked)
rem ============================================================================

rem Go to the folder this file is in. %~dp0 is that folder. /d also switches
rem the drive letter if needed.
cd /d "%~dp0"

rem If requirements.txt is not next to this file, the ZIP was not extracted.
if not exist "requirements.txt" goto :notextracted

echo.
echo == Step 1 of 3: looking for Python 3.10 to 3.13 ==
echo    This can take a moment.

rem PY will hold the Python command we decide to use. It starts empty.
set "PY="

rem "py" is the Python launcher that the python.org installer adds to Windows.
rem "py -3.13" starts Python 3.13 if it is installed. Try the versions in order
rem and keep the first one that works.
for %%V in (3.13 3.12 3.11 3.10) do (
    if not defined PY (
        py -%%V -c "import sys" >nul 2>&1 && set "PY=py -%%V"
    )
)
if defined PY goto :havepython

rem No launcher: try the plain "python" command and check its version.
python -c "import sys; raise SystemExit(0 if (3, 10) <= sys.version_info[:2] <= (3, 13) else 1)" >nul 2>&1
if not errorlevel 1 set "PY=python"
if not defined PY goto :nopython

:havepython
echo Using: %PY%
%PY% --version

echo.
echo == Step 2 of 3: creating the environment and installing the packages ==
echo    This takes a few minutes.

rem Create the virtual environment only if it does not exist yet.
if exist ".venv\Scripts\python.exe" goto :install
%PY% -m venv .venv
if errorlevel 1 goto :failed

:install
rem Install the packages with the environment's own Python. This works even
rem though the environment is not activated yet.
".venv\Scripts\python.exe" -m pip install -r requirements.txt
if errorlevel 1 goto :failed

echo.
echo == Step 3 of 3: creating profiles.yml ==

rem Copy the template only when profiles.yml does not exist, so a file you
rem already filled in is never overwritten.
if exist "profiles.yml" goto :haveprofile
copy "profiles.yml.example" "profiles.yml" >nul
echo Created profiles.yml from the template.
goto :done

:haveprofile
echo profiles.yml already exists. It was left unchanged.

:done
echo.
echo ==============================================================
echo  SETUP FINISHED
echo ==============================================================
echo  WITH A SNOWFLAKE ACCOUNT, type these commands one at a time in THIS window:
echo.
echo    1.  notepad profiles.yml
echo        Put your Snowflake account, user and password between
echo        the quotes. Save and close.
echo.
echo    2.  python run_pipeline.py
echo.
echo    3.  streamlit run dashboard/streamlit_app.py
echo.
echo  NO SNOWFLAKE ACCOUNT? The free path needs nothing filled in:
echo.
echo    1.  python run_pipeline.py --duckdb
echo.
echo    2.  streamlit run dashboard/streamlit_app.py -- --duckdb
echo.
echo  The virtual environment is already active in this window.
echo.

rem "cmd /k" keeps the window open and runs the activation script in it, so
rem the commands above work straight away.
cmd /k ".venv\Scripts\activate.bat"
exit /b 0

:notextracted
echo.
echo This file must be run from the extracted project folder.
echo Right-click the ZIP file, choose "Extract All", open the new folder,
echo and run setup_windows.bat from there.
echo.
pause
exit /b 1

:nopython
echo.
echo No Python between 3.10 and 3.13 was found on this computer.
echo.
echo Install Python 3.13 in one of these two ways, then run this file again:
echo.
echo    A. Open Command Prompt and type:
echo           winget install Python.Python.3.13
echo.
echo    B. Download a 3.13 "Windows installer (64-bit)" from
echo           https://www.python.org/downloads/windows/
echo       and tick "Add python.exe to PATH" on the first screen.
echo.
pause
exit /b 1

:failed
echo.
echo Setup stopped because the last step failed.
echo Read the messages above this line, fix the problem and run this file again.
echo.
pause
exit /b 1
