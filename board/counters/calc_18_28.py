"""Recalculate the published interval from the adjacent archived CSV."""
import csv
from pathlib import Path

source = Path(__file__).with_name("board_1792401376269930700.csv")
with source.open(encoding="utf-8-sig", newline="") as handle:
    rows = list(csv.DictReader(handle))[:396]
if len(rows) != 396:
    raise ValueError("The published interval requires 396 counter windows")
total = sum(int(row["total_cycles"]) for row in rows)
gated = sum(int(row["gated_cycles"]) for row in rows)
print("windows:", len(rows))
print("end_host_time_s:", rows[-1]["time_s"])
print("total_cycles:", total)
print("gated_cycles:", gated)
print("reduction_percent:", round(100 * (total - gated) / total, 4))
