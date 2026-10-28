-- Customer Retention Intelligence | PostgreSQL analysis queries
-- Every result describes only the generated synthetic dataset.

-- 1. Monthly customer churn by segment.
-- Denominator: customers active at the start of the snapshot month.
SELECT
    f.snapshot_month,
    c.segment,
    SUM(f.churn_event)::NUMERIC / NULLIF(SUM(f.active_at_start), 0) AS monthly_churn_rate,
    SUM(f.churn_event) AS churned_customers,
    SUM(f.active_at_start) AS starting_customers
FROM retention_demo.fact_customer_month AS f
JOIN retention_demo.dim_customer AS c USING (customer_id)
GROUP BY f.snapshot_month, c.segment
ORDER BY f.snapshot_month, c.segment;

-- 2. Cohort retention. The cohort size is fixed at its first recorded month;
-- later months count customers still active at the end of each snapshot.
WITH cohort_size AS (
    SELECT cohort_month, COUNT(*) AS customers_at_start
    FROM retention_demo.dim_customer
    GROUP BY cohort_month
),
cohort_activity AS (
    SELECT c.cohort_month, f.tenure_months,
           COUNT(*) FILTER (WHERE f.active_at_end = 1) AS active_customers
    FROM retention_demo.fact_customer_month AS f
    JOIN retention_demo.dim_customer AS c USING (customer_id)
    GROUP BY c.cohort_month, f.tenure_months
)
SELECT a.cohort_month, a.tenure_months, s.customers_at_start,
       a.active_customers::NUMERIC / NULLIF(s.customers_at_start, 0) AS cohort_retention
FROM cohort_activity AS a
JOIN cohort_size AS s USING (cohort_month)
ORDER BY a.cohort_month, a.tenure_months;

-- 3. Current MRR exposure for accounts over the illustrative risk threshold.
-- This is a prioritization pool, not a forecast of realized revenue loss.
WITH latest_month AS (
    SELECT MAX(snapshot_month) AS snapshot_month
    FROM retention_demo.fact_customer_month
)
SELECT c.segment, SUM(f.monthly_recurring_revenue) AS mrr_exposure,
       COUNT(*) AS accounts_in_review_pool,
       AVG(f.churn_risk_score) AS average_rule_based_risk_score
FROM retention_demo.fact_customer_month AS f
JOIN retention_demo.dim_customer AS c USING (customer_id)
JOIN latest_month AS lm USING (snapshot_month)
WHERE f.active_at_start = 1
  AND f.churn_risk_score >= 20
GROUP BY c.segment
ORDER BY mrr_exposure DESC;

-- 4. Data-quality reconciliation: impossible state transitions should return zero.
SELECT COUNT(*) AS invalid_state_rows
FROM retention_demo.stg_customer_month
WHERE churn_event > active_at_start
   OR active_at_end <> active_at_start - churn_event;
