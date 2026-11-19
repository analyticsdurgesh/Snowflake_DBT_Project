{#
================================================================================
macros/cleaning.sql  -  reusable cleaning functions for the staging models
================================================================================

WHAT IS JINJA?
  Jinja is a small templating language that dbt runs BEFORE sending anything to
  Snowflake. A dbt .sql file is really "SQL with Jinja holes in it". dbt fills
  the holes, and the result is plain SQL. That step is called COMPILING.
  You can read the compiled result in target/compiled/ after any dbt command.

  Jinja has exactly three kinds of brackets:

    {{ ... }}   EXPRESSION. "Print the result here."
                Example: {{ clean_price('price') }} is replaced by the SQL text
                that the macro returns.

    {% ... %}   STATEMENT. "Do some logic." Nothing is printed by the tag itself.
                Used for: macro / endmacro, if / else / endif, for / endfor, set.

    curly-hash  COMMENT. Written as an opening curly bracket plus a hash sign,
                and closed by a hash sign plus a closing curly bracket. This
                whole block is one. It is removed during compiling and never
                reaches Snowflake. (A normal SQL comment, written with two
                dashes, is different: it STAYS in the compiled SQL.)

WHAT IS A MACRO?
  A macro is a function for SQL. You give it arguments and it returns a piece of
  SQL text. Macros stop you from copy-pasting the same expression everywhere:
  write the logic once here, call it from many models, fix it in one place.

  Definition:   {% macro name(argument) %} ...SQL text... {% endmacro %}
  Call:         {{ name('some_column') }}

  dbt automatically finds every macro in the macros/ folder. No import needed.

WHAT DO THE DASHES IN {%- AND -%} MEAN?
  A dash inside a Jinja bracket removes the whitespace (spaces and line breaks)
  on that side of the tag. It only makes the compiled SQL tidier.
  It has no effect on the query result.

IMPORTANT IDEA: a macro argument is TEXT, not data.
  When a model calls {{ clean_price('price') }}, the argument column_name holds
  the five letters p-r-i-c-e. The macro pastes that text into the SQL below.
  The macro itself never sees a single row of data. Snowflake does the real work
  later, when it runs the compiled SQL.
================================================================================
#}


{#
--------------------------------------------------------------------------------
clean_price(column_name)
  Turns a currency text such as "$1,234.50" into the number 1234.50.

  Example call in a model:    {{ clean_price('price') }} as nightly_price
  What Snowflake receives:    try_to_decimal(nullif(regexp_replace(
                                  price::string, '[^0-9.-]', ''), ''), 18, 2)
                              as nightly_price
--------------------------------------------------------------------------------
#}
{% macro clean_price(column_name) -%}
    {#- try_to_decimal(text, 18, 2) converts text into a number with up to 18
        digits in total and 2 after the decimal point. The "try_" version returns
        NULL when the text is not a valid number, instead of failing the query. #}
    try_to_decimal(
        {#- Read this line from the inside out:
            1) {{ column_name }} is replaced by the column name passed in.
            2) ::string casts the value to text (:: is Snowflake's cast operator).
            3) regexp_replace(text, '[^0-9.-]', '') deletes every character that
               is NOT a digit, a dot or a minus sign. Inside square brackets the
               ^ means "not". So "$1,234.50" becomes "1234.50".
            4) nullif(x, '') turns an empty text into NULL, because an empty
               text cannot be converted into a number. #}
        nullif(regexp_replace({{ column_name }}::string, '[^0-9.-]', ''), ''),
        {#- 18 = precision: the maximum number of digits in total. #}
        18,
        {#- 2 = scale: digits after the decimal point (cents). #}
        2
    )
{%- endmacro %}


{#
--------------------------------------------------------------------------------
clean_percent(column_name)
  Turns a percent text such as "98%" into the rate 0.98.
  Storing rates as 0-to-1 numbers makes later maths (averages, charts) simple.

  Example call:   {{ clean_percent('host_response_rate') }} as host_response_rate
--------------------------------------------------------------------------------
#}
{% macro clean_percent(column_name) -%}
    {#- Same cleaning steps as clean_price: keep only digits, dot and minus,
        turn empty text into NULL, then convert to a number. #}
    try_to_decimal(
        nullif(regexp_replace({{ column_name }}::string, '[^0-9.-]', ''), ''),
        {#- Up to 18 digits in total. #}
        18,
        {#- 4 decimal places, so a value like 98.55 is not rounded away. #}
        4
    {#- Divide by 100 to go from "98" (percent) to 0.98 (rate). #}
    ) / 100
{%- endmacro %}


{#
--------------------------------------------------------------------------------
to_boolean(column_name)
  Inside Airbnb stores yes/no values as the letters "t" and "f".
  This macro converts them into a real BOOLEAN (true / false).
  Unknown values stay NULL: we never guess.

  Example call:   {{ to_boolean('host_is_superhost') }} as is_superhost
--------------------------------------------------------------------------------
#}
{% macro to_boolean(column_name) -%}
    {#- CASE is SQL's if / else-if / else. The first WHEN that matches wins. #}
    case
        {#- Cast to text, trim() removes surrounding spaces, lower() makes it
            lower-case, so "T", " t " and "TRUE" are all recognised.
            IN (...) checks whether the value is one of the listed texts. #}
        when lower(trim({{ column_name }}::string)) in ('t', 'true', '1', 'yes', 'y') then true
        {#- The same check for every spelling of "false". #}
        when lower(trim({{ column_name }}::string)) in ('f', 'false', '0', 'no', 'n') then false
        {#- Anything else (empty, NULL, unexpected text) becomes NULL. #}
        else null
    {#- END closes the CASE expression. #}
    end
{%- endmacro %}
