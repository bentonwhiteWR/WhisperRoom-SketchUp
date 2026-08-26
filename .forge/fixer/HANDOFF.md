# FIXER HANDOFF — 2026-08-26 (v5, supersedes v4)

v4 covered the component-probe audit and the width-axis split. **v5 closes v4's open item 6**
— the ENH face-level probe — and ships the first `.rb` change of this Fixer sequence.
**Every other v4 open item is unchanged and carried forward verbatim below.**

## Produced

- **`scripts/build-booth-components.rb` — CHANGED.** `iep_upside_down?` rewritten: the tray
  orientation is now decided from measured face levels instead of abstaining. Constants
  `IEP_LEVEL_MIN_SHARE` / `IEP_MOUTH_RATIO` removed; `IEP_PLATE_MIN_SHARE` (0.50),
  `IEP_RIM_MAX_SHARE` (0.25), `IEP_RIM_MIN_AREA` (10.0) added. `contact_z` demoted from first
  word to fallback. **`scripts/wr_tools/VERSION` 1.6.29 → 1.6.30.** `DEVLOG.md` entry added.
- **`.forge/fixer/TRAY-ORIENTATION-2026-08-26.md` — new.** The root-cause document: symptom,
  cause, the four upside-down parts, the nine affected layouts, the `contact_z` reversal, and
  the `SEAL_FL_DATUM_LIFT` answer (which is: no, and it did not need one).
- **`.forge/fixer/verify-tray.py` — new harness.** Sole input
  `P:\Sketchup\NewMasterComponentList\_face-levels.tsv`; its header names that witness. Re-runs
  `contact_z`, the old rule and the new rule over all 370 parts. **Not checked against any copy
  of itself.**
- `.forge/GOAL.md` — **Now** section replaced. Still one screen, one Mission, one Done-means,
  one Now, one Out-of-scope.
- Unchanged from v4 and still the things to read on their own subjects:
  `.forge/fixer/WIDTH-AXIS-FAMILY-2026-08-26.md`,
  `.forge/fixer/PROBE-COMPONENT-FILES-2026-08-26.md`,
  `.forge/fixer/ROOTCAUSE-side-wall-order-2026-08-26.md`,
  `.forge/fixer/analyze-component-probe.py`, `.forge/fixer/replay-portal-wallrun.js`.

**`wr-deck.rb` NOT touched — the Standard path sees nothing different. `P:` read-only, nothing
written to it. `WhisperRoomQuote` read only.**

## Read first

1. `.forge/fixer/TRAY-ORIENTATION-2026-08-26.md` — the new result and the code change it
   justifies, including the one place I reversed an existing deliberate decision.
2. `.forge/fixer/WIDTH-AXIS-FAMILY-2026-08-26.md` — unchanged, and it still changes the plan for
   placement.
3. `.forge/fixer/ROOTCAUSE-side-wall-order-2026-08-26.md` — the retractions. Do not reuse any
   pre-retraction conclusion about panel order.

## The answer in five lines

The abstention was **a threshold, not a missing measurement — and then it was both.**
`IEP_LEVEL_MIN_SHARE = 0.05` deleted the tray rim (1.9%–6.6% of the plate) before the mouth
ratio could see it, so the rule compared the plate against its own underside and abstained on 11
of 23 ENH ceilings. With the rim restored, **four parts are authored upside down** and nine `E`
layouts tile one. **`MDL 6060 E` and `MDL 4872 E` do not move.**

## Assumptions

- **The TSV is a faithful stand-in for `WR_Deck.flat_levels` at build time. This is the weakest
  link in the whole change.** **derived** — `probe-levels.rb`'s `levels` and `wr-deck.rb`'s
  `flat_levels_with_exact` use the same 0.999 flat test, the same 1/64 bin and the same
  recursive face walk, but they are two functions and neither can be executed here.
- The cut lists per layout are **derived** from a Python transcription of `WR_Deck.plan`
  (`.forge/builder/replay-iep-deck.py`), not from Ruby execution.
