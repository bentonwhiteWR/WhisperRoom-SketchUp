# FIXER HANDOFF — 2026-08-26 (v6, supersedes v5)

v5 shipped the IEP tray orientation (1.6.30). **v6 fixes two STANDARD deck defects Benton
reported off a built `MDL 84126 E`, and closes v5's open item 0.** Every other v5 open item is
unchanged and carried forward verbatim below.

## Produced

- **`scripts/wr-deck.rb` — CHANGED, in two independent places.**
  1. `plan` now carries `:run` and `:at_high_end`; `build` seats the **last tile of a multi-tile
     run against the far perimeter** (`far - got.max`) instead of its nominal station. 17 floor
     decks move by their own measured undersize; no ceiling and no single-tile deck moves.
  2. `build` now takes a ceiling's **own** `bracket_edge` when it has one and the **mirror**
     (`1.0 - e`) of its floor twin's when it does not. 18 ceiling end-tiles move across the
     60/72/84/102 series; **zero floor tiles** and **zero 96-series ceiling tiles** move.

  **`scripts/wr_tools/VERSION` 1.6.30 → 1.6.31.** `DEVLOG.md` entry added.
- **`.forge/fixer/ROOTCAUSE-std-deck-84126-2026-08-26.md` — new.** Both defects: symptom, root
  cause, the two Standard ceiling authoring conventions, blast radius, and the falsifiers.
- **Three harnesses, each naming its independent witness in its header, none compared against a
  copy of itself:** `.forge/fixer/verify-deck-pitch.py` (the pitch/seating arithmetic),
  `.forge/fixer/verify-ceiling-cue.py` (the convention split), `.forge/fixer/verify-84126.py`
  (before/after per booth, plus the two control runs).
- `.forge/GOAL.md` — **Now** replaced; **Settled** gained the two new measured facts; the
  out-of-scope fence narrowed to record Benton lifting it for these two defects only.
- Unchanged from v5 and still the things to read on their own subjects:
  `.forge/fixer/TRAY-ORIENTATION-2026-08-26.md`, `.forge/fixer/verify-tray.py`,
  `.forge/fixer/WIDTH-AXIS-FAMILY-2026-08-26.md`,
  `.forge/fixer/ROOTCAUSE-side-wall-order-2026-08-26.md`.

**`P:` read-only, nothing written to it. `WhisperRoomQuote` untouched.**

## Read first

1. `.forge/fixer/ROOTCAUSE-std-deck-84126-2026-08-26.md` — both fixes and, more importantly, the
   evidence that **no Standard ceiling's plan rotation has ever been confirmed by anyone.**
2. `.forge/fixer/WIDTH-AXIS-FAMILY-2026-08-26.md` — unchanged, still changes the plan for placement.
3. `.forge/fixer/ROOTCAUSE-side-wall-order-2026-08-26.md` — the retractions. Do not reuse any
   pre-retraction conclusion about panel order.

## The answer in five lines

The 1/32 is **nominal stations against measured seating**: `catalogue` reads widths off the name
digits, `build` seats off geometry, everything is laid low-edge-first, so the undersize surfaces
**once**, on the last tile, against the wall — which is why only one SIDE moves.
The hinges are an **unmeasured invariant**: "floor and ceiling hinges are coplanar in plan" rests
on two words from August, and it is false for the **17** Standard ceiling parts authored
pre-inverted about their long axis. **1.6.30 touches neither defect** — verified, not assumed.

## Assumptions

- **The direction of convention A's mirror is REPORTED, not measured, and it is the weakest link
  in 1.6.31.** One observed booth generalised across a measured class of 17 parts. No probe can
  currently see a convention-A ceiling's hardware — `bracket_edge` only looks above the rim and
  those parts have nothing there.
- `_face-levels.tsv` and `_component-probe.tsv` are faithful stand-ins for what `wr-deck.rb`
  measures at build time. **derived** — `probe-levels.rb`'s `bracket_edge`/`rim` and `wr-deck.rb`'s
  are line-for-line the same computation, but they are two functions and neither can be run here.
  Note `wr-deck.rb` additionally applies a `SYMMETRIC = 0.08` gate the probe does not; the
  harnesses apply it explicitly.
- **The 1/32 figure itself is doubly sourced** and does not rest on the above: derived from the
  code at 0.0312, and independently reported by Benton at 1/32. The *fix* does not depend on it
  at all — seating from `got.max` is right whatever `deck_extent` measures.
- `deck_extent` (the contact-face extent) is assumed to span the part's full width along the
  tiling axis. **assumed** — used only in the harness's *prediction* of the gap size, never in
  the fix.
- (from v5, still live) The cut lists per layout are **derived** from a Python transcription of
  `WR_Deck.plan`, not from Ruby execution. No Ruby interpreter exists in this environment;
  `scripts/rbparse.py` reports `wr-deck.rb` parses, which is not the same as running.
