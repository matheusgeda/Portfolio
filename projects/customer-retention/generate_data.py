#!/usr/bin/env python3
"""Create a deterministic, fully synthetic customer-month retention dataset.

No real people, customers, company records, or outcomes are represented.
Uses Python's standard library only.
"""
from __future__ import annotations

import argparse
import csv
import random
from datetime import date
from pathlib import Path

START_MONTH = date(2024, 1, 1)
MONTH_COUNT = 18
SEGMENTS = (
    {"name": "Core", "weight": 0.43, "base_churn": 0.022, "usage_mean": 72, "plan": "Starter", "price": 45.00},
    {"name": "Growth", "weight": 0.30, "base_churn": 0.032, "usage_mean": 64, "plan": "Plus", "price": 75.00},
    {"name": "At risk", "weight": 0.19, "base_churn": 0.080, "usage_mean": 39, "plan": "Plus", "price": 75.00},
    {"name": "Premium", "weight": 0.08, "base_churn": 0.014, "usage_mean": 82, "plan": "Pro", "price": 180.00},
)
REGIONS = ("Europe", "Latin America", "North America", "Asia Pacific")
REGION_WEIGHTS = (0.32, 0.43, 0.18, 0.07)
CHANNELS = ("Organic", "Paid search", "Referral", "Partner", "Social")
CHANNEL_WEIGHTS = (0.30, 0.25, 0.20, 0.15, 0.10)
FIELDS = (
    "snapshot_month", "customer_id", "cohort_month", "plan_name", "region",
    "acquisition_channel", "segment", "tenure_months", "active_at_start",
    "churn_event", "active_at_end", "monthly_recurring_revenue",
    "usage_index", "support_contacts", "churn_risk_score",
)


def month_label(month_offset: int) -> date:
    """Return a month date, allowing offsets to cross year boundaries."""
    absolute = START_MONTH.year * 12 + START_MONTH.month - 1 + month_offset
    return date(absolute // 12, absolute % 12 + 1, 1)


def choose_weighted(rng: random.Random, values: tuple, weights: tuple):
    return rng.choices(values, weights=weights, k=1)[0]


def generate(output: Path, customer_count: int, seed: int) -> tuple[int, int]:
    rng = random.Random(seed)
    output.parent.mkdir(parents=True, exist_ok=True)
    rows_written = 0
    active_last_month = 0

    with output.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=FIELDS)
        writer.writeheader()

        for customer_number in range(1, customer_count + 1):
            segment = choose_weighted(rng, SEGMENTS, tuple(x["weight"] for x in SEGMENTS))
            cohort_index = rng.randrange(MONTH_COUNT)
            cohort_month = month_label(cohort_index)
            customer_id = f"SYN-{customer_number:06d}"
            region = choose_weighted(rng, REGIONS, REGION_WEIGHTS)
            channel = choose_weighted(rng, CHANNELS, CHANNEL_WEIGHTS)
            active = True

            for month_index in range(cohort_index, MONTH_COUNT):
                tenure = month_index - cohort_index
                usage = max(0.0, min(100.0, rng.gauss(segment["usage_mean"] - max(0, tenure - 5) * 0.45, 9)))
                support_choices = (0, 1, 2, 3, 4, 5)
                support_weights = (0.45, 0.28, 0.15, 0.08, 0.03, 0.01)
                support_contacts = choose_weighted(rng, support_choices, support_weights)

                active_at_start = int(active)
                if active:
                    early_lifecycle = 0.018 if tenure < 3 else 0.0
                    low_usage = 0.025 if usage < 35 else 0.0
                    support_signal = min(0.020, support_contacts * 0.004)
                    churn_probability = min(
                        0.40,
                        segment["base_churn"] + early_lifecycle + low_usage + support_signal,
                    )
                    risk_score = round(min(100.0, churn_probability * 400), 1)
                    churn_event = int(rng.random() < churn_probability)
                    active_at_end = int(not churn_event)
                    mrr = segment["price"]
                else:
                    risk_score = 0.0
                    churn_event = 0
                    active_at_end = 0
                    mrr = 0.0

                writer.writerow({
                    "snapshot_month": month_label(month_index).isoformat(),
                    "customer_id": customer_id,
                    "cohort_month": cohort_month.isoformat(),
                    "plan_name": segment["plan"],
                    "region": region,
                    "acquisition_channel": channel,
                    "segment": segment["name"],
                    "tenure_months": tenure,
                    "active_at_start": active_at_start,
                    "churn_event": churn_event,
                    "active_at_end": active_at_end,
                    "monthly_recurring_revenue": f"{mrr:.2f}",
                    "usage_index": f"{usage:.1f}" if active else "0.0",
                    "support_contacts": support_contacts if active else 0,
                    "churn_risk_score": f"{risk_score:.1f}",
                })
                rows_written += 1
                active = bool(active_at_end)
                if month_index == MONTH_COUNT - 1 and active:
                    active_last_month += 1

    return rows_written, active_last_month


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--customers", type=int, default=8420, help="number of synthetic customer profiles")
    parser.add_argument("--seed", type=int, default=20261028, help="fixed random seed for reproducibility")
    parser.add_argument("--output", type=Path, default=Path("data/customer_month.csv"), help="CSV output path")
    args = parser.parse_args()
    if args.customers < 1:
        parser.error("--customers must be a positive integer")
    rows, active = generate(args.output, args.customers, args.seed)
    print(f"Synthetic rows written: {rows:,}")
    print(f"Unique synthetic profiles: {args.customers:,}")
    print(f"Active at end of demo window: {active:,}")
    print(f"Output: {args.output}")


if __name__ == "__main__":
    main()
