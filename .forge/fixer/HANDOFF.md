# FIXER HANDOFF — side-wall window at the wrong END, 2026-08-27 (v4, supersedes v3)

## The defect and the verdict

Benton, 2026-08-27, off a real SketchUp build of the MDL 102144 E **HX** from the link:
*"the windows on the side walls are still on the wrong 'side'."* Same report he made 2026-08-26
on the plain E and on Standard. Orchestrator-observed picture pair (reported to me; I cannot see
images): in the booth builder the window sits on the correct long wall at the end **closest** to
the door; in SketchUp it sits on that same wall at the end **farthest** from the door. Correct
WALL, wrong END — commit 39bdc71's title, confirmed a second time on a fresh build.

**Root cause: the 2026-08-11 change to `scripts/gen-booth.py` that walked every E/W wall
N→S.** It put slot 0 at the N end of the side walls; the customer's own booth-builder view — and
the pre-2026-08-11 data, and WhisperRoom's measured big-run convention — put slot 0 at the
door-wall (S) end. **Shipped in this change: the walk is reverted to S→N and
`scripts/wr-booth-data.rb` regenerated.** UNRUN — no Ruby executed, no SketchUp opened.

## How this differs from the RETRACTED e2e3461 diagnosis — read before re-litigating

e2e3461 retracted the same four-line revert because its *witness* was circular
(`booth-iso-geometry.json` is a stale snapshot of the file under test) and left the 102144
**unresolved pending Benton**. Two things are new:

1. **Benton has now adjudicated, twice, on real builds** (Standard + Enhanced 2026-08-26, HX
   2026-08-27): the built end is wrong. That is the human ruling e2e3461 said was required. The
   evidence for this fix is *Benton plus the live customer-facing view*, not the stale JSON.
2. The "breaks the 14 models where the builder matches the plan the customer is shown" objection
   inverted: the customer's primary view is the angled "YOUR BOOTH" view, and it — plus Benton —
   contradicts the portal 2D plan's raw order on exactly those models. The 2D plan is the odd
   one out (see below).

The retraction's other three findings all still stand and were honoured: booth-iso-geometry.json
was used only as *context*, never as a verdict; the portal's `wallPanelRun()` flip gate is a
correct rendering of the documented convention; and the anchor is the **model's own door wall**
(`layout.door.wall`, S on all 25 catalogue models), never the live door placement (v2.417.1).

## Where slot order comes from (question 1 of the brief)

- `scripts/gen-booth.py` digitises the catalogue and writes `scripts/wr-booth-data.rb`
  (header line 1: GENERATED — do not hand-edit). Slot order → physical position is decided by
  the walk at gen-booth.py **line ~411** (outer) and **~259** (inner IEP), with the mid-wall
  seals at **~424** and **~268**.
- `scripts/booth-from-link.rb` assigns pack→slot-id only (`assign[sid]`, :319-342); it never
  positions anything. **HX is a part-name suffix only** (`resolve_part`, :246-247; layout key
  built at :289-290 without hx) — there is **no per-variant layout table**, which is why the HX
  build shows the identical defect. `build-booth-components.rb` places each part at its `:poly`
  verbatim.
