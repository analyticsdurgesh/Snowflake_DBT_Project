{#
================================================================================
tests/assert_non_negative_prices.sql                  KIND: singular data test
================================================================================
PURPOSE
  A business rule: a price can never be below zero.
  This test checks two different tables in one query.

HOW A dbt TEST WORKS (reminder)
  The query selects the rows that BREAK the rule.
      0 rows returned  ->  PASS
      1+ rows returned ->  FAIL
  A negative price would mean the cleaning macro kept a minus sign it should
  not have, or the source data is wrong. Either way we want to know.

WHY A SINGULAR TEST?
  None of the four built-in generic tests can say "must be zero or more", and
  this rule spans two models. A custom query in the tests/ folder handles both.

dbt KEYWORD USED HERE
  ref('model_name')
      Used twice. The test therefore depends on both models, and dbt makes
      sure both are built before the test runs.

HOW TO RUN IT
  dbt test --select assert_non_negative_prices
================================================================================
#}

-- Part 1: listings whose base price is negative.
select
    -- Which listing has the problem.
    listing_id,
    -- The bad value, under a shared column name so both parts line up.
    nightly_price as price_value,
    -- A text label saying where the bad value came from, to make failures easy to read.
    'dim_listings.nightly_price' as failing_field
{#- Compiles to: from AIRBNB_ANALYTICS.ANALYTICS.dim_listings #}
from {{ ref('dim_listings') }}
-- Keep only the rule-breaking rows. (NULL < 0 is not true, so NULL prices pass.)
where nightly_price < 0

-- UNION ALL stacks the rows of two queries on top of each other.
-- Both queries must return the same number of columns, in the same order.
-- ALL keeps every row. A plain UNION would also remove duplicates, which is slower.
union all

-- Part 2: calendar rows whose effective price is negative.
select
    -- Which listing has the problem.
    listing_id,
    -- The bad value.
    effective_nightly_price as price_value,
    -- Where it came from.
    'fct_listing_calendar.effective_nightly_price' as failing_field
{#- Compiles to: from AIRBNB_ANALYTICS.ANALYTICS.fct_listing_calendar #}
from {{ ref('fct_listing_calendar') }}
-- Keep only the rule-breaking rows.
where effective_nightly_price < 0
