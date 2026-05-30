# Streamlit Dashboard

This dashboard reads the final dbt mart models from Snowflake:

- `ANALYTICS.DIM_LISTINGS`
- `ANALYTICS.DIM_HOSTS`
- `ANALYTICS.AGG_NEIGHBOURHOOD_MONTHLY_PERFORMANCE`

Run it after `dbt run` succeeds:

```bash
streamlit run dashboard/streamlit_app.py
```

The app uses the same Snowflake environment variables as dbt.
