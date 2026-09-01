# Builder HANDOFF — D1–D5 doc defects, the winding convention, the sill collision (2026-08-31)

Goal reconfirmed against `.forge/GOAL.md` before writing this: Done-means 5
(the written protocol updated to match what the loop actually proved) plus the
no-silent-fallback and never-invent-a-placement-number rules. Prior handoff
preserved at `.forge/builder/HANDOFF-blind-trial.md` if it is wanted; this one
supersedes it. Plugin `scripts/wr_tools/VERSION` 1.12.8 → **1.12.9**.

## The one thing to read first

**D2 was a live silent-wrong-geometry landmine, and it is closed.** The
take-off format never said which way runs walk or which corner they start at.
`build-takeoff.rb` derives its mitre sense from the signed area and builds
either winding without complaint, so a counter-clockwise run list closes,
validates and produces a clean, plausible room — and a counter-clockwise list
is exactly what a **mirrored** read of the plan produces, since swapping east
for west reverses the walk.

Proven, not argued: `eval/floorplans/blind-a-office/takeoff.json` with east
and west swapped, and the same room walked the other way round, **both
validated clean against the committed checker** — exit 0, closure 0.00", no
self-intersection, lock written, ready to build. Both now refuse by name.
The two files are at
`C:\Users\bento\AppData\Local\Temp\claude\C--Users-bento-OneDrive-Documents-Claude-Sketchup\87da3f21-6f6b-4dcc-8750-75cbeb1a22ca\scratchpad\mirror-A.json`
and `...\mirror-B.json` (scratch, not committed).

This was found by the blind transcription trial, not by review. Worth
remembering when deciding whether the next trial is worth its cost.

## Produced

| file | what |
|---|---|
| `scripts/takeoff-check.py` | The five D1–D5 fixes plus the sill collision. `check_winding` + `signed_area` (D2), `RUN_START_END` and the printed door anchor (D1), `check_parts` hoisted so it works on `{"assumed"}` values (D3), `norm_enum` (D4), `derived` in `SRC_KINDS` and the one-unknown-per-axis check (D5), room-level `sill` refused and window `sill` required. `--selftest` is 48 cases, 17 new. |
| `scripts/eval-floorplan.py` | `SCRATCH_GUARD` — refuses inside the Ruby job, before any geometry, unless the active model is Untitled, naming the refused model's title and path. `_BUILT` / `cleanup_built()` — erases the groups this run created, by entityID captured at build time, in `main()`'s `finally`, and reads back to confirm. |
| `reference/takeoff-format.md` | Normative: the third generating rule (winding), the winding/start-corner/`at` section, `derived`, enums, `parts` on assumed values, the sill ruling. |
| `skills/whisperroom-takeoff/SKILL.md` | The same in short form for Gabe, kept in step so the three cannot drift. |
| `clients/uic-daley-library/takeoff.json` | One declaration on room 3190J. **No geometry changed** — `s609-3190j` still scores against the same truth polygon. |
| `eval/RESULTS.md` | D1–D5 each carry what changed and whether it is ENFORCED or DOCUMENTED; a note under the blind table saying no row has been re-scored. |
| `DEVLOG.md`, `scripts/wr_tools/VERSION` | 1.12.9. |

## Read-first

1. `eval/RESULTS.md` — the D1–D5 entries, now with their resolutions.
2. `reference/takeoff-format.md` — the "Winding, the start corner, and what
   `at` is measured from" section. It is one rule, not three.

## What is verified, and what is not

**Verified (observed):**
- `python scripts/takeoff-check.py --selftest` → 48/48, exit 0.
- All 26 eval cases plus `clients/uic-daley-library/takeoff.json` run through
  the checker with **exactly their prior exit codes**: the five refusal cases
  (`blind-g-lounge`, `synthetic-cornerdoor`, `synthetic-missing`,
  `synthetic-nonclosing`, `synthetic-selfcross`) still refuse with their
  expected phrases; every other case still validates. The format change is
  backward compatible at the checker.
- The D2 mirror proof above.
- The sill proof: `synthetic-nasty`'s take-off with the window's `sill`
  deleted validated clean against the committed checker and produced a lock
  with no `sill_in` on the window and an unflagged `sill_in: 48.0` on the
  room; it now fails by name.
- The scratch guard, both directions, by read-only bridge job: it raises on a
  stubbed saved model naming title and path, and passes on a live Untitled
  model.