- (from v4/v5) `runs` is meaningful as a wall-plane axis only for thin parts. **derived**.
- (from v4) `ENH LeftWADoor_HX` / `RightWADoor_HX` being +9.9908in over their twins is deliberate
  door-leaf clearance rather than a defect. **assumed** — unconfirmed.
- (from v3/v4) The coordinate map `E/W builder y == H - bIn .. H - aIn` is **derived** from
  `layout-render.js:1003-1004` and `:1562-1565`.

## Open questions for Benton

0. **NEW — build `MDL 84126 E` (Shell = Both), then `MDL 7272 S`.** Needs `git pull` →
   `install-plugin.py` → **RESTART**. The 84126 answers both of his reports; the **7272 S is the
   real falsifier** for the ceiling mirror, because its ceiling moves and its floor was signed off
   in August and does not. See `.forge/GOAL.md` **Now** for exactly what to look at.

1. **NEW — `STD7224FL SIDE R.skp` is defective, and only you can fix it.** It measures
   **37.9375 x 72** where its name says 24 across, `origin_anchor max/min/min`, 6 entities. Its
   ceiling twin `STD7224CL SIDE R` measures the correct 24.0000 x 72. **This makes `MDL 7272 S`'s
   floor ~14 in wrong at the high end, and it always has been.** Both harnesses refuse to guess a
   width for it rather than pick one silently. Component-authoring fix, on the share.

2. **`RightSideVent_CP_HX.skp` is defective and only you can fix it.** The HX rework was never
   applied: every measured property is identical to the non-HX `RightSideVent_CP`, including the
   origin offset and an entity count of 1 where the correct mirror `LeftSideVent_CP_HX` has 3.
   Expected after re-authoring: x = 46.0000, y = 8.5468, z = 96.6128, anchor `min/min/min`,
   3 entities. **Component-authoring fix, not a code change.**

3. **On a real 102144, which end of the side wall does the window sit at**, measured against the
   floor/ceiling **hinge slots**? And is it fixed by the model at all, **or does the assembler put
   the window wherever the customer asks?** Same question for the 96144. **Still the one that
   matters most.** ⚠ **NEWLY ANSWERABLE WITHOUT YOU, PARTLY.** It wanted a datum "that does not
   move when the door moves"; `hinge_runs` (`wr-deck.rb:149`) measures exactly that along the
   panel's long axis, and `probe-levels.rb`'s `brackets` already computes it — but **only the
   short-axis `bracket_edge` is written to the TSV; the long-axis runs are printed to the console
   and thrown away.** Adding a `runs` column to `_face-levels.tsv` would close the measurable half.
   **Flagged, deliberately not done — out of scope for this fix.**

4. **Green-light the four-booth flip?** 6060 / 6084 / 7272 / 7296 only, 24 walls. ⚠ `MDL 6060 E`
   is still in the GOAL "Now", and 1.6.31 now also moves the 6060's and 7272's Standard ceilings.
   Sequence it; do not land it underneath him.

5. **Green-light bounding-box width-axis resolution?** Written up but **not made**. It would touch
   the outer Standard shell as well as Enhanced. ⚠ Benton has now lifted the Standard fence for
   **two named defects only**, which is not a green light for this one. Still needs its own
   decision.

6. **The portal's angled view is stale on 14 models** (56 walls). Refreshing it requires fixing
   `gen-booth.py` FIRST. `WhisperRoomQuote` change, not mine to make.

7. **`RightWADoorWithRamp_HX` has no non-HX twin under that name** — its twin is in the set as
   `RightWADoorWithRamp#1`, SketchUp's duplicate-definition suffix. Any name-keyed lookup for
   `RightWADoorWithRamp` will miss it. Flagged, not investigated.

8. **`.forge/builder/replay-iep-deck.py` section 9 describes a file that no longer exists.** It
   still asserts `_face-levels.tsv` carries zero `ENH` rows. **Left alone deliberately — it is the
   Builder's harness, not the Fixer's.**

9. ~~ENH parts have never been face-level probed.~~ **CLOSED 2026-08-26 (v5).**
   ~~Build the 84126 E for the tray test.~~ **Still owed — folded into item 0.**

10. **NEW — neither 1.6.31 fix reaches the ENHANCED inner deck, and that is a scope boundary, not
    a verdict.** `build-booth-components.rb` calls `WR_Deck.plan` (line 863) but runs its **own**
    placement loop and its **own** `bracket_edge` call (line 611); it never calls `WR_Deck.build`.
    So the inner deck still seats every tile low-edge-first off nominal stations, and still reads a
    ceiling's orientation without the convention-A mirror. **`ENH 8418 FL` measures 17.9375, 1/16
    under its nominal**, so an inner floor ending on that part has the same perimeter gap the
    Standard floor had. Benton reported the Standard deck and the GOAL fence was lifted for the
    Standard deck, so this was deliberately left. **Worth deciding after the 84126 build**, since
    the same evidence would carry over.
