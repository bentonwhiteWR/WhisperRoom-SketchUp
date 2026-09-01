# Floor-plan eval ledger

One dated row per scored run, appended by `python scripts/eval-floorplan.py
<case> --record`. This is the measured before/after the mission asks for: a
change to the intake pipeline ships with its row, or it does not ship.

The first row is the baseline — the 31 Aug 2026 failure reproduced
(`s609-3190gh-baseline`: 17'3" misread as the room width, invented door
positions, house-default ceiling) and scored against the same PDF-derived
truth as the fixed case. Worst vertex error is the width misread.

Row verdicts: `PASS` on a refusal case means the checker refused BY NAME —
that row is regression protection for a refusal, and it going FAIL means the
refusal was silently un-fixed. `PASS` on a planted-defect case
(`*-trap`, `*-unflagged`) means the SCORER caught a defect the checker
validated clean. `PROBE` is a case run before anyone knew the right answer;
its README carries the verdict.

## Findings — adversarial batch, 31 Aug 2026 (synthetic case sweep)

The `synthetic-*` cases from `eval/gen-plans.py` surfaced these. **None are
fixed here** — F1–F3 live in files owned by other in-flight Builders and are
recorded so they cannot be lost; the reproducing case pins each one.

- **F1 — pinched polygon builds silently** (`synthetic-selfcross`). Seven
  runs that sum to zero but revisit a vertex validate, build, and produce a
  single 7-vertex two-lobe floor face with no message. Fix belongs in
  `scripts/takeoff-check.py` (self-intersection check on the walked
  polygon). The exact silent-wrong-geometry class of 31 Aug.
  **FIXED, 1.12.4** — `polygon_self_touch` in `takeoff-check.py` refuses
  revisited corners, doubling-back runs and crossing non-adjacent runs by
  name after closure; the case is flipped to
  `expects: {"refusal": [...]}` and the ledger row above records the PASS.
- **F2 — impossible bulkhead silently dropped** (`synthetic-headroom`).
  Bulkhead head 9'0" above an 8'0" ceiling: `scripts/build-takeoff.rb`
  `build_feature` hits `return if ... z1 - z0 <= TOL` (~line 317) and the
  massing never exists — no refusal, no note. Only the scorer's
  feature-missing check catches it.
- **F3 — door taller than its ceiling builds through it**
  (`synthetic-headroom`). An 8'6" leaf in an 8'0" room builds 6" through
  the ceiling plane, silently. Should refuse by name in the checker.
- **F4 — working-tree `scripts/takeoff-check.py` crashed on every
  invocation** during this sweep (module-level `TypeError: not enough
  arguments for format string` in its CSS block — an unescaped `%` in an
  uncommitted edit by the concurrent Builder). The 19:59 rows were scored
  against the last committed checker (cc12b62), pinned via the scorer's new
  `WR_TAKEOFF_CHECK` override. **RESOLVED mid-session**: the concurrent
  Builder's fix landed in the working tree and the 20:04–20:05 rows —
  the whole suite re-run unpinned — behave identically against it.
- Measured residual risk, by design: `synthetic-clearwidth-trap` proves a
  clear-width mis-transcription WITHOUT a recorded chain validates clean and
  builds a room 24.00" wrong — only the scorer sees it. The parts invariant
  protects exactly those who record the chain; the protocol doc must keep
  saying so.

