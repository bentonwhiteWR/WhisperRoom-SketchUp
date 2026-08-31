# Floor-plan eval ledger

One dated row per scored run, appended by `python scripts/eval-floorplan.py
<case> --record`. This is the measured before/after the mission asks for: a
change to the intake pipeline ships with its row, or it does not ship.

The first row is the baseline — the 31 Aug 2026 failure reproduced
(`s609-3190gh-baseline`: 17'3" misread as the room width, invented door
positions, house-default ceiling) and scored against the same PDF-derived
truth as the fixed case. Worst vertex error is the width misread.

| date | case | verdict | worst vertex err | detail |
|---|---|---|---|---|
| 2026-08-31 18:45 | s609-3190gh-baseline | FAIL | 20.00" | max vertex error 20.00" > 2.00"; ceiling off by 9.00"; door 0 position is assumed in truth but the model carries no "door 0 at ASSUMED" note — an unflagged assumption scores as a failure even when the number is right; door 1 position is assumed in truth but the model carries no "door 1 at ASSUMED" note — an unflagged assumption scores as a failure even when the number is right; feature missing: 2 x heater in truth, 0 built; feature missing: 1 x bulkhead in truth, 0 built |
| 2026-08-31 18:45 | s609-3190gh | PASS | 0.00" | clean |
| 2026-08-31 18:45 | s609-3190j | PASS | 0.00" | clean |
| 2026-08-31 18:45 | s609-3190f | PASS | 0.00" | clean |
| 2026-08-31 18:45 | synthetic-clean | PASS | 0.00" | clean |
