# HANDOFF — part orientation, 2026-08-28 (plugin 1.7.10)

Fixer pass on Benton's five-item defect list off freshly built booths. **Nothing here has been
run in SketchUp.** There is no SketchUp and no `ruby.exe` on this machine; every claim below is
either observed off a file, derived from observations, or reported by Benton, and it is labelled.

---

## Produced

| file | change |
|---|---|
| `C:\Users\bento\Documents\Claude\Sketchup\scripts\wr-deck.rb` | the convention-A ceiling mirror `1.0 - e` is **skipped on handed parts**. One added local (`handed`), one added condition. Nothing else in the file moved. |
| `C:\Users\bento\Documents\Claude\Sketchup\scripts\gen-booth.py` | `SWAP_TWO_PANEL_SIDE_WALL` + `swap_side_wall()`; the outer wall loop and `inner_parts()` reverse their slot→position pairing on a matching wall. The inner predicate is computed from the **outer** lengths. |
| `C:\Users\bento\Documents\Claude\Sketchup\scripts\wr-booth-data.rb` | REGENERATED (`python scripts/gen-booth.py --all`). 72 lines moved, in exactly four model blocks: `MDL 6060 S/E`, `MDL 6084 S/E`. |
| `C:\Users\bento\Documents\Claude\Sketchup\scripts\wr-overlays.rb` | `FACE_ROOM[:duct]` 1 → **-1**. |
| `C:\Users\bento\Documents\Claude\Sketchup\scripts\rbtest-part-orientation.py` | NEW. 45 offline checks over all three rules, incl. the 84/96/102 regression boundary. |
| `C:\Users\bento\Documents\Claude\Sketchup\scripts\wr_tools\VERSION` | 1.7.9 → **1.7.10** |
| `C:\Users\bento\Documents\Claude\Sketchup\DEVLOG.md` | 1.7.10 entry |

Untouched, as instructed: `scripts/wr-drop-lights.rb`, `scripts/proposal-package.rb`, the
`WhisperRoomQuote` repo (read only), the `P:` share (read only).

---

## Read first

1. **`scripts/wr-deck.rb`, the comment block above `own = bracket_edge(defn)`.** It carries the
   whole argument for keying the mirror on the hand, including what falsifies it.
2. **`scripts/gen-booth.py`, the `SWAP_TWO_PANEL_SIDE_WALL` block.** It states why the 46/22
   pair (7272 / 7296) is deliberately excluded and why the walk direction is not touched.
3. **`.forge/fixer/ROOTCAUSE-side-wall-order-2026-08-26.md`** — the prior art on the side-wall
   order, including the two retracted fixes. Read it before re-opening that question.
4. `reference/floor-ceiling-geometry.md` § "What SIDE L and SIDE R actually mean".

---

## Assumptions — each one is a place this can be wrong

- **ASSUMED / DERIVED: the hand letter is the right discriminator for the ceiling mirror.**
  It reproduces all five of Benton's reported tiles and holds all three protected series, which
  is a 9-for-9 fit, but the *causal* story (unhanded families are flipped about the long axis,
  handed families about the short) is **derived from the defect report, not measured**. Nobody
  has separated the two authoring conventions by opening the parts.
- **The soundly-measured alternative was not available and here is why.** A convention-A
  ceiling's hardware hangs *below* its minor level, so it could in principle be measured the way
  `bracket_edge` measures a floor's hardware above its rim — a per-part cue with no mirror and
  no exception at all. That is the fix this repo's own rule ("orientation is measured per part")
  asks for. **It cannot be written safely from here**: it would replace the 84/96/102 answer
  with a fresh measurement, and there is no way to run it, so a subtle error in it (the rim runs
  the full length of the panel and merges with every bracket — the mistake that already cost an
  evening) would move the three series Benton fenced off. Flagged as the right next step **once
  someone can run a probe in SketchUp**, not done blind.
- **ASSUMED: Benton's item 3 means the E/W walls.** On both the 6060 and the 6084 the E/W runs
  are the 40+16 ones (N/S are 40+16 on the 6060 and 40+40 on the 6084), so "the side walls where
  the 40 and 16 are" resolves to E/W on both. If he meant the 6060's N/S wall too, that is a
  separate change and this one does not make it.
