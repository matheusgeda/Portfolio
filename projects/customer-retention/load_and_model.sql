\set ON_ERROR_STOP on
-- Run from this folder using psql. The generator writes the CSV to data/customer_month.csv.
TRUNCATE TABLE retention_demo.stg_customer_month;\n\\copy retention_demo.stg_customer_month FROM 'data/customer_month.csv' WITH (FORMAT csv, HEADER true)

INSERT INTO retention_demo.dim_customer (customer_id, cohort_month, region, acquisition_channel, segment)
SELECT DISTINCT customer_id, cohort_month, region, acquisition_channel, segment
FROM retention_demo.stg_customer_month
ON CONFLICT (customer_id) DO UPDATE SET
    cohort_month = EXCLUDED.cohort_month,
    region = EXCLUDED.region,
    acquisition_channel = EXCLUDED.acquisition_channel,
    segment = EXCLUDED.segment;

INSERT INTO retention_demo.dim_plan (plan_name, monthly_list_price)
SELECT plan_name, MAX(monthly_recurring_revenue)
FROM retention_demo.stg_customer_month
GROUP BY plan_name
ON CONFLICT (plan_name) DO UPDATE SET
    monthly_list_price = EXCLUDED.monthly_list_price;

INSERT INTO retention_demo.dim_month (snapshot_month, calendar_year, quarter_number, month_number)
SELECT DISTINCT snapshot_month,
       EXTRACT(YEAR FROM snapshot_month)::SMALLINT,
       EXTRACT(QUARTER FROM snapshot_month)::SMALLINT,
       EXTRACT(MONTH FROM snapshot_month)::SMALLINT
FROM retention_demo.stg_customer_month
ON CONFLICT (snapshot_month) DO UPDATE SET
    calendar_year = EXCLUDED.calendar_year,
    quarter_number = EXCLUDED.quarter_number,
    month_number = EXCLUDED.month_number;

INSERT INTO retention_demo.fact_customer_month (
    snapshot_month, customer_id, plan_name, tenure_months, active_at_start,
    churn_event, active_at_end, monthly_recurring_revenue, usage_index,
    support_contacts, churn_risk_score
)
SELECT snapshot_month, customer_id, plan_name, tenure_months, active_at_start,
       churn_event, active_at_end, monthly_recurring_revenue, usage_index,
       support_contacts, churn_risk_score
FROM retention_demo.stg_customer_month
ON CONFLICT (snapshot_month, customer_id) DO UPDATE SET
    plan_name = EXCLUDED.plan_name,
    tenure_months = EXCLUDED.tenure_months,
    active_at_start = EXCLUDED.active_at_start,
    churn_event = EXCLUDED.churn_event,
    active_at_end = EXCLUDED.active_at_end,
    monthly_recurring_revenue = EXCLUDED.monthly_recurring_revenue,
    usage_index = EXCLUDED.usage_index,
    support_contacts = EXCLUDED.support_contacts,
    churn_risk_score = EXCLUDED.churn_risk_score;