- So the disagreement was in the **DATA** (generated layout), not the placer. The placer was not
  touched (and the IEP_WALL_LIFT region ~140-170 was left strictly alone — the orchestrator is
  editing it concurrently; the tree's `M build-booth-components.rb` is theirs, not mine).

## The portal's three views (question 2), observed in code

| view | index-0 end on E/W | source |
|---|---|---|
| angled "YOUR BOOTH" (what the customer judges) | **S / door end** — 102144 `W0` at y 2..42 | `lib/pl-data/booth-iso-geometry.json` (`booths[].parts`), painted by `assets/iso-render.js:1464-1475`, `:1731-1752` |
| 2D top-down plan | **N end** raw (`aIn` grows from N; `layout-render.js:156` `wallPanelRun`), flipped back to the door end ONLY on 2-slot unequal walls (`:275` gate `n===2 && skuRaw[0]!==skuRaw[1]`) | `assets/layout-render.js` |
| SketchUp builder (pre-fix) | N end | `wr-booth-data.rb` post-2026-08-11 |

The 2D plan therefore contradicts the angled view on every multi-slot **symmetric** E/W wall (14
models, 56 walls) — invisible on solids, visible the moment a window or vent occupies a side-wall
slot. `wallPanelRun`'s own comment block (layout-render.js:~240) states the angled view "was
already correct." The big-run convention (`reference/seam-seal-attachment.md` §"Two things that
move a seal along a wall", hinge slots, measured) also puts slot 0 (the big run) at the door end
on 6060/6084/7272/7296.

## Exactly what changed

- `scripts/gen-booth.py` — four sites: outer panel walk (now `y = cursor`), outer seal
  (`mid = cursor + SEAL_W/2`, E/W override deleted), inner IEP panel walk (`y, dy = cursor, ln`),
  inner seal (E/W override deleted). Both shells now walk the same direction **unconditionally**,
  so they can never disagree with each other. Comments carry the evidence and the
  "anchor = model's fixed door wall, NOT live placement" rule, with a note for any future
  N-door model.
- `scripts/wr-booth-data.rb` — regenerated (`python scripts/gen-booth.py --all`): 312 lines
  changed, **every changed entity is E/W** (panels W0..W2/E0..E2, their `i` twins, W-/E-seals).
  N/S untouched.
- `.forge/fixer/replay-portal-wallrun.js` — header note only: expected state changed; 84
  DISAGREE is now the correct reading (see below).
- `scripts/wr_tools/VERSION` → **1.6.34** (the orchestrator's concurrent edit had already taken
  1.6.33; collapsing to one number at commit time is the orchestrator's call).

Nothing committed; tree left dirty for the orchestrator. `WhisperRoomQuote` read only.

## Verification run (all offline — NOTHING here ran in SketchUp)

- Regenerated data vs **pre-flip commit `4c0cf38`**: all 226 Standard outer panel origins
  compared — **224 identical, 2 differ**, and the 2 are the known 96168 N3/S3 digitisation
  correction (post-flip, legitimate, N/S). The revert is exact.
- 102144 E: `W0` outer now y 2..42 (door end), `W0i` 4.25..39.75 — matches the angled view's
  `W0 [[1,2],[2,2],[2,42],[1,42]]` (file still stamped 2026-08-07, verified today).
- 6060: `W0` (the 40" big run) now y 2..42 — the measured hinge-slot convention lands as a
  byproduct; **the four split-run booths' 24-wall defect from ROOTCAUSE-6060E is closed by this
  same change.**
- `node .forge/fixer/replay-portal-wallrun.js --all`: **300 walls, 84 DISAGREE** — exactly the
  14 symmetric multi-slot models × 2 walls × 3 shell rows where the portal 2D plan draws raw
  N-first order. The four split-run booths **AGREE (0 disagreements)**; if one of those ever
  disagrees again, that is a real regression. 6060 S: 0 DISAGREE, angled matches too.
- `python scripts/rbparse.py`: **52 files parse** (real CRuby parse; parsing is not running).
- `.forge/builder/replay-iep-wall-lift.py`: 105/105 PASS against HEAD's
  `build-booth-components.rb` + my regenerated data (isolated in a temp worktree). The 1/105
  failure in the live tree is caused by the orchestrator's in-progress IEP_WALL_LIFT edit, not
  by this change. `.forge/builder/replay-iep-deck.py`'s failure is the DEVLOG-documented stale
  line-879 assert, present at clean HEAD, unrelated.

## Provenance

- Slot order source, HX keying, the four walk sites, the portal's three-view code paths, the
  regeneration diffs, and every harness number above: **observed** (file:line cited).
- "The customer's booth-builder view shows the window door-adjacent / SketchUp shows far end":
  **reported** (Benton via orchestrator screenshots; I cannot see images).
- "Slot 0 belongs at the door-wall end on symmetric walls": **derived** from Benton's two
  reports + the customer-facing angled view + the portal's own "already correct" comment +
  continuity with the pre-2026-08-11 data; **measured** (hinge slots) only on the four
  split-run booths. A physical hinge-slot check on a real 102144/96144 (HANDOFF.md's open
  question) would upgrade this to measured; it has still never been taken.
- The fix itself: **assumed correct until built** — UNRUN.

## What Benton must look at in a rebuilt booth

Reinstall (`git pull` → `python scripts/install-plugin.py` → **restart SketchUp**), then:

1. **MDL 102144 E HX from his same link** — window (`W0`/`W0i`) at the end of the W wall
   **adjacent to the door corner**, both shells; E-wall vent (`E0`) likewise at the door end.
2. **Standard MDL 102144** from the same link — same.
3. **MDL 6060 (either variant)** — the 40" run at the door end of both side walls, 16" at the
   back; mid-wall seal 24" from where it was.
4. **MDL 4872 E** (signed off) — must be **unchanged** (single panel per side wall; its E/W
   origins are in the 224-identical set).
5. Any N-wall vents — **unchanged** (N/S untouched).

## Left open, deliberately

- **The portal 2D plan draws the raw N-first order on 14 models** — now the lone dissenter,
  contradicting its own angled view, SketchUp, and Benton. That is a `WhisperRoomQuote`
  (`wallPanelRun`) change — generalise the door-end rule beyond the 2-slot-unequal gate — and
  is not makeable from this repo. Until then the portal's 2D plan will look mirrored on
  side-wall windows/vents relative to the (now-correct) build.
- `booth-iso-geometry.json` can now be re-extracted safely (its source file matches it again on
  E/W), but that is also `WhisperRoomQuote`'s to run.
- The **width-axis family split** (end-for-end IN PLACE, `WIDTH-AXIS-FAMILY-2026-08-26.md`) is a
  separate, still-open defect. If a rebuilt 102144's window is at the right END but the panel
  looks turned, that is the other defect, not a failure of this one.
- The physical hinge-slot measurement on a 102144/96144 is still worth taking; it is the only
  thing that would make the symmetric-wall rule *measured* rather than derived.
