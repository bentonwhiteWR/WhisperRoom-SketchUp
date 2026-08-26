# ROOT CAUSE — the E/W wall run is walked from the wrong end (SketchUp side)

Diagnosed 2026-08-26 on `main` @ v1.6.29. **Nothing was shipped.** The only file changed is the
harness, `.forge/fixer/replay-side-wall-order.py`.

## Which of the two defects this is

This is the **ORDER** defect — which END of a side wall a slot id lands on.

It is **NOT** the width-axis family split (`40Panel2636WDO` runs X while `16PanelSolid` /
`40PanelSolid` run Y). That one turns a panel end-for-end **in place** and is still open and
untouched. `FACING` is the thickness sense and `RUNS` is the width axis; neither is order.

## One sentence

`scripts/gen-booth.py` was changed on 2026-08-11 to walk every **E/W** wall **N→S** to match
`layout-render.js`'s *drawing* order, which put **slot 0 at the N end instead of the door end**
on all 18 multi-slot-side-wall models; the regenerated `scripts/wr-booth-data.rb` landed on
`main` in commit **`92dc59b`**, and the builder places every part at its `:poly` from that file,
so the window panel (`W0`) is built at the far end of the wall from the door.

## The evidence, in order

**1. The layout data was reversed by a specific commit.** (observed)

    git show 4c0cf38:scripts/wr-booth-data.rb   'MDL 102144 S'  W0 -> poly y 2.0 .. 42.0
    git show 92dc59b:scripts/wr-booth-data.rb   'MDL 102144 S'  W0 -> poly y 62.0 .. 102.0

A full diff of every panel origin between `4c0cf38` and `HEAD`: **152 unchanged, 74 changed —
36 on `E`, 36 on `W`, and exactly 2 on `N`/`S`.** The two N/S ones are `MDL 96168 N3` and `S3`
moving 128→122, which is the documented 96168 `N2` digitisation correction and unrelated.
So the change is a clean, catalogue-wide reversal of the E/W runs and nothing else.

**2. The generator says so in its own comment.** (observed) `scripts/gen-booth.py:407-412`

    # E/W slot lists run NORTH -> SOUTH. That is the booth builder's own
    # convention (layout-render.js top-down: ay = runY(aIn), y-down from
    # the N wall), and this walked them south->north until 2026-08-11 —
    # which put every E/W wall's panels at the mirrored end. N/S run
    # west->east in both, so only these two flip.
    x, y = (W - t if side == 'E' else t - PANEL_T), H - cursor - ln

The justification is a **drawing** convention, not a measurement.

**3. That drawing convention is one the portal itself patches.** (observed)
`assets/layout-render.js:1003-1004` `runY = inches => y0 + inches * PX`, and `:1562-1565` draws
`N` at `y0 + t` (top) and `S` at `y0 + H - t` (bottom). So `aIn = 0` **is** the N end — but
`wallPanelRun()` then flips the run back to the door end:

    if ((side === 'E' || side === 'W') && n === 2 && skuRaw[0] !== skuRaw[1]) { … }

with the cited source being `reference/seam-seal-attachment.md:317`:

> On the four split-run booths — 6060, 6084, 7272, 7296 — WhisperRoom's own build puts the
> **big** run on each E/W wall at the **door end**, which is the reverse of what the generated
> layout data says. **The floor and ceiling panels' hinge slots confirm it.**

That is **physical** evidence (hinge slots) that E/W slot 0 belongs at the door end. The portal
only applies it where it can *detect* it — a 2-piece wall with unequal real widths — and its own
comment writes off the larger models because "nothing on them can flip." That is true of the
**joint positions** and false of the **slot→part mapping**: `MDL 102144`'s W wall is 40/16/40,
perfectly symmetric in widths, so a reversal moves no joint by a thousandth and still swings the
window from one end of the wall to the other. **That is exactly why this went unseen.**

**4. An independent witness on disk agrees with the pre-flip order.** (observed)
`WhisperRoomQuote/lib/pl-data/booth-iso-geometry.json` is a straight extract of
`wr-booth-data.rb` stamped `2026-08-07T22:57:11.420Z` — four days before the flip. It carries
all 25 Standard layouts and puts `MDL 102144 W0` at **y 2..42**, the door end. It is the file
the portal's **angled ("YOUR BOOTH") view** renders from, so the portal's angled view still
draws the pre-flip order, and that matches Benton's portal render exactly: window adjacent to
the door corner.

