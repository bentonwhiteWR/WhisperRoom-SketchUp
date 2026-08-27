# FIXER HANDOFF — 2026-08-26 (v7, supersedes v6)

v6 shipped two Standard-deck fixes (1.6.31). **Benton has now built `MDL 84126 E` and confirmed
it good — the first in-SketchUp confirmation this mission has ever had.** That closes v6's open
item 0 *and* the tray-orientation test owed since v5. **v7 fixes the IEP vent yaw (1.6.32).**
Every other open item is carried forward below.

## Produced

- **`scripts/build-booth-components.rb` — CHANGED, one defect, three edits.**
  - `IEP_VENT_YAW = 180.0` **deleted**. The long comment above it is kept and corrected: its
    "restart before you believe a report" lesson is true, but it was used to *dismiss* a real
    report, and the note now says so.
  - New `self.iep_vent_yaw(cls)`, sitting immediately under `EVEN` so the parity it reads is
    next to the parity `rotation()` writes. Returns 180 only when the part's measured axis
    permutation is odd.
  - The inner-vent block in `build_booth` calls it and **prints the measured width axis and the
    chosen turn for every inner vent**, so the console is now evidence.
- **`scripts/wr_tools/VERSION` 1.6.31 → 1.6.32.** `DEVLOG.md` entry added.
- **`.forge/fixer/ROOTCAUSE-iep-vent-yaw-2026-08-26.md` — new.** Symptom, mechanism at
  `build-booth-components.rb:1400`, the eight measured vent axes, the five in-SketchUp reports
  and why the rule fits all five, the blast radius, and what must **not** be generalised.
- **`.forge/fixer/verify-vent-yaw.py` — new harness.** Independent witnesses named in its header:
  the measured `_component-probe.tsv` and the generated `scripts/wr-booth-data.rb`. Neither is
  derived from the placement code. It re-implements `classify()`'s axis pick and the parity from
  the measurements, prints the turn for all 25 layouts × {non-HX, HX}, and asserts the five
  reports. **All five fit; exit 0.**
- `.forge/GOAL.md` — **Now** replaced (records the 84126 E confirmation); **Settled** gained the
  measured vent-yaw fact and its do-not-generalise warning; two History lines.
- Unchanged from v6 and still the things to read on their own subjects:
  `.forge/fixer/ROOTCAUSE-std-deck-84126-2026-08-26.md`,
  `.forge/fixer/TRAY-ORIENTATION-2026-08-26.md`, `.forge/fixer/verify-tray.py`,
  `.forge/fixer/WIDTH-AXIS-FAMILY-2026-08-26.md`,
  `.forge/fixer/ROOTCAUSE-side-wall-order-2026-08-26.md`,
  `.forge/fixer/verify-deck-pitch.py`, `.forge/fixer/verify-ceiling-cue.py`,
  `.forge/fixer/verify-84126.py`.

**`P:` read-only, nothing written to it. `WhisperRoomQuote` untouched. `scripts/wr-deck.rb`
untouched. No Standard placement changed.**

## Read first

1. `.forge/fixer/ROOTCAUSE-iep-vent-yaw-2026-08-26.md` — and specifically its last two sections.
   The vent fix is done; the **general** defect behind it is not, and the door family proves you
   cannot fix it by generalising the vent rule.
2. `.forge/fixer/WIDTH-AXIS-FAMILY-2026-08-26.md` — unchanged, still changes the plan for
   placement. 1.6.32 is the first fix to act on it.
3. `.forge/fixer/ROOTCAUSE-std-deck-84126-2026-08-26.md` — now **confirmed in a built model**.
4. `.forge/fixer/ROOTCAUSE-side-wall-order-2026-08-26.md` — the retractions. Do not reuse any
   pre-retraction conclusion about panel order.

## The answer in five lines

`rotation()` derives the along-wall width direction from the **parity of the part's own axis
permutation**, so parts of opposite parity land end for end from each other on the same wall.
`ENH 35.5VNT` is the only one of the eight `ENH` vent parts whose width runs X; the blanket
`IEP_VENT_YAW = 180` was fitted to it and applied to the other seven. It is now derived per part.
Benton saw it on the HX; **ten non-HX 41.5-vent layouts were wrong too, and nobody had looked.**

## Assumptions

- **The parity rule is a per-FAMILY convention, not a law.** derived for the mechanism, but which
  of the two rigid orientations is *correct* is an authoring property. It fits five reports across
  vents, and agrees with the mid-wall seal — and it would be **wrong** for the inner door family,
  which is uniformly Y-running and uniformly wants 180. This is the weakest link in 1.6.32.
- **Only two of the eight `ENH` vent parts have been seen in a built model** (`ENH 35.5VNT`,
  `ENH 35.5VNT_HX`). The 41.5s rest on the 96144 E and 4872 E reports. **reported.**
- **The `MDL 4872 E` data point is the weakest of the five.** The booth was signed off as a whole
  on 08-25 when the constant did not exist; there is no note that the vent's end-for-end
  orientation was specifically examined. **reported.** Drop it and the rule still stands on the
  96144 E and today's HX, which are independent of each other.
- **A part authored end for end in its own frame defeats this rule**, exactly as four of 23 `ENH`
  ceiling parts are authored upside down. No way to detect it from a bounding box. **assumed** it
  does not occur among the eight vent parts.
- `_component-probe.tsv` is a faithful stand-in for what `classify()` measures at build time.
  **derived** — both read `defn.bounds`; they are two functions and neither ran here.
- (from v6) The direction of convention A's mirror is **reported**, not measured — but it has now
  survived a built `MDL 84126 E`, which is real evidence it did not have before.
