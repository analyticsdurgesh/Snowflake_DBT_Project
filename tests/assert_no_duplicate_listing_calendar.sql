{#
================================================================================
tests/assert_no_duplicate_listing_calendar.sql        KIND: singular data test
================================================================================
PURPOSE
  Prove that fct_listing_calendar has at most ONE row per listing per date.

THE TWO KINDS OF dbt TEST
  1. GENERIC test   A reusable, ready-made check that you attach to a column in
                    a .yml file (not_null, unique, accepted_values,
                    relationships). You write no SQL.
  2. SINGULAR test  One .sql file in the tests/ folder holding a custom query
                    for one specific rule. This file is a singular test.
                    Use one when no generic test can express the rule.

THE GOLDEN RULE OF EVERY dbt TEST
  The query must SELECT THE ROWS THAT BREAK THE RULE.
      0 rows returned  ->  PASS  (nothing is wrong)
      1+ rows returned ->  FAIL  (each returned row is a problem to inspect)
  So you always write the test "backwards": describe what BAD data looks like.

WHY IS THIS A SINGULAR TEST?
  The built-in "unique" test checks ONE column. Our key is the COMBINATION of
  two columns (listing_id + calendar_date), so we write the check ourselves.

HOW TO RUN IT
  dbt test                                                   runs every test
  dbt test --select assert_no_duplicate_listing_calendar     runs only this one
  The test's name is the file name without ".sql".

dbt KEYWORD USED HERE
  ref('fct_listing_calendar')
      Points at the model being tested. It also tells dbt that this test
      belongs to that model, so "dbt build" runs it right after the model.
================================================================================
#}

select
    -- First half of the key.
    listing_id,
    -- Second half of the key.
    calendar_date,
    -- How many rows share this listing + date. It should always be 1.
    count(*) as row_count

{#- Compiles to: from AIRBNB_ANALYTICS.ANALYTICS.fct_listing_calendar #}
from {{ ref('fct_listing_calendar') }}

-- Put all rows with the same listing and date into one group.
group by listing_id, calendar_date

-- HAVING filters GROUPS after grouping (WHERE filters rows before grouping).
-- Keep only the groups with more than one row. Those are the duplicates.
-- No duplicates means no rows returned, which means the test passes.
having count(*) > 1
