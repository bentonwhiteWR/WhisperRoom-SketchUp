# This baseline predates 1.19.10 — eight keys record the mirrored side walls

Written by the Fixer, 2026-09-02. **Not regenerated**: there is no SketchUp on the
machine that shipped 1.19.10, and a golden captured live cannot honestly be
hand-edited. Nothing in these folders was touched.

## What is stale, and why

Every manifest here was captured on 2026-08-30 through
`WR_BuildBoothComponents::ASSIGN[key]` (`scripts/rbtest-live-booth.py:235`) on plugin
1.9.0, when `ASSIGN` still swapped the E/W slot names on the four split-run booths and
`gen-booth.py` still swapped the 40/16 positions on the 60-series. Audit 2026-09-01
finding 1 and Benton's 2026-09-02 ruling (wide panel at the door end, every split-run
model) removed both. So these files hold the DEFECT as expected output for:

| folder | keys | what the .txt records that is now wrong |
|---|---|---|
| `dry/` | MDL 6060 S, 6060 E, 6084 S, 6084 E | six `rebalanced E1/E0/W1/W0 ...` lines and two `seal shifted +24.000` lines per shell — the 40 re-walked to y 2..42 from a 16-wide slot |
| `dry/` | MDL 7272 S, 7272 E, 7296 S, 7296 E | the same, the other way: `rebalanced E0 22PanelSolid 2.000..24.000 (slot was 2.000..48.000)`, the 46 pushed to y 26..72 |
| `build/` | MDL 6060 S, 6060 E | as `dry/` for the 6060, plus the census bounds of the E/W wall instances and the two mid-wall seals at the old ends |

`build/MDL-102186-E`, `build/MDL-96192-E`, `build-efp/*` and the other 42 `dry/` keys are
unaffected: their side walls are symmetric or three-panel and neither swap ever touched
them (`scripts/rbtest-side-wall-order.py` asserts that both paths agree on all 50 keys).

## What the next live run should show for those eight keys

- **No `rebalanced` line at all** on any E or W wall — every part is now the width of
  its slot on both paths, so `rebalance_walls` has nothing to do.
- Outer shell, both side walls: 46 at y 2..48 and 22 at y 50..72 on the 72-series;
  40 at y 2..42 and 16 at y 44..60 on the 60-series. Mid-wall seal centred y 49 / y 43.
- Inner shell (E keys): 41.5 at y 4.25..45.75, 17.5 at y 52.25..69.75 (72-series);
  35.5 at y 4.25..39.75, 11.5 at y 46.25..57.75 (60-series).

`python scripts/rbtest-live-booth.py diff <this folder>` will therefore report exactly
those eight keys as CHANGED (two in `build/`). **That is the expected result, not a
regression.** Once the new run has been eyeballed against the table above, replace the
eight manifests and delete this note. Any OTHER key reporting CHANGED is a finding.
