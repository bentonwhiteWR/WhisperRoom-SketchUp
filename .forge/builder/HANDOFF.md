# Builder handoff — roof-mounted ventilation, the roof unit is seated (plugin 1.14.0)

## Produced
- `scripts/wr-roof-vent.rb` — the seating rule (`seat`, `flush_right`,
  `FLUSH_RIGHT_MODELS`, `NOMINAL_INSET`), `unit_height` now quoting the measured
  part, `roof_unit_blockers` down to one reason, `seating_note` per booth.
- `scripts/wr-overlays.rb` — `place_roof_unit`: loads `RM<model>[VSS].skp`,
  cross-checks it against the `MEASURED` table, seats it on the booth's
  **measured** roof plane, refuses by name at every step.
- `scripts/build-booth-components.rb` — loads `wr-roof-vent.rb`.
- `scripts/booth-from-link.rb` — passes `roof_vent` / `roof_vss` / `roof_efs`,
  computes the blocker list once, and reports seated-vs-refused.
- `scripts/rbtest-roofvent.py` — 72 checks became 137, mutation table in the docstring.
- `.forge/builder/roof-vent/seat-shot.py` — builds and photographs the booths live.
- `.forge/roof-vent-placement.md` — rewritten; the spec now records the resolution.
- `DEVLOG.md` entry, `scripts/wr_tools/VERSION` -> 1.14.0.

## Read first
1. `scripts/wr-roof-vent.rb`'s header — the rule, the orientation convention, and
   what is still refused, in one place.
2. `.forge/roof-vent-placement.md` — the same for a non-code reader, with the
   pixel measurements from the viewport proof.
3. `.forge/builder/roof-vent/seat-shot.py`'s docstring — what the pictures showed.

## Assumptions
- **The flush-right shift is keyed to MODEL WIDTH, not to the EFS flag.** Benton
  gave EFS as the reason but named all four 84-in-wide models unconditionally.
  A `6084` with no EFS is therefore shifted. Printed on every build so he can
  correct it; a one-line change to `FLUSH_RIGHT_MODELS` if he does.
- `Right` = `+x` = the E wall, from `WALL_WORD` + `wr-booth-data.rb` (observed),
  and confirmed in the viewport. Not intuition.

## Open questions
- The `6084`-without-EFS case above.
- `live-rm-report.py --hx / --efs / --vss / --nopart` could not be re-run after
  the final `booth-from-link.rb` refactor: Benton's saved
  `Master Component List.skp` became the active model and the guard refuses, as
  designed. The default mode passed after that refactor; the other four are
  unverified against the last commit and should be re-run against an Untitled
  model. `seat-shot.py`'s four cases all passed before the refactor.
