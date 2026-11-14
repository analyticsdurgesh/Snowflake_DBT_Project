{#
  Why this file exists
  --------------------
  The models are written in Snowflake SQL, because Snowflake is what this
  project teaches. They also run, unchanged, on DuckDB: a free database that is
  just a file on your laptop (no account, no card, no 30-day trial clock).

  DuckDB already understands almost all of the SQL here. For the few Snowflake
  functions it does not have, this macro creates DuckDB versions with the same
  names before every dbt command (it is wired to `on-run-start` in
  dbt_project.yml). On Snowflake it renders nothing, so dbt skips it and the
  SQL Snowflake runs is exactly what you read in the models.

  Snowflake function            DuckDB stand-in created here
  ----------------------------  ------------------------------------------------
  '42'::number                  a NUMBER type = DECIMAL(38, 0), like Snowflake's
  try_to_number(x [, p, s])     try_cast; NULL instead of an error on bad text
  try_to_decimal(x [, p, s])    same, rounded to s decimal places
  try_to_date(x [, format])     try_cast / try_strptime; NULL on bad dates
  boolor_agg(x)                 bool_or(x)
#}
{% macro create_duckdb_compat() %}
  {%- if target.type == 'duckdb' -%}
    create or replace type main.number as decimal(38, 0);
    create or replace macro main.try_to_number(x) as try_cast(x as decimal(38, 0)),
        (x, p, s) as try_cast(round(try_cast(x as double), s) as double);
    create or replace macro main.try_to_decimal(x) as try_cast(x as decimal(38, 0)),
        (x, p, s) as try_cast(round(try_cast(x as double), s) as double);
    create or replace macro main.try_to_date(x) as try_cast(x as date),
        (x, fmt) as cast(try_strptime(x, fmt) as date);
    create or replace macro main.boolor_agg(x) as bool_or(x);
  {%- endif -%}
{% endmacro %}
