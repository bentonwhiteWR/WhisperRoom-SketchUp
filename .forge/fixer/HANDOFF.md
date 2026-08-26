# FIXER HANDOFF — 2026-08-26 (v4, supersedes v3)

v3 covered the side-wall panel ORDER. v4 adds the component-probe audit and closes v3's
open item 4. **The side-wall order items from v3 are unchanged and carried forward below.**

## Produced

- `.forge/fixer/PROBE-COMPONENT-FILES-2026-08-26.md` — **rewritten (v2).** Now sourced from
  `P:\Sketchup\NewMasterComponentList\_component-probe.tsv` read directly, not from a terminal
  paste. Header says so. Carries an explicit audit of what the v1 transcription got right
  (everything it listed) and the one claim it got wrong (the `_HX` axis convention).
- `.forge/fixer/WIDTH-AXIS-FAMILY-2026-08-26.md` — **new.** Closes v3 open item 4. Full
  characterisation of the width-axis split across all 370 parts, with three appendices
  enumerating every X-runner, every axis-flipping `_HX` pair, and every non-flipping pair.
- `.forge/fixer/analyze-component-probe.py` — **new harness.** Its only input is the TSV, and
  its header names that witness explicitly. Reads `P:` only; writes nothing there.
- `.forge/fixer/ROOTCAUSE-side-wall-order-2026-08-26.md` — unchanged from v3. Carries four
  retractions of earlier conclusions plus the three-source map. Still the thing to read on
  panel order.
- `.forge/fixer/replay-portal-wallrun.js` — unchanged from v3. Executes `wallPanelRun()` from
  `WhisperRoomQuote/assets/layout-render.js` directly. `--all` → `300 walls compared:
  24 DISAGREE`, exit 1.

**No `.rb` touched. `scripts/wr_tools/VERSION` untouched at 1.6.29. `P:` read-only, nothing
written to it. `WhisperRoomQuote` read only.**

## Read first

1. `.forge/fixer/WIDTH-AXIS-FAMILY-2026-08-26.md` — the new result, and it changes the plan.
2. `.forge/fixer/ROOTCAUSE-side-wall-order-2026-08-26.md` — the retractions. Do not reuse any
   pre-retraction conclusion about panel order.

## The two answers in six lines

**Width axis.** There is **no name-level rule.** The best rule I can construct misses 20 of
194 wall parts. `ENH 38.5Panel2636WDO` runs X and `ENH 38.5Panel2648WDO` runs Y — same family,
same module width, different axis — which kills family-based and width-based rules on its own.
**Placement must read the measured bounding box.** The mixed origin anchor already forced that;
the axis data removes the last reason to hope otherwise.

**Panel order.** Unchanged from v3: the portal's angled view is a 2026-08-07 snapshot of
`wr-booth-data.rb`, so Benton's 102144 comparison was SketchUp against a stale copy of itself.
The window's correct end **cannot be determined from anything on disk.**

## Assumptions

- The TSV dated 2026-08-26 17:26 is the run Benton just made. **observed** — file mtime and
  the 370-row count both match.
- `runs` is meaningful as a *wall-plane axis* only for thin parts. For floor/ceiling slabs both
  dimensions are large and `runs` reports something else entirely. **derived** from
  `scripts/probe-components.rb:80`; stated in the width-axis doc so it can be challenged.
- `ENH LeftWADoor_HX` / `ENH RightWADoor_HX` being +9.9908in rather than +10.0000in over their
  twins is deliberate door-leaf clearance rather than a defect. **assumed** — unconfirmed.
- (from v3, still live) The coordinate map `E/W builder y == H - bIn .. H - aIn` is **derived**
  from `layout-render.js:1003-1004` and `:1562-1565`. Every number in the panel-order report
  depends on it.
- (from v3) The assign fed to `wallPanelRun()` is built from `wr-booth-data.rb`'s own resolved
  panel widths, because the flip keys on real part widths and slot sizes would misfire.

## Open questions for Benton

1. **`RightSideVent_CP_HX.skp` is defective and only you can fix it.** The HX rework was never
   applied: every measured property is identical to the non-HX `RightSideVent_CP`, including
   the origin offset and an entity count of 1 where the correct mirror `LeftSideVent_CP_HX` has
   3. It is the only one of 99 `_HX` pairs with a +0.0000 Z delta, and the only `_HX` in the
   set dimensionally identical to its twin. Expected after re-authoring: x = 46.0000,
   y = 8.5468, z = 96.6128, anchor `min/min/min`, 3 entities. **Component-authoring fix, on the
   share, not a code change.** `P:` is read-only to me.

2. **On a real 102144, which end of the side wall does the window sit at**, measured against
   the floor/ceiling **hinge slots** (a datum that does not move when the door moves)? And is
   it fixed by the model at all, **or does the assembler put the window wherever the customer
   asks?** If the latter, there is no rule to code and the real defect is that
   `booth-from-link.rb` inherits a hard-coded polygon instead of honouring a chosen position.
   Same question for the 96144 (46+46, also symmetric). **Still the one that matters most.**

3. **Green-light the four-booth flip?** 6060 / 6084 / 7272 / 7296 only, 24 walls. Evidenced by
   the hinge slots, both portal views, and Benton's own "the 6060 top-down looks correct."
   ⚠ **`MDL 6060 E` is the current GOAL "Now"** — this moves its E/W panels and seals on both
   shells. Sequence it against his 6060 work; do not land it underneath him.

4. **Green-light bounding-box width-axis resolution?** This is the code change the width-axis
   document argues for, written up but **not made**. It would touch the outer Standard shell as
   well as Enhanced, and `.forge/GOAL.md` puts "changing how Standard booths resolve or place"
   out of scope. Needs an explicit decision from you before anyone writes it.

5. **The portal's angled view is stale on 14 models** (56 walls). Refreshing it requires fixing
   `gen-booth.py` FIRST — a naive re-extract would break the four split-run booths' angled
   view. `WhisperRoomQuote` change, not mine to make.

6. **`ENH` parts have never been face-level probed.** `_face-levels.tsv` on the share is dated
   **2026-08-14** and is Standard-only. The IEP tray orientation still abstains for want of it.
   Needs `scripts/probe-levels.rb` run over the folder with an **empty** filter — a different
   tool from the component probe. Do not use the stale file for width-axis questions.

7. **`RightWADoorWithRamp_HX` has no non-HX twin under that name** — its twin is in the set as
   `RightWADoorWithRamp#1`, SketchUp's duplicate-definition suffix. Any name-keyed lookup for
   `RightWADoorWithRamp` will miss it. Flagged, not investigated.
