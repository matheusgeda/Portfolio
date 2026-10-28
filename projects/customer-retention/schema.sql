-- Customer Retention Intelligence | PostgreSQL schema
-- All source data is synthetic. Run from the project folder with psql.

CREATE SCHEMA IF NOT EXISTS retention_demo;

CREATE TABLE IF NOT EXISTS retention_demo.stg_customer_month (
    snapshot_month DATE NOT NULL,
    customer_id TEXT NOT NULL,
    cohort_month DATE NOT NULL,
    plan_name TEXT NOT NULL,
    region TEXT NOT NULL,
    acquisition_channel TEXT NOT NULL,
    segment TEXT NOT NULL,
    tenure_months INTEGER NOT NULL CHECK (tenure_months >= 0),
    active_at_start SMALLINT NOT NULL CHECK (active_at_start IN (0, 1)),
    churn_event SMALLINT NOT NULL CHECK (churn_event IN (0, 1)),
    active_at_end SMALLINT NOT NULL CHECK (active_at_end IN (0, 1)),
    monthly_recurring_revenue NUMERIC(12, 2) NOT NULL CHECK (monthly_recurring_revenue >= 0),
    usage_index NUMERIC(5, 1) NOT NULL CHECK (usage_index BETWEEN 0 AND 100),
    support_contacts SMALLINT NOT NULL CHECK (support_contacts >= 0),
    churn_risk_score NUMERIC(5, 1) NOT NULL CHECK (churn_risk_score BETWEEN 0 AND 100),
    PRIMARY KEY (snapshot_month, customer_id),
    CHECK (churn_event <= active_at_start),
    CHECK (active_at_end = active_at_start - churn_event)
);

CREATE TABLE IF NOT EXISTS retention_demo.dim_customer (
    customer_id TEXT PRIMARY KEY,
    cohort_month DATE NOT NULL,
    region TEXT NOT NULL,
    acquisition_channel TEXT NOT NULL,
    segment TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS retention_demo.dim_plan (
    plan_name TEXT PRIMARY KEY,
    monthly_list_price NUMERIC(12, 2) NOT NULL,
    currency_code CHAR(3) NOT NULL DEFAULT 'USD'
);

CREATE TABLE IF NOT EXISTS retention_demo.dim_month (
    snapshot_month DATE PRIMARY KEY,
    calendar_year SMALLINT NOT NULL,
    quarter_number SMALLINT NOT NULL CHECK (quarter_number BETWEEN 1 AND 4),
    month_number SMALLINT NOT NULL CHECK (month_number BETWEEN 1 AND 12)
);

CREATE TABLE IF NOT EXISTS retention_demo.fact_customer_month (
    snapshot_month DATE NOT NULL REFERENCES retention_demo.dim_month(snapshot_month),
    customer_id TEXT NOT NULL REFERENCES retention_demo.dim_customer(customer_id),
    plan_name TEXT NOT NULL REFERENCES retention_demo.dim_plan(plan_name),
    tenure_months INTEGER NOT NULL CHECK (tenure_months >= 0),
    active_at_start SMALLINT NOT NULL CHECK (active_at_start IN (0, 1)),
    churn_event SMALLINT NOT NULL CHECK (churn_event IN (0, 1)),
    active_at_end SMALLINT NOT NULL CHECK (active_at_end IN (0, 1)),
    monthly_recurring_revenue NUMERIC(12, 2) NOT NULL CHECK (monthly_recurring_revenue >= 0),
    usage_index NUMERIC(5, 1) NOT NULL,
    support_contacts SMALLINT NOT NULL,
    churn_risk_score NUMERIC(5, 1) NOT NULL,
    PRIMARY KEY (snapshot_month, customer_id),
    CHECK (churn_event <= active_at_start),
    CHECK (active_at_end = active_at_start - churn_event)
);

CREATE INDEX IF NOT EXISTS ix_fact_customer_month_customer
    ON retention_demo.fact_customer_month (customer_id, snapshot_month);
CREATE INDEX IF NOT EXISTS ix_fact_customer_month_risk
    ON retention_demo.fact_customer_month (snapshot_month, churn_risk_score)
    WHERE active_at_start = 1;
