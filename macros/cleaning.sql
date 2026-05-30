{% macro clean_price(column_name) -%}
    -- Convert currency strings such as "$1,234.50" into numeric values.
    try_to_decimal(
        nullif(regexp_replace({{ column_name }}::string, '[^0-9.-]', ''), ''),
        18,
        2
    )
{%- endmacro %}

{% macro clean_percent(column_name) -%}
    -- Convert percent strings such as "98%" into decimal rates such as 0.98.
    try_to_decimal(
        nullif(regexp_replace({{ column_name }}::string, '[^0-9.-]', ''), ''),
        18,
        4
    ) / 100
{%- endmacro %}

{% macro to_boolean(column_name) -%}
    -- Inside Airbnb stores booleans as t/f strings; keep nulls when values are unknown.
    case
        when lower(trim({{ column_name }}::string)) in ('t', 'true', '1', 'yes', 'y') then true
        when lower(trim({{ column_name }}::string)) in ('f', 'false', '0', 'no', 'n') then false
        else null
    end
{%- endmacro %}