**5. All 25 doors are on `S`.** (observed, `booth-layouts.json`) So for this catalogue,
"walk E/W from low y" and "slot 0 at the door end" are the same rule. A future N-door model
would need the door-anchored form.

## Why the old harness could not see it

`.forge/fixer/replay-side-wall-order.py` decided AGREE/MIRRORED with

    want  = ids  (N/S)  |  list(reversed(ids))  (E/W)
    agree = (geo_order == want)

`ids` is `wr-booth-data.rb`'s own slot ids in slot-number order; `geo_order` is
`wr-booth-data.rb`'s own parts in coordinate order. The portal's slot list was read, printed,
and **never used in the verdict.** The verdict was one file against a hard-coded assumption —
and the assumption ("portal slot 0 is at the N end of a side wall") is *precisely the rule the
2026-08-11 generator change adopted.* The harness asserted the change under test. 200/200 was
guaranteed before it opened a portal file. It could only have failed on a layout whose own slot
numbering was non-monotonic.

Its secondary "PORTAL FLIP FIRES" note was scoped to 2-piece unequal walls, so it could not see
`102144` either.

## The harness is fixed — this is the deliverable that shipped

`.forge/fixer/replay-side-wall-order.py` now compares per-slot along-wall extents against
`booth-iso-geometry.json`, the independent pre-flip witness, prints an `END` and a
`vs WITNESS` column per slot, and exits non-zero on any mismatch. `booth-layouts.json` is still
printed but explicitly labelled **context only, not a verdict**, with the reason.

    python .forge/fixer/replay-side-wall-order.py "MDL 102144 S"
      W0  SOLID  62.000 102.000  40.000  40PanelSolid  HIGH  MOVED  witness 2.000..42.000 (LOW end)
      => *** REVERSED - the whole run is walked end for end.
         Slot W0 sits at the HIGH end here, at the LOW end in the witness.
      EXIT 1

    python .forge/fixer/replay-side-wall-order.py --all --summary
      300 wall(s) checked against the witness: 108 REVERSED, 0 DIFFER, 0 with no witness

**108 = 18 models × 2 walls × 3 shells** (`S out`, `E out`, `E in`). The seven models absent
from the list — **4230, 4242, 4260, 4284, 4848, 4872, 4896** — have a single panel per side
wall, so there is nothing to reverse. That is why the completed **MDL 4872 E** is unaffected.

---

# THE FIX I WOULD MAKE — NOT SHIPPED

Four lines in `scripts/gen-booth.py`, then a regenerate. **No change to any `.rb` by hand;
`wr-booth-data.rb` is generated.**

### `scripts/gen-booth.py:411` — outer shell panel walk

    -                x, y = (W - t if side == 'E' else t - PANEL_T), H - cursor - ln
    +                x, y = (W - t if side == 'E' else t - PANEL_T), cursor

and replace the 2026-08-11 comment above it (lines 408-412) with:

    # E/W slot lists run SOUTH -> NORTH: slot 0 sits at the DOOR end.
    # Physical evidence, reference/seam-seal-attachment.md §"Two things that
    # move a seal along a wall": the floor and ceiling panels' HINGE SLOTS put
    # the big run at the door end on the 6060/6084/7272/7296. The N->S walk
    # taken on 2026-08-11 copied layout-render.js's DRAWING order (aIn from the
    # N wall) - which is the very order wallPanelRun() patches back with its
    # big-run-at-the-door-end flip. Do not re-adopt it. All 25 doors are on S.

### `scripts/gen-booth.py:423-424` — outer mid-wall seal

    -                if side in ('E', 'W'):
    -                    mid = H - cursor - SEAL_W / 2.0   # same N->S flip as the panels

(delete both lines; `mid = cursor + SEAL_W / 2.0` on line 422 then stands for all four sides)

### `scripts/gen-booth.py:259` — inner (IEP) shell panel walk

    -                y, dy = H - cursor - ln, ln
    +                y, dy = cursor, ln

with its comment on line 258 changed from `# Same N->S walk as the outer shell, for the same
reason.` to `# Same S->N walk as the outer shell, for the same reason.`

### `scripts/gen-booth.py:268-269` — inner mid-wall seal

    -                if side in ('E', 'W'):
    -                    mid = H - cursor - IEP_SEAL_W / 2.0

(delete both lines)