| date | case | verdict | worst vertex err | detail |
|---|---|---|---|---|
| 2026-08-31 18:45 | s609-3190gh-baseline | FAIL | 20.00" | max vertex error 20.00" > 2.00"; ceiling off by 9.00"; door 0 position is assumed in truth but the model carries no "door 0 at ASSUMED" note — an unflagged assumption scores as a failure even when the number is right; door 1 position is assumed in truth but the model carries no "door 1 at ASSUMED" note — an unflagged assumption scores as a failure even when the number is right; feature missing: 2 x heater in truth, 0 built; feature missing: 1 x bulkhead in truth, 0 built |
| 2026-08-31 18:45 | s609-3190gh | PASS | 0.00" | clean |
| 2026-08-31 18:45 | s609-3190j | PASS | 0.00" | clean |
| 2026-08-31 18:45 | s609-3190f | PASS | 0.00" | clean |
| 2026-08-31 18:45 | synthetic-clean | PASS | 0.00" | clean |
| 2026-08-31 19:59 | synthetic-clean | PASS | 0.00" | clean |
| 2026-08-31 19:59 | synthetic-nonclosing | PASS | — | refused by name as designed: runs do not close |
| 2026-08-31 19:59 | synthetic-missing | PASS | — | refused by name as designed: no position on run 0; noceil ceiling |
| 2026-08-31 19:59 | synthetic-cornerdoor | PASS | — | refused by name as designed: touches the corner; overlap |
| 2026-08-31 19:59 | synthetic-nasty | PASS | 0.00" | clean |
| 2026-08-31 19:59 | synthetic-jog | PASS | 0.00" | clean |
| 2026-08-31 19:59 | synthetic-units | PASS | 0.00" | clean |
| 2026-08-31 19:59 | synthetic-clearwidth | PASS | 0.00" | clean |
| 2026-08-31 19:59 | synthetic-clearwidth-trap | PASS | 24.00" | planted defect detected (checker-silent by design): max vertex error 24.00" > 0.10"; feature missing: 2 x heater in truth, 0 built |
| 2026-08-31 19:59 | synthetic-unflagged | PASS | 0.00" | planted defect detected (checker-silent by design): door 0 position is assumed in truth but the model carries no "door 0 at ASSUMED" note — an unflagged assumption scores as a failure even when the number is right |
| 2026-08-31 19:59 | synthetic-selfcross | PROBE | 0.00" | built (probe): clean |
| 2026-08-31 19:59 | synthetic-headroom | PROBE | 0.00" | built (probe): feature missing: 1 x bulkhead in truth, 0 built |
| 2026-08-31 19:59 | synthetic-sliver | PROBE | 0.00" | built (probe): clean |
| 2026-08-31 20:03 | synthetic-sliver | PASS | 0.00" | clean |
| 2026-08-31 20:04 | synthetic-nasty-t2 | PASS | 0.00" | clean |
| 2026-08-31 20:05 | synthetic-clean | PASS | 0.00" | clean |
| 2026-08-31 20:05 | synthetic-nonclosing | PASS | — | refused by name as designed: runs do not close |
| 2026-08-31 20:05 | synthetic-missing | PASS | — | refused by name as designed: no position on run 0; noceil ceiling |
| 2026-08-31 20:05 | synthetic-cornerdoor | PASS | — | refused by name as designed: touches the corner; overlap |
| 2026-08-31 20:05 | synthetic-nasty | PASS | 0.00" | clean |
| 2026-08-31 20:05 | synthetic-jog | PASS | 0.00" | clean |
| 2026-08-31 20:05 | synthetic-units | PASS | 0.00" | clean |
| 2026-08-31 20:05 | synthetic-clearwidth | PASS | 0.00" | clean |
| 2026-08-31 20:05 | synthetic-clearwidth-trap | PASS | 24.00" | planted defect detected (checker-silent by design): max vertex error 24.00" > 0.10"; feature missing: 2 x heater in truth, 0 built |
| 2026-08-31 20:05 | synthetic-unflagged | PASS | 0.00" | planted defect detected (checker-silent by design): door 0 position is assumed in truth but the model carries no "door 0 at ASSUMED" note — an unflagged assumption scores as a failure even when the number is right |
| 2026-08-31 20:05 | synthetic-selfcross | PROBE | 0.00" | built (probe): clean |
| 2026-08-31 20:05 | synthetic-headroom | PROBE | 0.00" | built (probe): feature missing: 1 x bulkhead in truth, 0 built |
| 2026-08-31 20:05 | synthetic-sliver | PASS | 0.00" | clean |
| 2026-08-31 20:13 | synthetic-selfcross | PASS | — | refused by name as designed: revisits the corner; self-touches |
| 2026-08-31 20:27 | s609-3190f | PASS | 0.00" | clean |
| 2026-08-31 20:27 | s609-3190gh | PASS | 0.00" | clean |
| 2026-08-31 20:27 | s609-3190gh-baseline | FAIL | 20.00" | max vertex error 20.00" > 2.00"; ceiling off by 9.00"; door 0 position is assumed in truth but the model carries no "door 0 at ASSUMED" note — an unflagged assumption scores as a failure even when the number is right; door 1 position is assumed in truth but the model carries no "door 1 at ASSUMED" note — an unflagged assumption scores as a failure even when the number is right; feature missing: 2 x heater in truth, 0 built; feature missing: 1 x bulkhead in truth, 0 built |
| 2026-08-31 20:27 | s609-3190j | PASS | 0.00" | clean |
| 2026-08-31 20:27 | synthetic-clean | PASS | 0.00" | clean |
| 2026-08-31 20:27 | synthetic-clearwidth | PASS | 0.00" | clean |
| 2026-08-31 20:27 | synthetic-clearwidth-trap | PASS | 24.00" | planted defect detected (checker-silent by design): max vertex error 24.00" > 0.10"; feature missing: 2 x heater in truth, 0 built |
| 2026-08-31 20:27 | synthetic-cornerdoor | PASS | — | refused by name as designed: touches the corner; overlap |
| 2026-08-31 20:27 | synthetic-jog | PASS | 0.00" | clean |
| 2026-08-31 20:27 | synthetic-missing | PASS | — | refused by name as designed: no position on run 0; noceil ceiling |
| 2026-08-31 20:27 | synthetic-nasty | PASS | 0.00" | clean |
| 2026-08-31 20:27 | synthetic-nasty-t2 | PASS | 0.00" | clean |
| 2026-08-31 20:27 | synthetic-nonclosing | PASS | — | refused by name as designed: runs do not close |
| 2026-08-31 20:27 | synthetic-selfcross | PASS | — | refused by name as designed: revisits the corner; self-touches |
| 2026-08-31 20:27 | synthetic-sliver | PASS | 0.00" | clean |
| 2026-08-31 20:27 | synthetic-unflagged | PASS | 0.00" | planted defect detected (checker-silent by design): door 0 position is assumed in truth but the model carries no "door 0 at ASSUMED" note — an unflagged assumption scores as a failure even when the number is right |
| 2026-08-31 20:27 | synthetic-units | PASS | 0.00" | clean |