- **OBSERVED, and it is a real conflict: the builder now disagrees with the portal on the 6060
  and 6084 side walls.** `node .forge/fixer/replay-portal-wallrun.js "MDL 6060 S"` executes the
  portal's own `wallPanelRun()` and printed **0 DISAGREE** *before* this change. The portal 2D
  plan and the portal angled view both put the 40 at the low-y (door) end. Benton says the built
  booth is the other way. Reported here, not patched there.
- **`STD7224FL SIDE R` measures 37.9375 × 72 when the panel is 24 wide** (observed, twice:
  `_component-probe.tsv` and `_face-levels.tsv`). `wr-deck.deck_extent` already works around
  this for seating, but `bracket_edge` still divides by the inflated box, so that part's 0.7823
  fraction is a fraction of the wrong span. It comes out on the correct side of 0.5 and the fix
  turns the tile the way Benton asked, **but the number itself is not trustworthy** and a part
  whose stray geometry moved could flip it. Worth asking why that .skp carries 13.94 in of extra
  geometry.

---

## What Benton must look at on the next build — one line per defect

**This needs `git pull` → `python scripts/install-plugin.py` → RESTART SketchUp.** `wr-deck.rb`
and `wr-overlays.rb` are libraries whose constants live until restart; a report made before the
restart says nothing about this change.

1. **MDL 7272 S and MDL 7296 S** — standard ceiling, from below. **Both** end tiles' hinges must
   now be on the **outside perimeter**, not toward the middle. Console: `STD7248CL SIDE L` should
   print `edge 0.261` (not 0.739) and `STD7224CL SIDE R` `edge 0.782` (not 0.218), and the
   ` turned` flag on each should be the opposite of last build.
2. **MDL 6060 S** — standard ceiling. The `STD6018CL SIDE R` tile (the narrow one) should now be
   turned over; the `STD6042CL SIDE L` tile must be **exactly where it was**. Console: `6018`
   prints ` turned` and `edge 0.216`; `6042` prints `edge n/a` and no turn.
3. **MDL 6060 S and MDL 6084 S** — side walls (E and W). The **40 is now at the far end from the
   door wall** and the 16 at the door end; the seam seal between them sits ~18 in from the door
   end instead of ~42. On the 6060 that also moves the **E-wall vent** to the far end. On an
   Enhanced build check the IEP wall behind it moved with it — 11.5 at the door end, 35.5 beyond.
4. **REGRESSION — MDL 84126, MDL 96120 (or 96168), MDL 102144.** Ceilings and side walls must be
   **identical to the last build**. This is the one that matters most; if any of these moved, the
   ceiling change is wrong and the fix is to revert `wr-deck.rb` alone.
5. **Any booth with a vent wall** — every duct cover has yawed 180°. The covers must still sit on
   their ports at the same heights (~71 in and ~9 in) with their backs on the wall; only which way
   round they face changes.

**Least confident: item 3, the 40/16 swap.** It is the only one that puts the builder in open
disagreement with the portal, and the E/W order in this file has now been changed three times
(2026-08-11, reverted 2026-08-27, this). Everything else here is scoped by a part property;
this one is scoped by a length pair I chose from Benton's sentence. Look at it first, and if the
40 now reads wrong, the revert is one tuple.

Second least confident: whether **MDL 7272 / 7296** need the same swap on their 46/22 side walls.
They are the identical structural case, were not reported, and are **not** changed.

---

## Open questions

1. **Do the 7272 and 7296 side walls need the 46 and 22 swapped too?** One tuple in
   `SWAP_TWO_PANEL_SIDE_WALL`. Needs Benton's eye on a built booth.
2. **Which way is the portal wrong?** The builder and the portal now disagree on the 6060/6084
   side walls. If Benton is right about the part, `layout-render.js` `wallPanelRun()` and the
   angled view are both drawing the customer a booth that will not be built that way. That is a
   `WhisperRoomQuote` issue and this repo is read-only against it.
3. **Why does `STD7224FL SIDE R.skp` carry 13.94 in of geometry outside its panel?** Its ENH twin
   and its own CL twin both measure a clean 24 × 72.
4. **The per-part ceiling measurement** described under Assumptions — worth doing properly the
   next time a probe can be run in SketchUp, to retire the mirror and the hand test together.
5. Pre-existing and NOT caused by this work, both confirmed failing on `HEAD` before any edit:
   `.forge/builder/replay-iep-deck.py` still asserts `_face-levels.tsv` carries zero ENH rows
   (stale since 2026-08-26, already flagged in `.forge/fixer/HANDOFF.md`), and
   `.forge/builder/build-room-uitest.py` hard-codes the desktop's OneDrive path.