**NOT verified — the gap, stated plainly:** **no eval case has been built and
scored in SketchUp since this change.** Benton had his own files open, so the
live build-and-score step was deliberately not run rather than run against
the wrong model. Nothing in the ledger has been re-scored. The checker-level
evidence is real; the bridge-level evidence is absent.

**Also not done:** recorded non-numeric guesses (an assumed hinge, a declared
winding) reach the console report and the review sheet but **not the model as
a note**. They are in the lock as `flag_inventory`, deliberately separate from
`assumed_inventory` because `build-takeoff.rb` formats every entry of the
latter as a length and `near` is not a length. Placing them needs a
`build-takeoff.rb` change — another lane's file — and is the one loose end
worth routing.

## Closing the gap — the exact commands

Run these when the active SketchUp model is **Untitled** and nobody else is
building into it. The guard will refuse by name if it is not, so it is safe to
attempt; the risk that remains is a name collision with another agent's
concurrent suite, which no guard can see.

```
cd C:\Users\bento\OneDrive\Documents\Claude\Sketchup\WhisperRoom-SketchUp
python scripts/sketchup-bridge.py eval "m=Sketchup.active_model; {'path'=>m.path.to_s, 'title'=>m.title.to_s, 'groups'=>m.entities.grep(Sketchup::Group).map{|g| g.name.to_s}}" --json
```

Read `path` from **that same query** as the group list — a group list without
the path it came from cannot be compared to another one. (I compared two
readings taken from different models earlier today and drew a wrong conclusion
from it; capturing both together is what prevents that.) Proceed only if
`path` is `""`.

Then, one case at a time so a collision is visible early:

```
python scripts/eval-floorplan.py synthetic-clean --record
```

and if that row matches its current value, the rest:

```
for c in blind-a-office blind-b-annex blind-c-storage blind-d-workshop blind-e-studio blind-f-mech blind-g-lounge s609-3190f s609-3190gh s609-3190gh-baseline s609-3190j synthetic-clean synthetic-clearwidth synthetic-clearwidth-trap synthetic-cornerdoor synthetic-headroom synthetic-jog synthetic-missing synthetic-nasty synthetic-nasty-t2 synthetic-nonclosing synthetic-selfcross synthetic-sliver synthetic-unflagged synthetic-units; do python scripts/eval-floorplan.py $c --record; done
```

Every verdict must match its current value in `eval/RESULTS.md`. **If one
moves, that is a finding — report it, do not edit the case to agree with it.**
The `synthetic-*` and `blind-*` take-offs are deliberately what they are.
`s609-3190gh-baseline` is expected to FAIL at 20.00"; `synthetic-selfcross`,
`synthetic-headroom` and `synthetic-sliver` have PROBE history.

## Assumptions

- **observed:** no committed take-off uses a room-level `sill`, and both
  windows in the eval set state their own — so both sill changes break
  nothing. Surveyed all 27 files.
- **observed:** all 29 doors across the 27 committed take-offs state `hinge`
  explicitly, so making it mandatory breaks nothing.
- **observed:** `clients/uic-daley-library/takeoff.json` room 3190J was the
  only counter-clockwise room in the entire corpus, and the only file needing
  migration. Its migration is one declaration and no geometry.
- **derived:** enforcing clockwise winding catches an accidental east/west
  swap, because a mirror reverses orientation, so a clockwise walk of the
  original is a counter-clockwise walk of the mirror. The two mirror files
  above are the demonstration.
- **assumed:** that the concurrent Builder's `build-takeoff.rb` still reads
  `at` as an offset from `pts[i]` toward `pts[i+1]` and `hinge` as a plain
  string. I read both at 1.12.8 and neither is in my lane; if that Builder
  changes the door placement math, D1's ruling needs re-checking against it.
- **reported, not verified:** the coordinator states the 12 eval room groups
  sitting in `Z:\Sketchup\BoothBuilderClaude\RoofMountedVentilation.skp` are
  static debris from an earlier suite run, and that Benton is clearing them
  himself. I touched no model.

## Open questions

1. Route to the `build-takeoff.rb` lane: place an in-model note for
   `flag_inventory` entries (assumed hinge, declared winding), the way
   `assumed_inventory` entries already get one. Until then a guessed hinge is
   flagged everywhere except the model.
2. D5's unenforceable half: nothing can tell that a value labelled `pen` was
   in fact forced by closure. The ruling makes the honest path easy; it cannot
   make the dishonest one impossible.
3. The blind trial's transcribers wrote `at` from the run's start corner
   without being told to, which is why D1 never bit. Worth one more blind
   round against the *new* docs to see whether the written conventions
   actually steer, rather than assuming the docs caused what luck did.
