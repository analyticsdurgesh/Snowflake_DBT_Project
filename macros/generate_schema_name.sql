{% macro generate_schema_name(custom_schema_name, node) -%}
    {# Use classroom-friendly schema names: RAW, STAGING, INTERMEDIATE, ANALYTICS. #}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