- (from v6) `_face-levels.tsv` is a faithful stand-in for what `wr-deck.rb` measures. **derived.**
- (from v5) Cut lists per layout are **derived** from a Python transcription of `WR_Deck.plan`.
  No Ruby interpreter exists here; `scripts/rbparse.py` reports files **parse**, not that they run.
- (from v4/v5) `runs` is meaningful as a wall-plane axis only for thin parts. **derived.**
- (from v4) `ENH LeftWADoor_HX` / `RightWADoor_HX` being +9.9908 in over their twins is deliberate
  door-leaf clearance rather than a defect. **assumed** — unconfirmed.
- (from v3/v4) The coordinate map `E/W builder y == H - bIn .. H - aIn` is **derived** from
  `layout-render.js:1003-1004` and `:1562-1565`.

## Open questions for Benton

0. **NEW — build `MDL 7272 E` or `MDL 96144 E`, Shell = Both, and look at the inner vent walls.**
   `git pull` → `install-plugin.py` → **RESTART**. Those are 41.5-vent layouts and they have been
   wrong since this morning. Then **rebuild the HX** and confirm its vents came back. The console
   now prints the width axis and turn per vent. See `.forge/GOAL.md` **Now**.

1. **NEW — the inner WINDOW panels are predicted wrong and were deliberately not changed.**
   Every `ENH ...WDO` inner panel runs **X** (measured) and gets **no** turn, so under the
   vent/seal convention it should be end for end. There is no in-SketchUp observation of one, and
   the door family proves conventions differ per family, so guessing would be the same mistake
   1.6.21 made. **The test: build a booth with an inner window** — `guess_component` has no WDO
   branch, so it needs an explicit assignment such as `'W1i' => 'ENH 41.5Panel3236WDO'`
   (`build-booth-components.rb:1200`), or a portal link that carries one — **and say which end the
   window sits at.** One look closes it.

2. **`STD7224FL SIDE R.skp` is defective, and only you can fix it.** It measures **37.9375 x 72**
   where its name says 24 across, `origin_anchor max/min/min`, 6 entities. Its ceiling twin
   `STD7224CL SIDE R` measures the correct 24.0000 x 72. **This makes `MDL 7272 S`'s floor ~14 in
   wrong at the high end, and it always has been.** Both deck harnesses refuse to guess a width
   for it rather than pick one silently. Component-authoring fix, on the share.

3. **`RightSideVent_CP_HX.skp` is defective and only you can fix it.** The HX rework was never
   applied: every measured property is identical to the non-HX `RightSideVent_CP`, including the
   origin offset and an entity count of 1 where the correct mirror `LeftSideVent_CP_HX` has 3.
   Expected after re-authoring: x = 46.0000, y = 8.5468, z = 96.6128, anchor `min/min/min`,
   3 entities. **Component-authoring fix, not a code change.**

4. **On a real 102144, which end of the side wall does the window sit at**, measured against the
   floor/ceiling **hinge slots**? And is it fixed by the model at all, **or does the assembler put
   the window wherever the customer asks?** Same question for the 96144. ⚠ **Partly answerable
   without you, and still not done.** `hinge_runs` (`wr-deck.rb:149`) measures exactly the datum
   this wants along the panel's long axis, and `probe-levels.rb`'s `brackets` already computes it
   — but **only the short-axis `bracket_edge` is written to `_face-levels.tsv`; the long-axis runs
   are printed to the console and thrown away.** Adding a `runs` column would close the measurable
   half. **Flagged, deliberately not done — out of scope for both 1.6.31 and 1.6.32.**
   Note this overlaps open item 1: same wall, same part family.

5. **Green-light the four-booth flip?** 6060 / 6084 / 7272 / 7296 only, 24 walls. ⚠ `MDL 6060 E`
   and `MDL 7272 E` are both in the GOAL "Now" now. Sequence it; do not land it underneath him.

6. **Green-light bounding-box width-axis resolution?** Written up but **not made**, and 1.6.32
   makes the case for it stronger: the vent fix is a per-family patch on a **general** defect —
   `rotation()` deriving the along-wall direction from authoring parity. It would touch the outer
   Standard shell as well as Enhanced, and the Standard fence has only ever been lifted for named
   defects. Still needs its own decision.

7. **The portal's angled view is stale on 14 models** (56 walls). Refreshing it requires fixing
   `gen-booth.py` FIRST. `WhisperRoomQuote` change, not mine to make.

8. **`RightWADoorWithRamp_HX` has no non-HX twin under that name** — its twin is in the set as
   `RightWADoorWithRamp#1`, SketchUp's duplicate-definition suffix. Any name-keyed lookup for
   `RightWADoorWithRamp` will miss it. Flagged, not investigated.

9. **`.forge/builder/replay-iep-deck.py` section 9 describes a file that no longer exists.** It
   still asserts `_face-levels.tsv` carries zero `ENH` rows. **Left alone deliberately — it is the
   Builder's harness, not the Fixer's.**

10. **Neither 1.6.31 fix reaches the ENHANCED inner deck, and that is a scope boundary, not a
    verdict.** `build-booth-components.rb` calls `WR_Deck.plan` (line 863) but runs its **own**
    placement loop and its **own** `bracket_edge` call (line 611); it never calls `WR_Deck.build`.
    So the inner deck still seats every tile low-edge-first off nominal stations, and still reads a
    ceiling's orientation without the convention-A mirror. **`ENH 8418 FL` measures 17.9375, 1/16
    under its nominal**, so an inner floor ending on that part has the same perimeter gap the
    Standard floor had. ⚠ **The 84126 E confirmation makes this decidable now** — the same
    evidence that held for the Standard deck carries over. Worth a decision.

11. ~~ENH parts have never been face-level probed.~~ **CLOSED (v5).**
    ~~Build the 84126 E for the tray test.~~ **CLOSED 2026-08-26 — built and confirmed good.**