### Then

    python scripts/gen-booth.py --all          # rewrites scripts/wr-booth-data.rb
    python scripts/rbparse.py                  # real syntax check of every .rb
    python .forge/fixer/replay-side-wall-order.py --all --summary   # must read 0 REVERSED, exit 0
    python .forge/builder/replay-iep-deck.py         # 31 assertions
    python .forge/builder/replay-iep-wall-lift.py    # 105 checks

Bump `scripts/wr_tools/VERSION` (1.6.29 → 1.6.30) — `wr-booth-data.rb` is under `scripts/`.

**No change to `booth-from-link.rb`.** Its slot assignment is not the defect: the RAW PACK maps
`W0 = 40Panel2636WDO` and the portal's own summary says `Window Left (W0)`. Both agree on the
slot. Only the slot's *position* is wrong, and that lives in the layout data.

## What this moves on the Standard path

- **18 models × 2 side walls.** Every `E` and `W` panel and mid-wall seal on 102102, 102126,
  102144, 102168, 102186, 10284, 6060, 6084, 7272, 7296, 84102, 84126, 8484, 96120, 96144,
  96168, 96192, 9696 — Standard and Enhanced alike — moves to the mirrored position on its wall.
- **Corner seals, N/S walls, floors, ceilings, decks: untouched.** The change is confined to the
  E/W cursor.
- **On symmetric-width side walls (most of them) no joint moves at all** — only which slot id
  owns which end. The visible change is where the window / vent / cable panel sits.
- **On 6060, 6084, 7272, 7296 the joint moves 24 in**, into the position the hinge slots and
  the portal's angled view already say it belongs.
- **Unaffected: 4230, 4242, 4260, 4284, 4848, 4872, 4896** — one panel per side wall. The
  finished **MDL 4872 E** does not move.
- **`build-booth-components.rb`'s WA-door rebalance** (`:1720-1776`) walks a wall by coordinate,
  so on an E/W wall carrying a wide-access door the rebalance would shift to the other end. No
  catalogue model has a side-wall door frame (all 25 doors are on `S`), so this is dormant — but
  it is the one place the change could reach beyond the E/W panel positions.

## Regression check to run after the fix

| booth | expect |
|---|---|
| **Standard MDL 102144** from the link | window **adjacent to the door corner** |
| **Standard MDL 96144** from the link | window **adjacent to the door corner** |
| **Enhanced MDL 102144** from the same link | same, both shells |
| **MDL 6060 S** | the 40 run at the door end, the 16 at the back; seal moves 24 in |
| **MDL 4872 E** (already signed off) | **byte-identical — nothing moves** |
| **MDL 4260 S / 4848 S** (no side-wall window) | **unchanged** |

Offline, `replay-side-wall-order.py --all --summary` must read `0 REVERSED` and exit 0.

## A separate defect I am NOT fixing, reported for Benton

**The portal's own top-down plan has the same bug**, and it disagrees with the portal's own
angled view. `wallPanelRun()`'s door-end flip is gated on `n === 2 && skuRaw[0] !== skuRaw[1]`,
so it cannot fire on a 3-slot wall (102144) or an equal-width pair (96144's 46+46). For those
14 models the 2D plan, the elevations, the walk-around and the proposal PDF still draw
`aIn = 0` at the **N** end — the window at the far end from the door. The general rule is "E/W
run starts at the door wall", not "a 2-piece unequal wall flips."

`WhisperRoomQuote` is **read-only from here** and I have not touched it. Flagging it because
after the SketchUp fix, SketchUp and the portal's angled view will agree with each other and
both will disagree with the portal's 2D plan on those 14 models.

## Confidence, at the weakest link

- The reversal, its commit, and its 108 affected walls: **observed**, from git and the two data
  files.
- That the **pre-flip** order is the correct one: **derived** from three agreeing sources — the
  hinge-slot evidence in `reference/seam-seal-attachment.md` (physical, but attested only for
  4 models), the pre-flip iso extract the portal's angled view still draws, and Benton's own
  side-by-side render comparison (**reported**).
- **The weakest link is the generalisation from 4 models to 18.** The hinge-slot measurement
  covers 6060 / 6084 / 7272 / 7296. For the other 14 the door-end rule rests on the portal's
  angled view and on Benton's 102144 picture. It is the same rule and it is the only rule that
  fits both, but it has not been measured on a 3-slot wall.
- I could not run any Ruby and did not build anything. **No claim here has been checked in
  SketchUp.**
