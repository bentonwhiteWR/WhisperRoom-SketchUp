# HANDOFF — IEP tray orientation (v1.6.25), 2026-08-26

Supersedes the previous fixer handoff for this area. Prior notes in this folder
(`ROOTCAUSE-6060E-2026-08-26.md`, `PROBE-6060E-2026-08-26.md`,
`DEFECT-side-wall-flip-2026-08-26.md`) are still valid and untouched.

## Produced

- `scripts/build-booth-components.rb` — `IEP_CL_UPSIDE_DOWN` is now `nil` (= measure per
  part); new `iep_upside_down?(defn, kind, forced)`; `iep_deck` measures per tile and prints
  the decision with its reason. `IEP_FL_UPSIDE_DOWN` stays a declared `false`.
- `.forge/builder/replay-iep-deck.py` — new section 9, **31 assertions** (was 25), all pass.
- `scripts/wr_tools/VERSION` — 1.6.24 → **1.6.25**.
- `DEVLOG.md` — 2026-08-26 entry at the top.
- `.forge/fixer/replay-v1.6.25.txt`, `.forge/fixer/rbparse-v1.6.25.txt` — the two runs.

**Tree is left dirty and unpushed, deliberately.** Benton reviews and pushes.

## Read first

1. `.forge/GOAL.md` — mission unchanged; this is a defect off the Now list's booths.
2. `scripts/wr-deck.rb` ~lines 574–700 — `contact_z`, its two scars, `flat_levels`.
   **Not edited. Do not edit it** — the Standard path is live and cannot be run here.
3. `scripts/build-booth-components.rb` — the `IEP_CL_UPSIDE_DOWN` comment block and
   `iep_upside_down?`.
4. `.forge/fixer/replay-v1.6.25.txt` section 9 — the STD table, and the empty ENH table.

## Assumptions

- **assumed** the ENH CL parts really are trays (one closed plate, one open rim). Read off
  10 faces / 34 top entities in `_enhanced-probe.tsv` plus Benton's "engulfing" sentence —
  never off geometry.
- **assumed** `ENH 4872CL` is authored mouth-down. If it is not, the detector will flip the
  closed 4872 E. One-word revert: `IEP_CL_UPSIDE_DOWN = false`.
- **derived** that `contact_z` will frequently return its no-cue `false` on ENH parts (no
  1.0000 slab pair in a 1.7500 part). Not confirmed — no ENH part has ever been face-probed.

## Open questions

- **Which ENH CL families are authored which way up.** Unanswerable on this machine:
  `_face-levels.tsv` has **zero** ENH rows, and `_enhanced-probe.tsv`'s bands classify by
  extent so they cannot see which end is closed. To answer it: run `scripts/probe-levels.rb`
  on `P:/Sketchup/NewMasterComponentList` with an **EMPTY filter** (it OVERWRITES
  `_face-levels.tsv` — a `CL` filter would discard the wall panels and all FL rows), then
  re-run the harness.
- Whether any ENH tray needs re-saving in the library rather than flipping in code. The
  build console now names each one, which is the input to that call.
- Everything still open from the previous handoff: `SEAL_FL_DATUM_LIFT`, the 11.5 / 35.5
  room-prouds, and the global-vs-per-booth `IEP_WALL_LIFT` question.