- "Plate up = correct" is **reported**, from Benton via DEVLOG: *"the tray faces downwards, and
  it sits on top of the standard ceiling, completely engulfing it."*
- The TSV dated 2026-08-26 19:38 is Benton's full-folder run. **observed** — mtime, 380,767
  bytes, 6,625 lines, 1,761 ENH rows.
- (from v4, still live) `runs` is meaningful as a wall-plane axis only for thin parts; for
  floor/ceiling slabs it reports something else. **derived**.
- (from v4) `ENH LeftWADoor_HX` / `RightWADoor_HX` being +9.9908in rather than +10.0000in over
  their twins is deliberate door-leaf clearance rather than a defect. **assumed** — unconfirmed.
- (from v3/v4) The coordinate map `E/W builder y == H - bIn .. H - aIn` is **derived** from
  `layout-render.js:1003-1004` and `:1562-1565`. Every number in the panel-order report depends
  on it.
- (from v3/v4) The assign fed to `wallPanelRun()` is built from `wr-booth-data.rb`'s own
  resolved panel widths.

## Open questions for Benton

0. **NEW — build `MDL 84126 E`, Shell = Both, and look at the inner ceiling from below.** It is
   the one booth where the two end trays flip and the middle one does not, so the before/after
   is unmistakable. **Needs `git pull` → `install-plugin.py` → RESTART** — new constants, and a
   module keeps its constants until SketchUp restarts. Then `MDL 102144 E`.

1. **`RightSideVent_CP_HX.skp` is defective and only you can fix it.** The HX rework was never
   applied: every measured property is identical to the non-HX `RightSideVent_CP`, including the
   origin offset and an entity count of 1 where the correct mirror `LeftSideVent_CP_HX` has 3.
   Expected after re-authoring: x = 46.0000, y = 8.5468, z = 96.6128, anchor `min/min/min`,
   3 entities. **Component-authoring fix, on the share, not a code change.**

2. **On a real 102144, which end of the side wall does the window sit at**, measured against the
   floor/ceiling **hinge slots** (a datum that does not move when the door moves)? And is it
   fixed by the model at all, **or does the assembler put the window wherever the customer
   asks?** Same question for the 96144. **Still the one that matters most.**

3. **Green-light the four-booth flip?** 6060 / 6084 / 7272 / 7296 only, 24 walls. ⚠ `MDL 6060 E`
   is still in the GOAL "Now" — this moves its E/W panels and seals on both shells. Sequence it
   against that work; do not land it underneath him.

4. **Green-light bounding-box width-axis resolution?** Written up but **not made**. It would
   touch the outer Standard shell as well as Enhanced, and `.forge/GOAL.md` puts "changing how
   Standard booths resolve or place" out of scope. Needs an explicit decision.

5. **The portal's angled view is stale on 14 models** (56 walls). Refreshing it requires fixing
   `gen-booth.py` FIRST. `WhisperRoomQuote` change, not mine to make.

6. ~~ENH parts have never been face-level probed.~~ **CLOSED 2026-08-26 by this session.**

7. **`RightWADoorWithRamp_HX` has no non-HX twin under that name** — its twin is in the set as
   `RightWADoorWithRamp#1`, SketchUp's duplicate-definition suffix. Any name-keyed lookup for
   `RightWADoorWithRamp` will miss it. Flagged, not investigated.

8. **NEW, minor — `.forge/builder/replay-iep-deck.py` section 9 is now describing a file that no
   longer exists.** It still asserts that `_face-levels.tsv` carries zero `ENH` rows and that the
   mouth tell misfires on 17 of 22 Standard floors. It was run this session and passed, but that
   section should be re-pointed at the fresh TSV and at the new rule. **Left alone deliberately —
   it is the Builder's harness, not the Fixer's.** `.forge/fixer/verify-tray.py` covers the same
   ground against the fresh witness in the meantime.
