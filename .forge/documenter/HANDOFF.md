# Documenter HANDOFF — the Enhanced-booth session written up

2026-08-24. Scope: `DEVLOG.md` only. **No script was changed and `scripts/wr_tools/VERSION` was
not bumped** — this is a docs-only commit, so the update banner has nothing to announce.

## What was written

One new section under the existing `## 2026-08-24` heading, added *after* the TMG pottery stamp
material and before `## 2026-08-21 (Rev D)`:

- `### Done — Enhanced booth on the share-link path, and the exporter stops guessing`
- `### Still blocked — the Enhanced layout, and it gates everything downstream`

The pottery stamp content is untouched — `git diff --numstat DEVLOG.md` reports **156 insertions,
0 deletions**, so the change is a pure insertion by construction, not by inspection.

## What I verified myself rather than taking from the brief

Everything numeric in the entry was re-derived before it was written down.

- `P:\Sketchup\NewMasterComponentList\_enhanced-probe.tsv`: **112 data rows**; column 9 (`shells`)
  is `1` for all 112; column 10 (`gap`) is empty for all 112; 23 `FL` parts, every one at
  `0.3125`; `grep -c 24.4375` returns **0**.
- `_component-probe.tsv`: **182 data rows**; `83.0000` appears **0** times and `84.3125` appears
  **0** times. `81.0000` and `91.0000` appear 66 and 64 times respectively.
- Enhanced wall heights off the probe: **29 parts at 79.5000, 27 at 89.5000** (plus 4 each at
  79.4375 / 89.4375, the `NV`/`CBL`/`VNT` family). Note: `.forge/GOAL.md` says "30 and 24" for
  those two counts. Mine come from the current TSV. The 79.5000 / 89.5000 *values* agree; only the
  counts differ, so I wrote the values without counts rather than pick a side. **Worth a glance if
  anyone depends on the counts.**
- `46VntCP.skp` genuinely exists with no underscore, alongside `46Vnt_EFS_CP` and `46vnt_VSS_CP` —
  the case/separator inconsistency the fix addresses is real, not asserted.
- `scripts/angled-component-art.rb` line 24 still documents `CAMERA TARGET -> nearest component
  instance = the subject`. The stale resolution rule is confirmed present.
- VERSION at each commit: `1c84103`→1.5.3, `7841f14`→1.5.4, `8ea6a7d`→1.5.5, `72b84ab`→1.5.6,
  `78dc2ff`→1.5.7. The entry's version claims match the tree.

## Provenance discipline applied

The entry states plainly that the scripts were **syntax-checked only** with `scripts/rbparse.py`
and never executed outside SketchUp, **except** the probe and both exporter passes, which Benton
ran himself in SketchUp. Nothing is called "verified" that was only parsed. Geometry figures are
labelled **observed** and sourced to the TSV they came from.

## The things the entry exists to preserve

If any of these get lost the session's cost gets paid again:

1. The lesson — a heuristic inferring which component a scene means was wrong twice and corrupted
   files both times; explicit naming was right immediately.
2. The **failed raycast rewrite (v1.5.5)** is in the record, with the reason it failed (parallel
   projection, ~21,500 in lever arm) so nobody retries it.
3. **`24.4375` is not the gap.** The correction is written where a grep for that number will find
   it. The real air gap is still unknown.
4. The **83.0000 / 84.3125 panel-height correction**, written as a correction rather than an edit
   to the old entry, so the mistake stays findable.
5. Benton's five rulings, which no measurement can recover.
6. What is still blocked, given its own `###` heading rather than buried in prose.

## Not done, deliberately

- `.forge/GOAL.md` not touched, as instructed.
- No script touched, no VERSION bump.
- `scripts/angled-component-art.rb` is *reported* as carrying the stale rule, not fixed. That is a
  Builder job and it is named in the entry's open items.