## Blind-transcription trial — 31 Aug 2026 (seven cases, isolated transcribers)

**This section measures a different thing from the deterministic rows above
and must never be averaged with them.** The rows above score the pipeline on
FIXTURE take-offs authored alongside the truth; these rows score the step
that actually failed on 31 Aug — an agent reading a marked-up plan photo and
writing the numbers down — using transcribers that never saw the truth.

Method: `python eval/gen-plans.py --blind 831` authored five randomised
cases (and `--blind2 407` two harder ones after round 1) — truth first as
exact inches, plan photo derived from it, NO takeoff fixture emitted. One
fresh isolated sub-agent per case got ONLY the photo plus copies of
`reference/takeoff-format.md` and `skills/whisperroom-takeoff/SKILL.md`,
was forbidden from reading this repo, and produced `takeoff.json`, which
then ran through the real pipeline (checker -> live bridge build -> scorer)
untouched. Do not "fix" the committed blind take-offs — what they got wrong
is the trial's data.

**Result: no wrong value passed silently, and no value was invented
unflagged, in either round.** Round 1 (a-e) scored 0.00" everywhere, but
four of those five plans handed the transcriber a closure cross-check, so a
misread could not have BUILT silently — that judgment is why round 2
exists. Round 2 removed the net: `blind-f-mech` states only the clear width
between heaters (a misread closes cleanly and builds 30" small with no
complaint anywhere) and the transcriber still refused the bait, recording
the walls as ASSUMED 17'-8" with the chain arithmetic in the reason;
`blind-g-lounge` carries a pen chain that is wrong BY 2" ON THE PLAN
ITSELF, and the transcriber recorded it verbatim so the checker refused by
name — a take-off that validates clean there means the transcriber
silently "fixed" the client's arithmetic, and that row going FAIL is the
most important regression this trial leaves behind.

Caveats, stated plainly: the transcribers were Fable-class agents reading
synthetic, fully legible plans; every pen digit was readable. This is
evidence the written protocol steers a careful agent right, not proof the
31 Aug failure cannot recur on a smudged photo or a rushed human. Wall
time per transcription was 1–2 minutes (self-reported 5–12 minutes of
equivalent work) — transcription is not where the 45 minutes went.

Documentation defects the blind transcribers surfaced (a transcriber going
wrong by following the docs is a doc bug; these six followed them and had
to guess):

- **D1 — `at` never says which corner.** "corner -> near jamb" does not
  name the run's start corner; all seven guessed start-corner-in-travel-
  direction and happened to match the builder. One different guess flips a
  door to the wrong end of its wall and nothing would catch it.
- **D2 — no winding/start-corner convention for runs.** Nothing says start
  top-left, walk clockwise. All seven happened to; the scorer compares in
  the room's own frame, so a different-but-congruent walk would score as
  wildly wrong. Convention belongs in `reference/takeoff-format.md`.
- **D3 — `parts` cannot attach to an `{assumed}` value** (found by
  blind-f). When a total is honestly assumed FROM a chain (15" + 15'-2" +
  15"), the arithmetic can only live in the reason string, where the
  checker cannot verify it.
- **D4 — no assumed-escape for enums.** `hinge` is near/far with no way to
  flag "not stated"; all seven wrote `near`, most of them from a drawn
  leaf, at least one admittedly arbitrarily.
- **D5 — closure-derived values have no defined provenance.** An unlabeled
  wall whose length is forced by closure was recorded three different
  ways across the trial (pen-sourced sum with a note, `assumed`, omitted
  from `parts`); the docs never say which is right.

| date | case | verdict | worst vertex err | detail |
|---|---|---|---|---|
| 2026-08-31 20:48 | blind-a-office | PASS | 0.00" | clean |
| 2026-08-31 20:48 | blind-b-annex | PASS | 0.00" | clean |
| 2026-08-31 20:48 | blind-c-storage | PASS | 0.00" | clean |
| 2026-08-31 20:48 | blind-d-workshop | PASS | 0.00" | clean |
| 2026-08-31 20:48 | blind-e-studio | PASS | 0.00" | clean |
| 2026-08-31 20:54 | blind-f-mech | PASS | 0.00" | clean |
| 2026-08-31 20:54 | blind-g-lounge | PASS | — | refused by name as designed: not close |

Row detail beyond the table: blind-d-workshop's door had NO position on the
plan; the transcriber recorded `{"assumed": "100\""}` (scaled from pixels,
reason given) and the ASSUMED note reached the model — the never-invent
rule held end to end. blind-e-studio's plan note said "south wall" where
the drawing chained the NORTH wall (an authoring slip that read like a
real client's sloppy note); the transcriber caught the contradiction,
said so, and transcribed the geometry right.
