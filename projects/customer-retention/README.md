# Customer Retention Intelligence

An independent analytics engineering case study for a fictional subscription service. All records and outcomes are synthetic. The project demonstrates a reproducible data workflow and an interactive dashboard concept without claiming client work or production impact.

## What this project demonstrates

- Reproducible customer-month data generation with a fixed random seed (Python standard library only).
- A PostgreSQL staging layer and star-shaped analytical model.
- Explicit event, denominator, cohort, revenue-exposure and risk-score definitions.
- SQL analysis for monthly churn, cohort retention, MRR exposure and state-transition checks.
- A browser-based interactive report concept with segment and time-window filters.

## Data contract

Run the generator from this directory:

\`python generate_data.py --customers 8420 --seed 20261028 --output data/customer_month.csv\`

The generator produces a synthetic customer-month CSV spanning 18 months from January 2024 through June 2025. It writes one row from signup through the end of the demo window, including inactive periods after a churn event. IDs use the \`SYN-\` prefix. No real customer data is used.

Fields:

| Field | Meaning |
| --- | --- |
| \`snapshot_month\` | First day of the month being observed |
| \`customer_id\` | Synthetic identifier |
| \`cohort_month\` | Signup month |
| \`plan_name\`, \`region\`, \`acquisition_channel\`, \`segment\` | Synthetic customer attributes |
| \`tenure_months\` | Completed months since signup |
| \`active_at_start\` | Active at the start of the month (0/1) |
| \`churn_event\` | Qualifying synthetic cancellation during the month (0/1) |
| \`active_at_end\` | Active after the monthly event (0/1) |
| \`monthly_recurring_revenue\` | Synthetic list price while active at month start |
| \`usage_index\` | Generated activity index from 0 to 100 |
| \`support_contacts\` | Generated monthly support-contact count |
| \`churn_risk_score\` | Transparent rule-based score from the generated monthly churn probability, scaled to 0–100 |

The generator includes early-tenure, low-usage, support-contact and segment-level signals so the analytical examples have patterns to inspect. This is a deterministic scenario generator, not a trained predictive model.

## Run the SQL model

Requires PostgreSQL and \`psql\`. From this folder:

\`\`\`sh
python generate_data.py
psql "$DATABASE_URL" -f schema.sql
psql "$DATABASE_URL" -f load_and_model.sql
psql "$DATABASE_URL" -f analysis.sql
\`\`\`

The schema defines a CSV-aligned staging table, customer/plan/month dimensions and a customer-month fact table. The load script copies the generated CSV, upserts dimensions and builds the fact table. Analysis queries use the fact and dimensions.

## Metric definitions

- **Monthly customer churn:** qualifying churn events divided by customers active at the beginning of the month.
- **Cohort retention:** members of a signup-month cohort still active at month end, divided by the cohort's starting size.
- **MRR exposure:** recurring revenue associated with active accounts above the selected rule-based score threshold. This is an investigation pool, not expected or saved revenue.
- **Risk score:** generated probability heuristic; not a classifier, calibrated probability, or customer decision.

## Dashboard note

The portfolio page contains a compact deterministic aggregate scenario so it can load instantly without a database or build step. The row-level generator is a separate reproducible artifact in the same project; both are synthetic and their individual sample values are not presented as real-world findings.

## Limitations and responsible use

The segment labels and churn mechanism are designed for demonstration. A production analysis would need stakeholder-approved churn definitions, privacy review, validation against observed outcomes, bias and stability checks, cost-sensitive threshold selection, and controlled measurement of any retention intervention. Association does not establish causation, and a score should support human review rather than automatically determine customer treatment.

## Files

- \`generate_data.py\` — deterministic synthetic CSV generator
- \`schema.sql\` — PostgreSQL staging and dimensional model
- \`load_and_model.sql\` — CSV load and idempotent model build
- \`analysis.sql\` — churn, cohort, exposure and data-quality queries
