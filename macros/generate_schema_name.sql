{#
================================================================================
macros/generate_schema_name.sql  -  decides which schema each model is built in
================================================================================

THE PROBLEM THIS FILE SOLVES
  In dbt_project.yml we wrote "+schema: staging" for the staging folder.
  You would expect those models to land in a schema called STAGING.

  But dbt's BUILT-IN behaviour joins two names together:

        <default schema from profiles.yml>_<custom schema>
        ANALYTICS                        _ staging        =  ANALYTICS_STAGING

  dbt does this on purpose. In a team, every developer has their own default
  schema (for example DBT_ALICE), so their models land in DBT_ALICE_STAGING and
  never overwrite a colleague's work.

  For a single-user learning project that prefix is only confusing.
  We want clean names: STAGING, INTERMEDIATE, ANALYTICS.

HOW THE OVERRIDE WORKS
  generate_schema_name is a SPECIAL macro name. dbt calls it once for every
  model to ask "which schema should this model go in?".
  If a project defines a macro with this exact name, dbt uses the project's
  version instead of its built-in one. This is called OVERRIDING a macro.
  You never call this macro yourself. dbt calls it for you.

THE TWO ARGUMENTS (dbt fills them in automatically)
  custom_schema_name  the value of "+schema" for the model, for example
                      "staging". It is none (empty) when no +schema is set.
  node                an object describing the model being built (its name,
                      path, configs...). We do not need it here, but dbt
                      always passes it, so it must be in the argument list.
================================================================================
#}

{#- "macro ... endmacro" defines the macro. Whatever text is left after the
    logic below runs is the schema name dbt will use. -#}
{% macro generate_schema_name(custom_schema_name, node) -%}

    {#- "if ... is none" checks whether the model has NO custom schema.
        "is none" is Jinja's way of asking "is this value missing?". -#}
    {%- if custom_schema_name is none -%}

        {#- No custom schema: fall back to the default one.
            "target" is a built-in dbt variable holding the active connection
            from profiles.yml. target.schema is its "schema:" value (ANALYTICS).
            Other useful ones: target.name (dev), target.database, target.role. -#}
        {{ target.schema }}

    {#- "else" covers every model that DOES have a +schema setting. -#}
    {%- else -%}

        {#- Use the custom schema name exactly as written, with NO prefix.
            "| trim" is a Jinja FILTER. A filter takes the value on its left and
            transforms it. trim removes accidental spaces around the name. -#}
        {{ custom_schema_name | trim }}

    {#- "endif" closes the if / else block. -#}
    {%- endif -%}

{#- "endmacro" closes the macro definition. -#}
{%- endmacro %}
